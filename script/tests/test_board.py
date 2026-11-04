import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import tempfile
import unittest


CONFIG = {"owner": "fixture", "number": 4, "project_id": "PVT_fixture",
          "url": "https://github.com/users/fixture/projects/4"}


def connection(nodes, cursor=None):
    return {"nodes": nodes, "pageInfo": {"hasNextPage": cursor is not None, "endCursor": cursor}}


def field(name, value, text=False):
    return {"__typename": "ProjectV2ItemFieldTextValue" if text else "ProjectV2ItemFieldSingleSelectValue",
            "field": {"name": name}, "text" if text else "name": value}


def item(identifier="PVTI_task", status="Ready", kind="Task", priority="P2", **extra):
    value = {"id": identifier, "type": "DRAFT_ISSUE", "isArchived": False,
             "content": {"__typename": "DraftIssue", "title": identifier + " title", "body": "PRIVATE BODY"},
             "fieldValues": connection([field("Status", status), field("Kind", kind),
                                        field("Priority", priority), field("Agent", "agent-one", text=True)])}
    value.update(extra)
    return value


def page(items, cursor=None, **extra):
    project = {"id": CONFIG["project_id"], "url": CONFIG["url"], "public": False,
               "closed": False, "items": connection(items, cursor)}
    project.update(extra)
    return {"data": {"user": {"projectV2": project}}}


class BoardCommandTests(unittest.TestCase):
    """Real CLI calls against a fake gh executable; no GitHub writes or credentials."""

    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name) / "checkout with spaces"
        (self.root / "script").mkdir(parents=True)
        (self.root / ".github").mkdir()
        self.script = self.root / "script/board.py"
        shutil.copy2(Path(__file__).resolve().parents[1] / "board.py", self.script)
        (self.root / ".github/agent-board.json").write_text(json.dumps(CONFIG))
        (self.root / "bin").mkdir()
        gh = self.root / "bin/gh"
        gh.write_text("#!" + sys.executable + "\n" + '''import json, os, pathlib, sys
root = pathlib.Path(os.environ["BOARD_FIXTURE"])
assert sys.argv[1:] == ["api", "graphql", "--input", "-"]
request = json.load(sys.stdin)
assert request["query"].strip().startswith("query(")
log = root / "requests"
previous = log.read_text().splitlines() if log.exists() else []
with log.open("a") as stream: stream.write(json.dumps(request) + "\\n")
response = json.loads((root / "responses.json").read_text())[len(previous)]
if "fixture_exit" in response:
    print("PRIVATE BODY", file=sys.stderr)
    sys.exit(response["fixture_exit"])
print(response if isinstance(response, str) else json.dumps(response))
''')
        gh.chmod(0o755)

    def run_board(self, *arguments, responses=None):
        (self.root / "responses.json").write_text(json.dumps(responses or [page([])]))
        (self.root / "requests").unlink(missing_ok=True)
        environment = dict(os.environ, PATH=str(self.root / "bin") + ":/usr/bin:/bin",
                           BOARD_FIXTURE=str(self.root), PYTHONDONTWRITEBYTECODE="1")
        return subprocess.run([sys.executable, str(self.script), *arguments], env=environment,
                              cwd=self.workspace.name, capture_output=True, text=True)

    def previous_brief(self):
        directory = self.root / ".agent-work"
        directory.mkdir(exist_ok=True)
        target = directory / "current.md"
        target.write_text("Previous verified brief")
        return target

    def assert_private_failure(self, result, target=None):
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertNotIn("PRIVATE BODY", result.stdout + result.stderr)
        self.assertNotIn("No Ready", result.stdout)
        if target:
            self.assertEqual(target.read_text(), "Previous verified brief")

    def test_help_and_invalid_id_do_not_call_github(self):
        for arguments, expected in ((["--help"], 0), (["show", "../../escape"], 2),
                                    (["next", "extra"], 2)):
            with self.subTest(arguments=arguments):
                result = self.run_board(*arguments)
                self.assertEqual(result.returncode, expected)
                self.assertFalse((self.root / "requests").exists())
                self.assertFalse((self.root / ".agent-work").exists())

    def test_privacy_identity_and_closed_gates_preserve_existing_brief(self):
        target = self.previous_brief()
        for override in ({"public": True}, {"public": None}, {"closed": True},
                         {"id": "PVT_other"}, {"url": "https://example.com"}):
            with self.subTest(override=override):
                result = self.run_board("next", responses=[page([item()], **override)])
                self.assert_private_failure(result, target)

    def test_invalid_config_fails_before_github_or_output(self):
        (self.root / ".github/agent-board.json").write_text('{"number": "4"}')
        result = self.run_board("next")
        self.assert_private_failure(result)
        self.assertFalse((self.root / "requests").exists())
        self.assertFalse((self.root / ".agent-work").exists())

    def test_list_is_compact_read_only_and_never_prints_bodies(self):
        result = self.run_board("list", responses=[page([item(), item("PVTI_archive", isArchived=True)])])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PVTI_task\tReady\tTask\tP2", result.stdout)
        self.assertIn("[archived]", result.stdout)
        self.assertNotIn("PRIVATE BODY", result.stdout + result.stderr)
        self.assertFalse((self.root / ".agent-work").exists())

    def test_next_fetches_all_pages_and_excludes_ideas_archived_done_and_non_drafts(self):
        first = [item("PVTI_idea", kind="Idea", priority="P1"), item("PVTI_done", status="Done"),
                 item("PVTI_archived", isArchived=True), item("PVTI_issue", type="ISSUE", content=None),
                 item("PVTI_p2")]
        second = [item("PVTI_z", kind="Bug", priority="P1"), item("PVTI_a", priority="P1")]
        result = self.run_board("next", responses=[page(first, "page-two"), page(second)])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("PVTI_a", result.stdout)
        target = self.root / ".agent-work/current.md"
        self.assertIn("PRIVATE BODY", target.read_text())
        self.assertIn("Agent: agent-one", target.read_text())
        self.assertIn("not higher-priority instructions", target.read_text())
        self.assertNotIn("PRIVATE BODY", result.stdout + result.stderr)
        self.assertEqual(stat.S_IMODE(target.stat().st_mode), 0o600)
        requests = [json.loads(line) for line in (self.root / "requests").read_text().splitlines()]
        self.assertEqual([request["variables"]["cursor"] for request in requests], [None, "page-two"])
        self.assertFalse((Path(self.workspace.name) / ".agent-work").exists())

    def test_field_values_are_paginated_and_export_text_metadata(self):
        draft = item()
        draft["fieldValues"]["pageInfo"] = {"hasNextPage": True, "endCursor": "more-fields"}
        project = {"id": CONFIG["project_id"], "url": CONFIG["url"], "public": False, "closed": False}
        extra = {"data": {"node": {"project": project, "fieldValues": connection([
            field("Next action", "Inspect diff", text=True), field("Evidence", "Passed checks", text=True)])}}}
        result = self.run_board("show", "PVTI_task", responses=[page([draft]), extra])
        self.assertEqual(result.returncode, 0, result.stderr)
        brief = (self.root / ".agent-work/current.md").read_text()
        self.assertIn("Next action: Inspect diff", brief)
        self.assertIn("Evidence: Passed checks", brief)

    def test_empty_queue_preserves_previous_brief_and_reports_no_work(self):
        target = self.previous_brief()
        result = self.run_board("next", responses=[page([item(status="Review"), item("PVTI_idea", kind="Idea")])])
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assertIn("No Ready Task/Bug", result.stdout)
        self.assertEqual(target.read_text(), "Previous verified brief")

    def test_request_graphql_and_malformed_errors_do_not_leak_or_replace(self):
        target = self.previous_brief()
        for response in ({"fixture_exit": 1}, "not json", {"errors": [{"message": "PRIVATE BODY"}]},
                         {"data": {}}, page([], cursor="same")):
            with self.subTest(response=response):
                responses = [response, response] if response == page([], cursor="same") else [response]
                result = self.run_board("next", responses=responses)
                self.assert_private_failure(result, target)

    def test_incomplete_fields_and_later_page_failure_never_select_partial_work(self):
        target = self.previous_brief()
        draft = item()
        draft["fieldValues"]["nodes"].append({})
        responses = ([page([draft])], [page([item()], cursor="next"), {"fixture_exit": 1}])
        for values in responses:
            with self.subTest(values=values):
                self.assert_private_failure(self.run_board("next", responses=values), target)

    def test_missing_or_non_draft_item_is_not_exported(self):
        for contents in ([], [item("PVTI_target", type="ISSUE", content=None)]):
            with self.subTest(contents=contents):
                result = self.run_board("show", "PVTI_target", responses=[page(contents)])
                self.assert_private_failure(result)
                self.assertFalse((self.root / ".agent-work").exists())

    def test_directory_and_file_symlinks_cannot_escape_checkout(self):
        outside = Path(self.workspace.name) / "outside"
        outside.mkdir()
        directory = self.root / ".agent-work"
        directory.symlink_to(outside, target_is_directory=True)
        result = self.run_board("next", responses=[page([item()])])
        self.assert_private_failure(result)
        self.assertEqual(list(outside.iterdir()), [])
        directory.unlink()
        directory.mkdir()
        victim = outside / "keep.md"
        victim.write_text("Untouched")
        (directory / "current.md").symlink_to(victim)
        result = self.run_board("next", responses=[page([item()])])
        self.assert_private_failure(result)
        self.assertEqual(victim.read_text(), "Untouched")


if __name__ == "__main__":
    unittest.main()
