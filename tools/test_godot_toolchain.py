"""Version/template isolation checks; no installed editor or network required."""
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import godot_toolchain as toolchain


class ToolchainTests(unittest.TestCase):
    def test_release_names_and_editor_settings_versions(self):
        for full, templates, release, minor in [
            ("4.7.stable.official.abc123", "4.7.stable", "4.7-stable", "4.7"),
            ("4.8.beta3.official.c51ff06e8", "4.8.beta3", "4.8-beta3", "4.8"),
            ("4.8.1.stable.official.abc123", "4.8.1.stable", "4.8.1-stable", "4.8"),
        ]:
            with self.subTest(full=full):
                version = toolchain.parse_version(full + "\n")
                self.assertEqual((version.templates, version.release, version.minor), (templates, release, minor))

    def test_unknown_version_fails_closed(self):
        for output in ["", "Godot 4.8", "4.8.beta3", "4.8.custom.abc", "../4.7.stable.official.abc"]:
            with self.subTest(output=output), self.assertRaises(ValueError):
                toolchain.parse_version(output)

    def test_never_uses_47_template_for_48_editor(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            old = root / "build/tools/godot-windows-templates/4.7.stable/windows_debug_x86_64.exe"
            old.parent.mkdir(parents=True)
            old.write_bytes(b"old template")
            version = toolchain.parse_version("4.8.beta3.official.c51ff06e8")
            with patch.object(toolchain, "ROOT", root), patch.object(toolchain, "engine_version", return_value=version), \
                    patch.dict(os.environ, {"APPDATA": str(root / "profile")}):
                with self.assertRaises(FileNotFoundError):
                    toolchain.template_path("editor", old.name)
                installed = root / "profile/Godot/export_templates/4.8.beta3" / old.name
                installed.parent.mkdir(parents=True)
                installed.write_bytes(b"new template")
                self.assertEqual(toolchain.template_path("editor", old.name), installed)
                local = root / "build/tools/godot-windows-templates/4.8.beta3" / old.name
                local.parent.mkdir(parents=True)
                local.write_bytes(b"new local template")
                self.assertEqual(toolchain.template_path("editor", old.name), local)

    def test_portable_export_copies_editor_instead_of_console_launcher(self):
        with tempfile.TemporaryDirectory() as directory:
            editor = Path(directory) / "Godot_v4.8-beta3_win64.exe"
            launcher = editor.with_name("Godot_v4.8-beta3_win64_console.exe")
            launcher.write_bytes(b"wrapper")
            with self.assertRaises(FileNotFoundError):
                toolchain.editor_binary(launcher)
            editor.write_bytes(b"editor")
            self.assertEqual(toolchain.editor_binary(launcher), editor)
            self.assertEqual(toolchain.editor_binary(editor), editor)


if __name__ == "__main__":
    unittest.main()
