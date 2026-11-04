import os
from pathlib import Path
import subprocess
import tempfile
import unittest


class BuildAndRunCommandTests(unittest.TestCase):
    """Exercise CLI boundaries without touching running apps or building Xcode."""

    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name) / "fixture checkout"
        (self.root / "script").mkdir(parents=True)
        (self.root / "bin").mkdir()
        self.script = self.root / "script/build_and_run.sh"
        source = Path(__file__).resolve().parents[1] / "build_and_run.sh"
        # Redirect fixed system paths only in the isolated script copy, as in
        # test_release.py. No real launcher or log stream can run in these tests.
        self.script.write_text(source.read_text().replace("/usr/bin/open", "open")
                               .replace("/usr/bin/log", "log"))
        self.invoked = self.root / "invoked"
        for name in ("pkill", "xcodebuild", "open", "lldb", "log", "sleep", "pgrep"):
            path = self.root / "bin" / name
            status = {"xcodebuild": "BUILD_RUN_TEST_BUILD_STATUS",
                      "pgrep": "BUILD_RUN_TEST_PROCESS_STATUS"}.get(name)
            path.write_text('#!/bin/sh\nprintf "%s\\n" "' + name
                            + ' $*" >> "$BUILD_RUN_TEST_ROOT/invoked"\n'
                            + (f'exit "${{{status}}}"\n' if status else "exit 0\n"))
            path.chmod(0o755)

    def run_script(self, *arguments, build_status=0, process_status=0):
        if self.invoked.exists():
            self.invoked.unlink()
        environment = dict(os.environ, PATH=f"{self.root / 'bin'}:/usr/bin:/bin",
                           BUILD_RUN_TEST_ROOT=str(self.root),
                           BUILD_RUN_TEST_BUILD_STATUS=str(build_status),
                           BUILD_RUN_TEST_PROCESS_STATUS=str(process_status))
        return subprocess.run(["/bin/bash", str(self.script), *arguments],
                              cwd=self.workspace.name, env=environment,
                              capture_output=True, text=True)

    def commands(self):
        return self.invoked.read_text().splitlines() if self.invoked.exists() else []

    def test_help_prints_usage_without_invoking_tools(self):
        result = self.run_script("--help")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("usage:", result.stdout)
        self.assertEqual(result.stderr, "")
        self.assertEqual(self.commands(), [])

    def test_unknown_and_empty_modes_fail_before_invoking_tools(self):
        for mode in ("unexpected", "", "--unknown"):
            with self.subTest(mode=mode):
                result = self.run_script(mode)
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertIn("usage:", result.stderr)
                self.assertEqual(self.commands(), [])

    def test_extra_arguments_fail_before_invoking_tools(self):
        for mode in ("run", "--debug", "--logs", "--telemetry", "--verify", "--help"):
            with self.subTest(mode=mode):
                result = self.run_script(mode, "extra")
                self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
                self.assertIn("usage:", result.stderr)
                self.assertEqual(self.commands(), [])

    def test_default_run_and_existing_aliases_preserve_actions(self):
        app = self.root / ".build/xcode/Build/Products/Debug/TrackPeek.app"
        cases = [((), [f"open -n {app}"]), (("run",), [f"open -n {app}"])]
        actions = {
            "debug": [f"lldb -- {app}/Contents/MacOS/TrackPeek"],
            "logs": [f"open -n {app}",
                     'log stream --info --style compact --predicate process == "TrackPeek"'],
            "telemetry": [f"open -n {app}",
                          'log stream --info --style compact --predicate subsystem == "com.trackpeek.TrackPeek"'],
            "verify": [f"open -n {app}", "sleep 2", "pgrep -x TrackPeek"],
        }
        for mode, expected in actions.items():
            cases.extend([((mode,), expected), ((f"--{mode}",), expected)])
        for arguments, expected in cases:
            with self.subTest(arguments=arguments):
                result = self.run_script(*arguments)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                commands = self.commands()
                self.assertEqual(commands[0], "pkill -x TrackPeek")
                self.assertTrue(commands[1].startswith("xcodebuild -project "))
                self.assertIn("-destination platform=macOS,arch=arm64", commands[1])
                self.assertEqual(commands[2:], expected)

    def test_failed_build_does_not_launch_app(self):
        result = self.run_script("run", build_status=65)
        self.assertEqual(result.returncode, 65, result.stdout + result.stderr)
        self.assertEqual([command.split()[0] for command in self.commands()],
                         ["pkill", "xcodebuild"])

    def test_verify_preserves_process_check_failure(self):
        result = self.run_script("--verify", process_status=1)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertEqual(self.commands()[-1], "pgrep -x TrackPeek")


if __name__ == "__main__":
    unittest.main()
