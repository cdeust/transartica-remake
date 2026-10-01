#!/usr/bin/env python3
"""Build private desktop previews using the pinned local Godot toolchain.

Source: Godot 4.5 desktop export documentation in tasks/evidence/engine-choice.md.
The local private map is copied byte-for-byte; this is not a publication command.
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ENGINE = ROOT / '.toolchain/Godot.app/Contents/MacOS/Godot'
TARGETS = {'windows': 'Windows Desktop', 'macos': 'macOS'}


def prepare_data():
    destination = ROOT / 'game/private-data'
    destination.mkdir(exist_ok=True)
    for source, output in [('CARTE.FIC', 'CARTE.FIC'),
                           ('villes-decoded.csv', 'villes-decoded.data'),
                           ('commerce.json', 'commerce.json'),
                           ('startup.json', 'startup.json')]:
        shutil.copyfile(ROOT / 'reference-private' / source, destination / output)
    # Source: private ECS campaign decoder; exported scenes require its texts,
    # map reveal tables and death pages as well as the base geography.
    subprocess.run([
        'python3', '-B', str(ROOT / 'tools/build_campaign_data.py'),
        '--source', str(ROOT / 'reference-private'),
        '--output', str(destination / 'campaign.json')], cwd=ROOT, check=True)
    # The authored global chart uses source static vectors, never original RGB.
    subprocess.run(['python3', '-B', str(ROOT / 'tools/export_overview_geometry.py')],
                   cwd=ROOT, check=True)
    shutil.copyfile(ROOT / 'reference-private/overview-geometry.json',
                    destination / 'overview-geometry.json')
    shutil.copytree(ROOT / 'reference-private/audio', destination / 'audio', dirs_exist_ok=True)
    # Captured original audio stays private; default finale visuals are authored.
    finale_audio = ROOT / 'reference-private/finale.wav'
    if not finale_audio.is_file():
        raise FileNotFoundError('Private finale audio has not been prepared')
    shutil.copyfile(finale_audio, destination / 'finale.wav')


def export(target):
    log = ROOT / '.cache' / f'export-{target}.log'
    process = subprocess.run(
        [str(ENGINE), '--headless', '--path', str(ROOT / 'game'),
         '--log-file', str(log), '--export-release', TARGETS[target]],
        cwd=ROOT, capture_output=True, text=True, check=False)
    output = process.stdout + process.stderr
    (ROOT / 'tasks/validation' / f'export-{target}.txt').write_text(output)
    if process.returncode or 'ERROR:' in output or 'SCRIPT ERROR' in output:
        raise RuntimeError(f'{target} export failed:\n{output}')


def package_windows():
    destination = ROOT / 'builds/windows'
    shutil.copyfile(ROOT / 'LICENSE', destination / 'LICENSE.txt')
    (destination / 'README.txt').write_text(
        'Transartica private development build. Unzip everything, then run Transartica.exe.\n'
        'Keep Transartica.pck beside it. See tasks/validation/completion-matrix-20261001.md for validation.\n'
        'Use the illustrated control panel to navigate. F5 saves; F6 opens options.\n'
        'Contains private historical map data: do not publish this package as MIT.\n'
        'Windows binary exported on macOS; execution on Windows not yet verified.\n'
        'Godot Engine license: https://godotengine.org/license/\n')
    archive = ROOT / 'builds/Transartica-Windows.zip'
    with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED) as bundle:
        for name in ('Transartica.exe', 'Transartica.pck', 'LICENSE.txt', 'README.txt'):
            bundle.write(destination / name, arcname='Transartica/' + name)


def unpack_macos():
    # Keep the documented .app launch path synchronized with the new archive.
    subprocess.run(['ditto', '-x', '-k', str(ROOT / 'builds/Transartica-macOS.zip'),
                    str(ROOT / 'builds/macos')], cwd=ROOT, check=True)


def record_artifacts():
    artifacts = []
    for path in sorted((ROOT / 'builds').glob('*.zip')):
        with path.open('rb') as stream:
            digest = hashlib.file_digest(stream, 'sha256').hexdigest()
        artifacts.append({'file': path.name, 'bytes': path.stat().st_size, 'sha256': digest})
    (ROOT / 'builds/manifest.json').write_text(json.dumps(artifacts, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('target', choices=['all', *TARGETS], default='all', nargs='?')
    target = parser.parse_args().target
    for directory in ('builds/windows', '.cache', 'tasks/validation'):
        (ROOT / directory).mkdir(parents=True, exist_ok=True)
    prepare_data()
    for name in TARGETS if target == 'all' else [target]:
        export(name)
        if name == 'windows':
            package_windows()
        else:
            unpack_macos()
        print(f'Exported {name}; see tasks/validation/export-{name}.txt')
    record_artifacts()


if __name__ == '__main__':
    main()
