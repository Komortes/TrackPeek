from concurrent.futures import ThreadPoolExecutor
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


class AgentCommandTests(unittest.TestCase):
    """Exercise the CLI in an isolated checkout without invoking native apps."""

    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name) / "fixture checkout"
        (self.root / "script").mkdir(parents=True)
        self.script = self.root / "script/agent.sh"
        shutil.copy2(Path(__file__).resolve().parents[1] / "agent.sh", self.script)
        self.docs = self.root / "docs/agents"
        self.docs.mkdir(parents=True)
        (self.docs / "STATE.md").write_text("Fixture current state\n", encoding="utf-8")
        (self.docs / "TASK_TEMPLATE.md").write_text(
            "# {{SLUG}}\nDate: {{DATE}}\nBase: {{BASE_COMMIT}}\nLeave {{OTHER}} alone.\n",
            encoding="utf-8",
        )
        (self.root / "bin").mkdir()
        self.stub("date", 'echo 2026-11-04\n')
        self.stub("uname", 'echo Darwin\n')
        self.stub("git", '''case "$*" in
  *"symbolic-ref --quiet --short HEAD") echo fixture-branch ;;
  *"rev-parse --verify HEAD") echo aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa ;;
  *"status --short") echo ' M tracked-file' ;;
  *"diff --stat="*|*"diff --cached --stat="*) echo ' fixture diff summary' ;;
  --version) echo 'git fixture version' ;;
  *) exit 99 ;;
esac
''')
        for command in ("sw_vers", "python-fixture", "xcodebuild", "xcrun", "xcodegen",
                        "actionlint", "shellcheck", "gh"):
            self.stub(command, 'echo "fixture version: $*"\n')

    def stub(self, name, body):
        path = self.root / "bin" / name
        path.write_text('#!/bin/sh\nprintf "%s\\n" "' + name
                        + ' $*" >> "$AGENT_FIXTURE_ROOT/invoked"\n' + body)
        path.chmod(0o755)

    def run_agent(self, *arguments, **overrides):
        environment = dict(os.environ, PATH=f"{self.root / 'bin'}:/usr/bin:/bin",
                           AGENT_FIXTURE_ROOT=str(self.root),
                           TRACKPEEK_PYTHON=str(self.root / "bin/python-fixture"))
        environment.update(overrides)
        return subprocess.run(["/bin/bash", str(self.script), *arguments],
                              cwd=self.workspace.name, env=environment,
                              capture_output=True, text=True)

    def test_help_and_invalid_arguments_have_no_side_effects(self):
        for arguments, code in (((), 0), (("--help",), 0), (("unknown",), 2),
                                (("doctor", "extra"), 2), (("new-task",), 2),
                                (("next", "extra"), 2), (("show",), 2),
                                (("show", "../escape"), 2),
                                (("new-task", "../escape"), 2),
                                (("new-task", "bad--slug"), 2),
                                (("new-task", "$(touch injected)"), 2),
                                (("new-task", "valid", "extra"), 2)):
            with self.subTest(arguments=arguments):
                result = self.run_agent(*arguments)
                self.assertEqual(result.returncode, code, result.stdout + result.stderr)
                self.assertIn("usage:", result.stdout + result.stderr)
                self.assertFalse((self.root / ".agent-work/tasks").exists())
                self.assertFalse((self.root / "invoked").exists())

    def test_task_creation_from_another_directory_replaces_only_known_fields(self):
        result = self.run_agent("new-task", "small-fix")
        self.assertEqual(result.returncode, 0, result.stderr)
        target = self.root / ".agent-work/tasks/2026-11-04-small-fix.md"
        self.assertEqual(target.read_text(),
                         "# small-fix\nDate: 2026-11-04\nBase: " + "a" * 40
                         + "\nLeave {{OTHER}} alone.\n")
        self.assertIn(".agent-work/tasks/2026-11-04-small-fix.md", result.stdout)
        self.assertFalse((Path(self.workspace.name) / "docs").exists())
        self.assertEqual(target.stat().st_mode & 0o777, 0o600)

    def test_private_task_directory_cannot_redirect_writes(self):
        outside = Path(self.workspace.name) / "outside"
        outside.mkdir()
        (self.root / ".agent-work").symlink_to(outside, target_is_directory=True)
        result = self.run_agent("new-task", "private-task")
        self.assertEqual(result.returncode, 1)
        self.assertIn("symbolic links", result.stderr)
        self.assertEqual(list(outside.iterdir()), [])

    def test_board_commands_delegate_arguments_without_changing_directory(self):
        (self.root / "script/board.py").write_text(
            'import sys\nprint("|".join(sys.argv[1:]))\n'
        )
        for args, expected in ((("board",), "list"), (("next",), "next"),
                               (("show", "PVTI_example"), "show|PVTI_example")):
            with self.subTest(args=args):
                result = self.run_agent(*args, TRACKPEEK_PYTHON=sys.executable)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout.strip(), expected)

    def test_existing_task_is_preserved(self):
        self.assertEqual(self.run_agent("new-task", "existing").returncode, 0)
        target = self.root / ".agent-work/tasks/2026-11-04-existing.md"
        target.write_text("Existing work must survive.\n")
        result = self.run_agent("new-task", "existing")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(target.read_text(), "Existing work must survive.\n")
        self.assertIn("never replaced", result.stderr)

    def test_concurrent_task_creation_has_exactly_one_winner(self):
        with ThreadPoolExecutor(max_workers=2) as executor:
            results = list(executor.map(lambda _: self.run_agent("new-task", "race"), range(2)))
        self.assertEqual(sorted(result.returncode for result in results), [0, 1])
        target = self.root / ".agent-work/tasks/2026-11-04-race.md"
        self.assertEqual(target.read_text().count("# race"), 1)
        self.assertEqual(len(list((self.root / ".agent-work/tasks").iterdir())), 1)

    def test_missing_template_fails_before_creating_task_directory(self):
        (self.docs / "TASK_TEMPLATE.md").unlink()
        result = self.run_agent("new-task", "no-template")
        self.assertEqual(result.returncode, 1)
        self.assertIn("Missing task template", result.stderr)
        self.assertFalse((self.root / ".agent-work/tasks").exists())
        self.assertFalse((self.root / "invoked").exists())

    def test_context_is_bounded_and_uses_only_read_only_git_commands(self):
        (self.docs / "STATE.md").write_text("Current state\n" * 100 + "HIDDEN TAIL\n")
        (self.root / ".agent-work/tasks").mkdir(parents=True)
        for number in range(35):
            (self.root / ".agent-work/tasks" / f"task-{number:02d}.md").write_text("Existing task\n")
        result = self.run_agent("context")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("fixture-branch", result.stdout)
        self.assertIn(" M tracked-file", result.stdout)
        self.assertNotIn("HIDDEN TAIL", result.stdout)
        self.assertIn("task-29.md", result.stdout)
        self.assertNotIn("task-30.md", result.stdout)
        commands = (self.root / "invoked").read_text().splitlines()
        self.assertEqual(len(commands), 5)
        self.assertTrue(all(command.startswith("git ") for command in commands))
        self.assertTrue(any("--no-optional-locks" in command for command in commands))
        self.assertFalse((self.root / ".build").exists())

    def test_doctor_queries_versions_without_running_build_or_ci(self):
        result = self.run_agent("doctor")
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = (self.root / "invoked").read_text().splitlines()
        self.assertEqual(commands, ["uname -s", "sw_vers ", "git --version", "gh --version",
                                   "python-fixture --version", "xcodebuild -version",
                                   "xcrun swiftc --version", "xcodegen --version",
                                   "actionlint -version", "shellcheck --version"])
        self.assertFalse((self.root / ".build").exists())
        self.assertFalse((self.root / ".agent-work/tasks").exists())

    def test_doctor_reports_all_failures_instead_of_stopping_at_first(self):
        self.stub("xcodebuild", "exit 65\n")
        self.stub("xcodegen", "exit 7\n")
        result = self.run_agent("doctor", TRACKPEEK_PYTHON=str(self.root / "missing-python"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("MISSING:", result.stderr)
        self.assertIn("FAILED: xcodebuild", result.stderr)
        self.assertIn("FAILED: xcodegen", result.stderr)
        self.assertIn("Failures: 3", result.stdout)
        self.assertIn("shellcheck --version", (self.root / "invoked").read_text())


if __name__ == "__main__":
    unittest.main()
