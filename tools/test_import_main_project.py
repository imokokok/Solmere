import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from import_main_project import BOOTSTRAP, import_project, run_pass


class ImportTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.project = self.root / "project.godot"
        self.original = b'config_version=5\r\n[autoload]\r\nGame="*res://game.gd"\r\n'
        self.project.write_bytes(self.original)
        self.logs = self.root / "logs"

    def test_both_passes_and_exact_restore(self):
        observed = []
        with patch("import_main_project.run_pass", side_effect=lambda *a: observed.append(self.project.read_bytes())):
            import_project("godot", self.root, self.logs)
        self.assertEqual(observed, [BOOTSTRAP, self.original])
        self.assertEqual(self.project.read_bytes(), self.original)
        self.assertFalse((self.logs / "project.godot.before-import").exists())

    def test_bootstrap_failure_and_timeout_restore_without_running_final(self):
        for error in (RuntimeError("failed"), subprocess.TimeoutExpired("godot", 1)):
            with self.subTest(error=type(error).__name__), patch("import_main_project.run_pass", side_effect=error) as runner:
                with self.assertRaises(type(error)):
                    import_project("godot", self.root, self.logs)
                self.assertEqual(runner.call_count, 1)
                self.assertEqual(self.project.read_bytes(), self.original)

    def test_interrupted_backup_is_not_overwritten(self):
        self.logs.mkdir()
        backup = self.logs / "project.godot.before-import"
        backup.write_bytes(b"previous original")
        with self.assertRaises(RuntimeError):
            import_project("godot", self.root, self.logs)
        self.assertEqual(backup.read_bytes(), b"previous original")
        self.assertEqual(self.project.read_bytes(), self.original)

    def test_zero_exit_with_engine_error_is_failure(self):
        def run(*args, **kwargs):
            kwargs["stdout"].write(b"SCRIPT ERROR: missing texture\n")
            return subprocess.CompletedProcess(args, 0)
        with patch("import_main_project.subprocess.run", side_effect=run):
            with self.assertRaises(RuntimeError):
                run_pass("godot", self.root, self.root / "error.log", 1)

    def test_nonzero_exit_without_engine_prefix_is_failure(self):
        with patch("import_main_project.subprocess.run", return_value=subprocess.CompletedProcess([], 134)):
            with self.assertRaises(RuntimeError):
                run_pass("godot", self.root, self.root / "abort.log", 1)

    def test_final_failure_still_keeps_original_project(self):
        with patch("import_main_project.run_pass", side_effect=[None, RuntimeError("final failed")]) as runner:
            with self.assertRaises(RuntimeError):
                import_project("godot", self.root, self.logs)
        self.assertEqual(runner.call_count, 2)
        self.assertEqual(self.project.read_bytes(), self.original)


if __name__ == "__main__":
    unittest.main()
