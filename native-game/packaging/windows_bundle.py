#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Close an installed CMake tree over its actual UCRT64 DLL imports and licenses.

Sources: GNU objdump -p PE import table; MSYS2 pacman -Qo/-Ql package database.
No downloads, PATH resolution, system DLL copying, or successful-launch claim.
"""
from __future__ import annotations

import argparse
import ctypes
import json
import os
from pathlib import Path
import re
import shutil
import sys

from macos_bundle import PackageError, run, sha
from stage_runtime import install_staged


def imports(output: str) -> list[str]:
    names = re.findall(r"^\s*DLL Name:\s*(\S+)\s*$", output, re.MULTILINE)
    if not names:
        raise PackageError("PE import table is empty")
    if any(not re.fullmatch(r"[A-Za-z0-9_.+-]+\.dll", name, re.IGNORECASE) for name in names):
        raise PackageError("Unsafe PE dependency name")
    return sorted(set(names), key=str.casefold)


def system_dependency(name: str, system: Path) -> bool:
    if (system / name).is_file():
        return True
    if sys.platform != "win32" or not name.lower().startswith(("api-", "ext-")):
        return False
    # Microsoft Windows API sets are loader contracts, sometimes without files.
    # source: Microsoft libloaderapi.h, LOAD_LIBRARY_SEARCH_SYSTEM32 = 0x00000800.
    kernel = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel.LoadLibraryExW.argtypes = [ctypes.c_wchar_p, ctypes.c_void_p, ctypes.c_uint32]
    kernel.LoadLibraryExW.restype = ctypes.c_void_p
    kernel.FreeLibrary.argtypes = [ctypes.c_void_p]
    kernel.FreeLibrary.restype = ctypes.c_int
    handle = kernel.LoadLibraryExW(name, None, 0x00000800)
    if not handle:
        return False
    if not kernel.FreeLibrary(handle):
        raise PackageError(f"Could not release system API contract {name}")
    return True


def closure(binary: Path, prefix: Path, objdump: Path, system: Path) -> dict[Path, list[str]]:
    libraries = {path.name.casefold(): path for path in (prefix / "bin").glob("*.dll")}
    pending = [binary]
    graph = {}
    while pending:
        current = pending.pop()
        if current in graph:
            continue
        dependencies = imports(run(objdump, "-p", current))
        graph[current] = dependencies
        for name in dependencies:
            candidate = libraries.get(name.casefold())
            if candidate:
                pending.append(candidate)
            elif not system_dependency(name, system):
                raise PackageError(f"Unresolved DLL {name} imported by {current.name}")
    return graph


def library_licenses(library: Path, prefix: Path, pacman: Path) -> tuple[str, list[Path]]:
    # pacman paths are MSYS package paths even when the caller is native Python.
    package_path = "/" + prefix.name + "/bin/" + library.name
    package = run(pacman, "-Qoq", package_path).strip()
    if not re.fullmatch(r"[a-zA-Z0-9@_.+-]+", package):
        raise PackageError(f"Ambiguous package ownership for {library.name}")
    files = []
    for line in run(pacman, "-Qlq", package).splitlines():
        if line.startswith("/" + prefix.name + "/share/licenses/"):
            candidate = prefix.parent / line.lstrip("/")
            if candidate.is_file():
                files.append(candidate)
    if not files:
        raise PackageError(f"No installed license text for {package}")
    return package, files


def copy_libraries(licenses: dict, prefix: Path, output: Path, pacman: Path) -> dict:
    packages = {}
    for library, (owner, texts) in licenses.items():
        shutil.copy2(library, output / library.name)
        packages[owner] = run(pacman, "-Q", owner).strip()
        for text in texts:
            target = output / "licenses" / owner / text.relative_to(prefix / "share/licenses")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(text, target)
    return packages


def package(source: Path, prefix: Path, output: Path) -> dict:
    if sys.platform != "win32":
        raise PackageError("Windows DLL closure must run on Windows")
    if output.exists():
        raise PackageError(f"Refusing existing output: {output}")
    binary = source / "bin/Transartica.exe"
    objdump, pacman = prefix / "bin/objdump.exe", prefix.parent / "usr/bin/pacman.exe"
    system = Path(os.environ["SystemRoot"]) / "System32"
    graph = closure(binary, prefix, objdump, system)
    licenses = {library: library_licenses(library, prefix, pacman) for library in graph if library != binary}
    output.mkdir(parents=True)
    install_staged(source / "bin/resources", output / "resources")
    shutil.copy2(binary, output / binary.name)
    packages = copy_libraries(licenses, prefix, output, pacman)
    receipt = {"format": "transartica-native-windows-v1", "runtime_tested": False,
               "packages": packages, "imports": {p.name: value for p, value in graph.items()},
               "files": {p.relative_to(output).as_posix(): sha(p) for p in output.rglob("*") if p.is_file()}}
    (output / "package-receipt.json").write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    return receipt


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ("source", "prefix", "output"):
        parser.add_argument("--" + name, type=Path, required=True)
    args = parser.parse_args()
    try:
        result = package(args.source.resolve(), args.prefix.resolve(), args.output.resolve())
        print(json.dumps({"files": len(result["files"]), "runtime_tested": False}))
    except (OSError, ValueError, KeyError, PackageError) as error:
        print(f"Windows packaging failed: {error}", file=sys.stderr)
        raise SystemExit(1)


if __name__ == "__main__":
    main()
