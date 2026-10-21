import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class CICommandTests(unittest.TestCase):
    """Test CI failure propagation without building or launching an app."""

    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        (self.root / "script").mkdir()
        shutil.copy2(Path(__file__).resolve().parents[1] / "ci.sh", self.root / "script/ci.sh")
        (self.root / "bin").mkdir()
        self.stub("uname", 'case "$1" in -s) echo Darwin ;; -m) echo arm64 ;; esac\n')
        self.stub("xcodebuild", '''if [ "$1" = -version ]; then echo 'fixture Xcode'; exit 0; fi
previous=''
for argument do
  case "$previous" in
    -resultBundlePath) mkdir -p "$argument" ;;
    -derivedDataPath) derived_data="$argument" ;;
  esac
  previous="$argument"
done
if [ "${CI_FIXTURE_HELPER:-0}" = 1 ]; then
  helper="$derived_data/Build/Products/Debug/TrackPeek.app/Contents/Helpers/TrackPeekScriptHelper"
  mkdir -p "$(dirname "$helper")"
  printf '#!/bin/sh\\nexit 0\\n' > "$helper"
  chmod +x "$helper"
fi
echo 'fixture test output'
echo 'fixture test diagnostics' >&2
exit "$CI_FIXTURE_TEST_STATUS"
''')
        self.stub("xcrun", '''if [ "$1" = swiftc ]; then echo 'fixture Swift'; exit 0; fi
echo 'fixture exported report'
exit "$CI_FIXTURE_REPORT_STATUS"
''')
        self.report = self.root / ".build/ci/test"

    def stub(self, name, body):
        path = self.root / "bin" / name
        path.write_text('#!/bin/sh\nprintf "%s\\n" "$0 $*" >> "$CI_FIXTURE_ROOT/invoked"\n' + body)
        path.chmod(0o755)

    def run_ci(self, *arguments, test_status=65, report_status=0, helper=False):
        environment = dict(os.environ, PATH=f"{self.root / 'bin'}:{os.environ['PATH']}",
                           CI_FIXTURE_ROOT=str(self.root), CI_FIXTURE_TEST_STATUS=str(test_status),
                           CI_FIXTURE_REPORT_STATUS=str(report_status), CI_FIXTURE_HELPER=str(int(helper)))
        return subprocess.run(["bash", str(self.root / "script/ci.sh"), *arguments],
                              env=environment, capture_output=True, text=True)

    def test_unsupported_mode_fails_before_invoking_tools_or_creating_reports(self):
        result = self.run_ci("publish")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("usage:", result.stderr)
        self.assertFalse((self.root / "invoked").exists())
        self.assertFalse((self.root / ".build").exists())

    def test_extra_arguments_fail_before_invoking_tools_or_creating_reports(self):
        result = self.run_ci("test", "unexpected")
        self.assertEqual(result.returncode, 2, result.stdout + result.stderr)
        self.assertIn("usage:", result.stderr)
        self.assertFalse((self.root / "invoked").exists())
        self.assertFalse((self.root / ".build").exists())

    def test_test_failure_survives_logging_and_report_collection(self):
        result = self.run_ci("test")
        self.assertEqual(result.returncode, 65, result.stdout + result.stderr)
        log = (self.report / "run.log").read_text()
        self.assertIn("fixture test output", log)
        self.assertIn("fixture test diagnostics", log)
        self.assertIn("Test command exit status: 65", log)
        self.assertIn("fixture exported report", (self.report / "test-summary.json").read_text())

    def test_failed_report_exports_cannot_replace_the_original_test_failure(self):
        result = self.run_ci("test", test_status=42, report_status=73)
        self.assertEqual(result.returncode, 42, result.stdout + result.stderr)
        log = (self.report / "run.log").read_text()
        self.assertIn("Test summary could not be exported", log)
        self.assertIn("Coverage JSON could not be exported", log)
        self.assertIn("Coverage text could not be exported", log)
        self.assertIn("Test command exit status: 42", log)

    def test_successful_test_command_without_embedded_helper_is_a_failure(self):
        result = self.run_ci("test", test_status=0)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("missing its embedded script helper", (self.report / "run.log").read_text())

    def test_successful_test_command_with_helper_keeps_success_if_reports_fail(self):
        result = self.run_ci("test", test_status=0, report_status=73, helper=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Test command exit status: 0", (self.report / "run.log").read_text())


if __name__ == "__main__":
    unittest.main()
