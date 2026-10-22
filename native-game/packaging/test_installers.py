# SPDX-License-Identifier: MIT
"""Packaging boundary regressions; real host checks are separate delivery steps."""
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import Mock, patch

import macos_dmg
from macos_bundle import PackageError
import windows_bundle


class WindowsImports(unittest.TestCase):
    def test_package_rejects_wrong_host_and_existing_output(self):
        with patch.object(windows_bundle.sys, "platform", "darwin"), self.assertRaisesRegex(PackageError, "must run on Windows"):
            windows_bundle.package(Path("source"), Path("ucrt64"), Path("output"))
        with tempfile.TemporaryDirectory() as name, patch.object(windows_bundle.sys, "platform", "win32"):
            with self.assertRaisesRegex(PackageError, "Refusing existing output"):
                windows_bundle.package(Path("source"), Path("ucrt64"), Path(name))

    def test_package_copies_closure_resources_and_licenses(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            binary = root / "source/bin/Transartica.exe"
            binary.parent.mkdir(parents=True)
            binary.write_bytes(b"executable")
            prefix = root / "ucrt64"
            library = prefix / "bin/SDL2.dll"
            library.parent.mkdir(parents=True)
            library.write_bytes(b"dll")
            license_file = prefix / "share/licenses/SDL2/LICENSE"
            license_file.parent.mkdir(parents=True)
            license_file.write_text("license")
            output = root / "output"
            graph = {binary: ["SDL2.dll"], library: ["KERNEL32.dll"]}
            with patch.object(windows_bundle.sys, "platform", "win32"), patch.dict(os.environ, {"SystemRoot": str(root)}), patch.object(windows_bundle, "closure", return_value=graph), patch.object(windows_bundle, "library_licenses", return_value=("sdl-package", [license_file])), patch.object(windows_bundle, "run", return_value="sdl-package 2.0"), patch.object(windows_bundle, "install_staged") as stage:
                receipt = windows_bundle.package(root / "source", prefix, output)
            stage.assert_called_once_with(root / "source/bin/resources", output / "resources")
            self.assertFalse(receipt["runtime_tested"])
            self.assertEqual((output / "SDL2.dll").read_bytes(), b"dll")
            self.assertIn("licenses/sdl-package/SDL2/LICENSE", receipt["files"])
            self.assertEqual(json.loads((output / "package-receipt.json").read_text()), receipt)

    def test_api_contract_load_is_released_and_missing_contract_fails(self):
        kernel = Mock()
        kernel.LoadLibraryExW.return_value = 42
        kernel.FreeLibrary.return_value = 1
        with tempfile.TemporaryDirectory() as name, patch.object(windows_bundle.sys, "platform", "win32"), patch.object(windows_bundle.ctypes, "WinDLL", return_value=kernel, create=True):
            self.assertTrue(windows_bundle.system_dependency("api-ms-win-core-test-l1-1-0.dll", Path(name)))
            kernel.FreeLibrary.assert_called_once_with(42)
            kernel.LoadLibraryExW.return_value = None
            self.assertFalse(windows_bundle.system_dependency("api-ms-win-missing-l1-1-0.dll", Path(name)))
            kernel.LoadLibraryExW.return_value = 42
            kernel.FreeLibrary.return_value = 0
            with self.assertRaisesRegex(PackageError, "Could not release"):
                windows_bundle.system_dependency("api-ms-win-core-test-l1-1-0.dll", Path(name))

    def test_import_names_are_unique_and_sorted(self):
        self.assertEqual(windows_bundle.imports(" DLL Name: SDL2.dll\n DLL Name: KERNEL32.dll\n DLL Name: SDL2.dll\n"), ["KERNEL32.dll", "SDL2.dll"])

    def test_invalid_import_tables_fail(self):
        for table in ("not a PE", " DLL Name: ../outside.dll\n"):
            with self.subTest(table=table), self.assertRaises(PackageError):
                windows_bundle.imports(table)

    def test_recursive_dependency_closure_and_missing_import(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            (root / "prefix/bin").mkdir(parents=True)
            (root / "system").mkdir()
            library = root / "prefix/bin/SDL2.dll"
            library.touch()
            (root / "system/KERNEL32.dll").touch()
            binary = root / "Transartica.exe"
            binary.touch()
            def dump(*args):
                return "DLL Name: SDL2.dll\n" if args[-1] == binary else "DLL Name: KERNEL32.dll\n"
            with patch.object(windows_bundle, "run", side_effect=dump):
                graph = windows_bundle.closure(binary, root / "prefix", Path("objdump"), root / "system")
            self.assertEqual(set(graph), {binary, library})
            with patch.object(windows_bundle, "run", return_value="DLL Name: missing.dll\n"), self.assertRaisesRegex(PackageError, "Unresolved DLL missing.dll"):
                windows_bundle.closure(binary, root / "prefix", Path("objdump"), root / "system")

    def test_licenses_are_required_and_bound_to_package(self):
        with tempfile.TemporaryDirectory() as name:
            prefix = Path(name) / "ucrt64"
            license_file = prefix / "share/licenses/SDL2/LICENSE"
            license_file.parent.mkdir(parents=True)
            license_file.write_text("license")
            with patch.object(windows_bundle, "run", side_effect=["sdl-package\n", "/ucrt64/share/licenses/SDL2/LICENSE\n"]):
                self.assertEqual(windows_bundle.library_licenses(prefix / "bin/SDL2.dll", prefix, Path("pacman")), ("sdl-package", [license_file]))
            with patch.object(windows_bundle, "run", side_effect=["sdl-package", "/ucrt64/bin/SDL2.dll"]), self.assertRaisesRegex(PackageError, "No installed license"):
                windows_bundle.library_licenses(prefix / "bin/SDL2.dll", prefix, Path("pacman"))
            with patch.object(windows_bundle, "run", return_value="two packages"), self.assertRaisesRegex(PackageError, "Ambiguous package"):
                windows_bundle.library_licenses(prefix / "bin/SDL2.dll", prefix, Path("pacman"))


class DiskImage(unittest.TestCase):
    def test_wrong_host_refuses_before_touching_files(self):
        with patch.object(macos_dmg.sys, "platform", "win32"), self.assertRaisesRegex(PackageError, "requires macOS"):
            macos_dmg.create(Path("absent.app"), Path("absent.json"), Path("new.dmg"), Path("scratch"))

    def test_image_verification_success_also_detaches(self):
        with tempfile.TemporaryDirectory() as name, patch.object(macos_dmg, "run") as run, patch.object(macos_dmg, "verify", return_value={"files_verified": 3}):
            mount = Path(name)
            (mount / "Applications").symlink_to("/Applications")
            self.assertEqual(macos_dmg.mounted_check(Path("image.dmg"), mount, "Transartica.app", Path("receipt")), {"files_verified": 3})
            self.assertEqual(run.call_args.args, ("/usr/bin/hdiutil", "detach", mount))

    def test_receipt_publication_failure_rolls_back_own_image(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            candidate, output, report = root / "candidate.dmg", root / "output.dmg", root / "receipt.json"
            candidate.write_bytes(b"image")
            report.write_text("keep")
            with self.assertRaises(FileExistsError):
                macos_dmg.publish(candidate, output, report, {"test": True})
            self.assertFalse(output.exists())
            self.assertEqual(report.read_text(), "keep")
            self.assertEqual(candidate.read_bytes(), b"image")

    def test_publication_preserves_bytes(self):
        with tempfile.TemporaryDirectory() as name:
            root = Path(name)
            candidate, output, report = root / "candidate.dmg", root / "output.dmg", root / "receipt.json"
            candidate.write_bytes(b"image")
            macos_dmg.publish(candidate, output, report, {"test": True})
            self.assertEqual(output.read_bytes(), b"image")
            self.assertEqual(json.loads(report.read_text()), {"test": True})

    def test_mounted_failure_always_detaches(self):
        with tempfile.TemporaryDirectory() as name:
            mount = Path(name)
            (mount / "Applications").symlink_to("/Applications")
            with patch.object(macos_dmg, "run") as run, patch.object(macos_dmg, "verify", side_effect=PackageError("tampered")), self.assertRaisesRegex(PackageError, "tampered"):
                macos_dmg.mounted_check(Path("image.dmg"), mount, "Transartica.app", Path("receipt"))
            self.assertEqual(run.call_args.args, ("/usr/bin/hdiutil", "detach", mount))

    def test_invalid_applications_link_fails_and_detaches(self):
        with tempfile.TemporaryDirectory() as name, patch.object(macos_dmg, "run") as run:
            with self.assertRaisesRegex(PackageError, "Applications link"):
                macos_dmg.mounted_check(Path("image.dmg"), Path(name), "Transartica.app", Path("receipt"))
            self.assertEqual(run.call_args.args[1], "detach")

    def test_existing_destination_is_untouched(self):
        with tempfile.TemporaryDirectory() as name, patch.object(macos_dmg.sys, "platform", "darwin"):
            output = Path(name) / "owned.dmg"
            output.write_bytes(b"keep")
            with self.assertRaisesRegex(PackageError, "new .dmg"):
                macos_dmg.create(Path("absent.app"), Path("absent.json"), output, Path(name))
            self.assertEqual(output.read_bytes(), b"keep")


if __name__ == "__main__":
    unittest.main()
