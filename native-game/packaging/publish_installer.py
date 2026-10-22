#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Verify an existing Windows build and upload only its installer to a draft.

Sources: docs.github.com/en/rest/actions/artifacts and /releases/assets.
Downloaded artifact bytes are inspected; no downloaded code is executed.
"""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import zipfile


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def api(path):
    return json.loads(subprocess.check_output(["gh", "api", path]))


def validate_run(run, repo, expected):
    require(run["repository"]["full_name"] == repo and run["head_repository"]["full_name"] == repo, "Foreign repository run")
    require(run["head_sha"] == expected, "Source commit mismatch")
    require(run["name"] == "Native Windows installer" and run["path"] == ".github/workflows/native-windows-delivery.yml", "Unexpected source workflow")
    require(run["status"] == "completed" and run["conclusion"] == "success", "Source run did not succeed")


def draft_release(repo, tag):
    # Draft tags need not exist yet; listing includes unpublished releases.
    pages = json.loads(subprocess.check_output(["gh", "api", "--paginate", "--slurp", f"repos/{repo}/releases"]))
    matches = [release for page in pages for release in page if release["tag_name"] == tag]
    require(len(matches) == 1, "Expected one existing release")
    release = matches[0]
    require(release["draft"] is True, "Release is already public")
    require(not any(asset["name"] == "Transartica-setup.exe" for asset in release["assets"]), "Installer asset already exists")
    return release


def source_manifest(repo, expected):
    result = api(f"repos/{repo}/contents/game/assets/audio/orchestral/music.json?ref={expected}")
    require(result["encoding"] == "base64", "Unexpected source manifest encoding")
    raw = base64.b64decode(result["content"])
    return json.loads(raw), hashlib.sha256(raw).hexdigest()


def member(archive, suffix):
    matches = [name for name in archive.namelist() if name.endswith("/" + suffix) or name == suffix]
    require(len(matches) == 1, "Ambiguous artifact member: " + suffix)
    return matches[0]


def verify_music(package, manifest, manifest_sha):
    tracks = manifest["tracks"]
    require(len(tracks) == 9 and len({track["file"] for track in tracks.values()}) == 9, "Nine distinct masters required")
    checked = {}
    for cue, track in tracks.items():
        require(track["file"].startswith("res://assets/audio/orchestral/"), "Unexpected music path")
        key = "resources/game/" + track["file"].removeprefix("res://")
        require(package["files"].get(key) == track["sha256"], "Music hash mismatch: " + cue)
        checked[cue] = track["sha256"]
    require(package["files"].get("resources/game/assets/audio/orchestral/music.json") == manifest_sha, "Music manifest mismatch")
    return checked


def verify_playback(proof, manifest):
    state = (proof / "state.log").read_text(encoding="utf-8-sig")
    title = manifest["tracks"]["bopres-0"]
    pattern = rf'AUDIO event=quit driver=dummy rate={title["rate"]} music_cursor=[1-9][0-9]* music_frames={title["frames"]} music_playing=1 .*error=""'
    require(re.search(pattern, state), "Final title did not advance on Windows")
    require("STATE event=boot " in state and "STATE event=quit " in state, "Runtime markers missing")
    require("NATIVE runtime=SDL2 renderer=" in (proof / "stdout.log").read_text(encoding="utf-8-sig"), "Renderer marker missing")
    require(not (proof / "stderr.log").read_text(encoding="utf-8-sig").strip(), "Installed game emitted stderr")


def verify_archive(path, artifact, manifest, manifest_sha):
    require(path.stat().st_size == artifact["size_in_bytes"], "Artifact size mismatch")
    require("sha256:" + sha(path) == artifact["digest"], "Artifact digest mismatch")
    proof = path.parent / "proof"
    proof.mkdir()
    with zipfile.ZipFile(path) as archive:
        package = json.loads(archive.read(member(archive, "package-receipt.json")))
        smoke = json.loads(archive.read(member(archive, "windows-smoke/receipt.json")).decode("utf-8-sig"))
        checked = verify_music(package, manifest, manifest_sha)
        require(smoke["runtime_tested"] is True and smoke["uninstall_tested"] is True, "Native installation receipt incomplete")
        require(smoke["resources_verified"] == len(package["files"]), "Installed file count mismatch")
        require(smoke["physical_audio_tested"] is False and smoke["gameplay_input_tested"] is False, "Unexpected hosted interaction claim")
        installer = path.parent / "Transartica-setup.exe"
        with archive.open(member(archive, installer.name)) as source, installer.open("xb") as target:
            shutil.copyfileobj(source, target)
        require(sha(installer) == smoke["installer_sha256"], "Installed executable digest mismatch")
        for suffix in ("windows-smoke/state.log", "windows-smoke/stdout.log", "windows-smoke/stderr.log", "LastTest.log"):
            (proof / Path(suffix).name).write_bytes(archive.read(member(archive, suffix)))
    verify_playback(proof, manifest)
    (proof / "package-receipt.json").write_text(json.dumps(package, indent=2) + "\n")
    (proof / "windows-smoke-receipt.json").write_text(json.dumps(smoke, indent=2) + "\n")
    return installer, {"installer_sha256": sha(installer), "installer_bytes": installer.stat().st_size,
                       "music_sha256": checked, "music_manifest_sha256": manifest_sha, "windows_smoke": smoke}


def upload(repo, release, installer):
    # GitHub rejects duplicate asset names; no clobber or release publication.
    current = api(f"repos/{repo}/releases/{release['id']}")
    require(current["draft"] is True and current["tag_name"] == release["tag_name"], "Draft changed before upload")
    require(not any(asset["name"] == installer.name for asset in current["assets"]), "Installer asset already exists")
    subprocess.run(["gh", "release", "upload", release["tag_name"], str(installer), "--repo", repo], check=True)
    assets = api(f"repos/{repo}/releases/{release['id']}/assets")
    matches = [asset for asset in assets if asset["name"] == installer.name]
    require(len(matches) == 1, "Uploaded asset missing or ambiguous")
    asset = matches[0]
    require(asset["state"] == "uploaded" and asset["size"] == installer.stat().st_size, "Remote asset size/state mismatch")
    require(asset["digest"] == "sha256:" + sha(installer), "Remote asset digest mismatch")
    return asset


def publish(args):
    require(re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", args.repo), "Invalid repository")
    require(re.fullmatch(r"[0-9a-f]{40}", args.expected_sha), "Expected full source SHA")
    require(args.run_id.isdecimal(), "Expected numeric run ID")
    require(args.tag and not args.tag.startswith("-"), "Invalid release tag")
    args.scratch.mkdir(parents=True, exist_ok=False)
    run = api(f"repos/{args.repo}/actions/runs/{args.run_id}")
    validate_run(run, args.repo, args.expected_sha)
    release = draft_release(args.repo, args.tag)
    artifacts = api(f"repos/{args.repo}/actions/runs/{args.run_id}/artifacts")["artifacts"]
    matches = [a for a in artifacts if a["name"] == "Transartica-Windows-x64-" + args.expected_sha]
    require(len(matches) == 1 and not matches[0]["expired"], "Expected one live source artifact")
    artifact = matches[0]
    manifest, manifest_sha = source_manifest(args.repo, args.expected_sha)
    archive = args.scratch / "artifact.zip"
    with archive.open("xb") as stream:
        subprocess.run(["gh", "api", f"repos/{args.repo}/actions/artifacts/{artifact['id']}/zip"], stdout=stream, check=True)
    installer, receipt = verify_archive(archive, artifact, manifest, manifest_sha)
    receipt.update(source_sha=args.expected_sha, source_run_url=run["html_url"], artifact=artifact, release_id=release["id"], release_tag=args.tag)
    proof = args.scratch / "proof/publication.json"
    proof.write_text(json.dumps(receipt, indent=2) + "\n")
    receipt["release_asset"] = upload(args.repo, release, installer)
    proof.write_text(json.dumps(receipt, indent=2) + "\n")
    print(json.dumps({"installer_sha256": receipt["installer_sha256"], "installer_bytes": receipt["installer_bytes"], "release_asset_id": receipt["release_asset"]["id"]}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("repo", "run-id", "expected-sha", "tag"):
        parser.add_argument("--" + name, required=True)
    parser.add_argument("--scratch", required=True, type=Path)
    publish(parser.parse_args())
