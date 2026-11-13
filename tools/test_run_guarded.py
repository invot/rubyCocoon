"""Exercise cutoff behavior with small real children, without allocating large memory."""
import io
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

import run_guarded as guard

HEALTHY = guard.Memory(0, 64 * 1024 * guard.MIB, 32 * 1024 * guard.MIB)


class GuardTests(unittest.TestCase):
    def test_preserves_child_exit_code(self):
        self.assertEqual(guard.run([sys.executable, "-c", "raise SystemExit(7)"],
                                   sample=lambda pid: HEALTHY, interval=0.01), 7)

    def test_child_output_reaches_explicit_log(self):
        with tempfile.TemporaryFile() as output:
            code = guard.run([sys.executable, "-c", "print('child output')"],
                             sample=lambda pid: HEALTHY, stdout=output, stderr=output, log=io.StringIO())
            output.seek(0)
            self.assertEqual(code, 0)
            self.assertIn(b"child output", output.read())

    def test_low_commit_does_not_launch_child(self):
        output = io.StringIO()
        with patch.object(guard.subprocess, "Popen") as spawn:
            code = guard.run([sys.executable, "-c", "raise SystemExit(0)"],
                             sample=lambda pid: guard.Memory(0, 1, HEALTHY.free_ram), log=output)
        self.assertEqual(code, guard.MEMORY_EXIT)
        spawn.assert_not_called()
        self.assertIn("not started", output.getvalue())

    def test_memory_cutoff_stops_real_child(self):
        children = []
        real_spawn = subprocess.Popen
        def spawn(*args, **kwargs):
            child = real_spawn(*args, **kwargs)
            children.append(child)
            return child
        def sample(pid):
            return HEALTHY if pid is None else guard.Memory(5 * 1024 * guard.MIB, HEALTHY.free_commit, HEALTHY.free_ram)
        output = io.StringIO()
        with patch.object(guard.subprocess, "Popen", side_effect=spawn):
            code = guard.run([sys.executable, "-c", "import time; time.sleep(30)"], sample=sample, log=output)
        self.assertEqual(code, guard.MEMORY_EXIT)
        self.assertIsNotNone(children[0].poll())
        self.assertIn("GUARD MEMORY", output.getvalue())

    def test_timeout_stops_real_child(self):
        output = io.StringIO()
        started = time.monotonic()
        code = guard.run([sys.executable, "-c", "import time; time.sleep(30)"],
                         timeout=0.05, sample=lambda pid: HEALTHY, interval=0.01, log=output)
        self.assertEqual(code, 124)
        self.assertLess(time.monotonic() - started, 5)
        self.assertIn("GUARD TIMEOUT", output.getvalue())


if __name__ == "__main__":
    unittest.main()
