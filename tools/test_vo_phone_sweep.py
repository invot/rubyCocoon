"""Recovery regressions: an unavailable phone must not mask errors or overwrite identity."""
from contextlib import nullcontext
import json
from pathlib import Path
import subprocess
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import vo_phone_sweep as sweep


class Recovery(unittest.TestCase):
    def test_completed_attach_does_not_require_pid_or_relaunch(self):
        args = SimpleNamespace(sdk="unused", serial="test", attach=True)
        report = {"passes": [{}, {}, {}], "problems": 0, "focus_losses": []}
        commands = []
        def fake_call(command, **kwargs):
            commands.append(command)
            if "stdout" in kwargs:
                kwargs["stdout"].write(b"archive")
            return subprocess.CompletedProcess(command, 0, "")
        with tempfile.TemporaryDirectory(prefix="vo-phone-test-") as folder:
            out = Path(folder)
            (out / "temperatures.json").write_text(json.dumps([{"elapsed_s": 30}]))
            with patch.object(sweep.phone, "OUT", out), patch.object(sweep.phone, "TARGET_PASSES", 3), \
                 patch.object(sweep.phone, "call", side_effect=fake_call), \
                 patch.object(sweep.phone.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, json.dumps(report).encode())), \
                 patch.object(sweep.phone.subprocess, "Popen") as popen:
                sweep.phone.record(args)
            self.assertEqual(json.loads((out / "report.json").read_text()), report)
            self.assertEqual((out / "phone-files.tar").read_bytes(), b"archive")
            self.assertTrue(json.loads((out / "observer-recovery.json").read_text())["completed_checkpoint"])
            popen.assert_not_called()
            self.assertFalse(any("install" in c or "clear" in c or "start" in c or "pidof" in c for c in commands))

    def test_completed_attach_preserves_invalid_report(self):
        args = SimpleNamespace(sdk="unused", serial="test", attach=True)
        report = {"passes": [{}, {}, {}], "problems": 1, "focus_losses": [123]}
        with tempfile.TemporaryDirectory(prefix="vo-phone-test-") as folder:
            out = Path(folder)
            (out / "temperatures.json").write_text(json.dumps([{"elapsed_s": 30}]))
            with patch.object(sweep.phone, "OUT", out), patch.object(sweep.phone, "TARGET_PASSES", 3), \
                 patch.object(sweep.phone, "call", return_value=subprocess.CompletedProcess([], 0, "")), \
                 patch.object(sweep.phone.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, json.dumps(report).encode())):
                with self.assertRaisesRegex(RuntimeError, "interrupted"):
                    sweep.phone.record(args)
            self.assertEqual(json.loads((out / "report.json").read_text()), report)
            self.assertFalse((out / "phone-files.tar").exists())

    def test_usb_cleanup_preserves_original_error(self):
        args = SimpleNamespace(sdk="unused", serial="test", attach=False)
        responses = [subprocess.CompletedProcess([], 0, "player-original\n"),
                     subprocess.CompletedProcess([], 1, ""), subprocess.CompletedProcess([], 1, "")]
        with tempfile.TemporaryDirectory(prefix="vo-phone-test-") as folder:
            out = Path(folder)
            with patch.object(sweep.phone, "OUT", out), patch.object(sweep, "model_lock", return_value=nullcontext()), \
                 patch.object(sweep.subprocess, "run", side_effect=responses), patch.object(sweep.phone, "call"), \
                 patch.object(sweep.phone, "record", side_effect=ConnectionError("original USB disconnect")):
                with self.assertRaisesRegex(ConnectionError, "original USB disconnect"):
                    sweep.run(args)
            self.assertEqual((out / "player-package-before.txt").read_text(), "player-original\n")
            self.assertFalse((out / "player-package-after.txt").exists())
            self.assertTrue(json.loads((out / "cleanup.json").read_text())["recover_observer_if_still_running"])

    def test_attach_preserves_and_checks_first_snapshot(self):
        args = SimpleNamespace(sdk="unused", serial="test", attach=True)
        with tempfile.TemporaryDirectory(prefix="vo-phone-test-") as folder:
            out = Path(folder)
            snapshot = out / "player-package-before.txt"
            snapshot.write_text("player-original\n")
            with patch.object(sweep.phone, "OUT", out), patch.object(sweep, "model_lock", return_value=nullcontext()), \
                 patch.object(sweep.subprocess, "run", return_value=subprocess.CompletedProcess([], 0, "changed\n")), \
                 patch.object(sweep.phone, "record") as record:
                with self.assertRaisesRegex(RuntimeError, "original snapshot preserved"):
                    sweep.run(args)
                record.assert_not_called()
            self.assertEqual(snapshot.read_text(), "player-original\n")


if __name__ == "__main__":
    unittest.main()
