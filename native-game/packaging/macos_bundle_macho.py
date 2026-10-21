# SPDX-License-Identifier: MIT
"""Mach-O load-command parsing and dyld path interpretation for private bundles."""
from __future__ import annotations

from pathlib import Path
import re

LOAD_COMMANDS = {"LC_LOAD_DYLIB", "LC_LOAD_WEAK_DYLIB", "LC_REEXPORT_DYLIB", "LC_LOAD_UPWARD_DYLIB", "LC_LAZY_LOAD_DYLIB"}
SYSTEM_ROOTS = ("/usr/lib/", "/System/Library/")


class PackageError(RuntimeError):
    pass


def macho_commands(text: str) -> dict:
    """Parse Apple's otool -l load-command records, including paths with spaces."""
    result = {"loads": [], "rpaths": [], "id": None, "minimum": []}
    for block in re.split(r"(?m)^Load command \d+\s*$", text)[1:]:
        found = re.search(r"(?m)^\s*cmd (LC_\w+)\s*$", block)
        if not found:
            continue
        command = found[1]
        if command in LOAD_COMMANDS or command == "LC_ID_DYLIB":
            name = re.search(r"(?m)^\s*name (.+) \(offset \d+\)\s*$", block)
            if not name:
                raise PackageError("Unrecognized Mach-O dylib load record")
            if command == "LC_ID_DYLIB":
                result["id"] = name[1]
            else:
                result["loads"].append(name[1])
        elif command == "LC_RPATH":
            name = re.search(r"(?m)^\s*path (.+) \(offset \d+\)\s*$", block)
            if not name:
                raise PackageError("Unrecognized Mach-O rpath record")
            result["rpaths"].append(name[1])
        elif command in ("LC_BUILD_VERSION", "LC_VERSION_MIN_MACOSX"):
            value = re.search(r"(?m)^\s*(?:minos|version) ([0-9.]+)\s*$", block)
            if value:
                result["minimum"].append(value[1])
    result["loads"] = list(dict.fromkeys(result["loads"]))
    result["rpaths"] = list(dict.fromkeys(result["rpaths"]))
    return result


def system_library(name: str) -> bool:
    return name.startswith(SYSTEM_ROOTS)


def expand_path(name: str, loader: Path, executable: Path) -> Path:
    if name == "@loader_path" or name.startswith("@loader_path/"):
        return loader.parent / name.removeprefix("@loader_path").lstrip("/")
    if name == "@executable_path" or name.startswith("@executable_path/"):
        return executable.parent / name.removeprefix("@executable_path").lstrip("/")
    value = Path(name)
    if not value.is_absolute():
        raise PackageError(f"Nonportable unresolved dyld path: {name}")
    return value
