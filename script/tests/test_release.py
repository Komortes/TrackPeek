import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


class ReleasePreflightTests(unittest.TestCase):
    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        (self.root / "script").mkdir()
        shutil.copy2(Path(__file__).resolve().parents[1] / "release.sh", self.root / "script/release.sh")
        self.config = self.root / "project.yml"
        self.original = 'settings:\n  base:\n    MARKETING_VERSION: "1.1"\n    CURRENT_PROJECT_VERSION: "2"\n'
        self.config.write_text(self.original)
        notes = self.root / "docs/releases"
        notes.mkdir(parents=True)
        (notes / "1.1.md").write_text("# TrackPeek 1.1\nRelease notes.\n")
        (notes / "1.2.md").write_text("# TrackPeek 1.2\nRelease notes.\n")
        (self.root / "bin").mkdir()
        for command in ("xcodegen", "xcodebuild", "ditto"):
            stub = self.root / "bin" / command
            stub.write_text('#!/bin/sh\nprintf invoked >> "$RELEASE_TEST_ROOT/invoked"\nexit 99\n')
            stub.chmod(0o755)

    def run_script(self, *arguments):
        env = dict(os.environ, PATH=f"{self.root / 'bin'}:{os.environ['PATH']}", RELEASE_TEST_ROOT=str(self.root))
        return subprocess.run(["bash", str(self.root / "script/release.sh"), *arguments], env=env, capture_output=True, text=True)

    def assert_rejected_without_changes(self, expected_message, *arguments):
        result = self.run_script(*arguments)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(expected_message, result.stderr)
        self.assertFalse((self.root / "invoked").exists(), result.stdout + result.stderr)
        self.assertEqual(self.config.read_text(), self.original)
        self.assertFalse((self.root / ".build").exists())

    def test_invalid_version_never_reaches_build_or_changes_configuration(self):
        for version in ("../outside", "1.1-beta", "1.1/2", "1.1;echo broken", "v1.1"):
            with self.subTest(version=version):
                self.assert_rejected_without_changes("Version must contain", version, "2")

    def test_invalid_build_number_is_rejected(self):
        for build in ("0", "-1", "2.1", "02", "abc"):
            with self.subTest(build=build):
                self.assert_rejected_without_changes("Build number must be", "1.1", build)

    def test_version_must_match_checked_in_configuration(self):
        self.assert_rejected_without_changes("Set project.yml to version 1.2 and build 2", "1.2", "2")

    def test_build_must_match_checked_in_configuration(self):
        self.assert_rejected_without_changes("Set project.yml to version 1.1 and build 3", "1.1", "3")

    def test_build_number_is_required(self):
        self.assert_rejected_without_changes("Usage:", "1.1")

    def test_extra_arguments_are_rejected(self):
        self.assert_rejected_without_changes("Usage:", "1.1", "2", "unexpected")

    def test_valid_release_prepares_build_specific_artifacts_without_changing_configuration(self):
        def stub(path, body):
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(body)
            path.chmod(0o755)

        for command in ("xcodegen", "xcodebuild", "xcrun", "codesign", "lipo"):
            stub(self.root / "bin" / command, '#!/bin/sh\nprintf invoked >> "$RELEASE_TEST_ROOT/invoked"\n')
        stub(self.root / "bin/ditto", '#!/bin/sh\nfor destination do :; done\nprintf "fixture archive" > "$destination"\n')
        stub(self.root / "bin/PlistBuddy", '''#!/bin/sh
case "$2" in
  'Print :CFBundleShortVersionString') printf 1.1 ;;
  'Print :CFBundleVersion') printf 2 ;;
  'Print :SUPublicEDKey') printf fixture-key ;;
  *) exit 1 ;;
esac
''')
        # Replace this fixed system-tool path only in the isolated script copy.
        # Every build, signing and packaging tool is a fake; no app is built.
        script = self.root / "script/release.sh"
        script.write_text(script.read_text().replace("/usr/libexec/PlistBuddy", "PlistBuddy"))
        sparkle = self.root / ".build/xcode-release/SourcePackages/artifacts/sparkle/Sparkle/bin"
        stub(sparkle / "generate_keys", "#!/bin/sh\nprintf fixture-key\n")
        stub(sparkle / "generate_appcast", '''#!/usr/bin/python3
from pathlib import Path
import sys
from xml.sax.saxutils import escape

directory = Path(sys.argv[-1])
archive = next(directory.glob("*.zip"))
notes = archive.with_suffix(".txt").read_text()
prefix = sys.argv[sys.argv.index("--download-url-prefix") + 1]
xml = ('<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item>'
       '<sparkle:version>2</sparkle:version><sparkle:shortVersionString>1.1</sparkle:shortVersionString>'
       '<description>' + escape(notes) + '</description>'
       '<enclosure url="' + escape(prefix + archive.name) + '" length="' + str(archive.stat().st_size) + '" '
       'sparkle:edSignature="fixture-signature" /></item></channel></rss>')
(directory / "appcast.xml").write_text(xml)
''')
        stub(self.root / ".build/verify-update", "#!/bin/sh\nexit 0\n")

        result = self.run_script("1.1", "2")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue((self.root / "invoked").exists())
        self.assertEqual(self.config.read_text(), self.original)
        release = self.root / ".build/release/1.1"
        archive_name = "TrackPeek-1.1-build2.zip"
        self.assertTrue((release / archive_name).is_file())
        self.assertEqual((release / archive_name).read_bytes(), b"fixture archive")
        self.assertEqual((release / "TrackPeek-1.1-build2.txt").read_text(), "TrackPeek 1.1\nRelease notes.\n")
        self.assertIn(f"/releases/download/v1.1/{archive_name}", (release / "appcast.xml").read_text())
        self.assertIn(f"  {archive_name}\n", (release / "SHA256SUMS").read_text())
        self.assertIn(archive_name, result.stdout)
        self.assertFalse((release / "TrackPeek-1.1.zip").exists())

    def test_help_does_not_build(self):
        result = self.run_script("--help")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse((self.root / "invoked").exists())
        self.assertEqual(self.config.read_text(), self.original)

    def test_existing_release_is_never_overwritten(self):
        directory = self.root / ".build/release/1.1"
        directory.mkdir(parents=True)
        archive = directory / "TrackPeek-1.1.zip"
        archive.write_bytes(b"previous release")
        result = self.run_script("1.1", "2")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Release directory already exists", result.stderr)
        self.assertFalse((self.root / "invoked").exists())
        self.assertEqual(archive.read_bytes(), b"previous release")
        self.assertEqual(self.config.read_text(), self.original)


if __name__ == "__main__":
    unittest.main()
