import os
from pathlib import Path
import plistlib
import shutil
import subprocess
import tempfile
import unittest

try:
    from ds_store import DSStore
except ImportError:  # Provided by the optional dmgbuild environment.
    DSStore = None


SCRIPT = Path(__file__).resolve().parents[1] / "package_dmg.sh"


class DiskImageTests(unittest.TestCase):
    def setUp(self):
        workspace = tempfile.TemporaryDirectory()
        self.addCleanup(workspace.cleanup)
        self.root = Path(workspace.name)
        self.app = self.root / "Sample input.app"
        contents = self.app / "Contents"
        (contents / "MacOS").mkdir(parents=True)
        shutil.copy("/usr/bin/true", contents / "MacOS/TrackPeek")
        (contents / "Info.plist").write_bytes(plistlib.dumps({
            "CFBundleExecutable": "TrackPeek",
            "CFBundleIdentifier": "com.trackpeek.TrackPeek",
            "CFBundlePackageType": "APPL",
        }))

    def test_existing_image_and_source_bundle_are_preserved(self):
        existing = self.root / "existing.dmg"
        existing.write_bytes(b"previous image")
        for output, error in ((existing, b"new output filename"),
                              (self.app / "nested.dmg", b"outside the app bundle")):
            with self.subTest(output=output):
                result = subprocess.run([SCRIPT, self.app, output], capture_output=True)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn(error, result.stderr)
        self.assertEqual(existing.read_bytes(), b"previous image")
        self.assertFalse((self.app / "nested.dmg").exists())

    def test_output_in_differently_cased_bundle_is_rejected(self):
        alias = self.root / self.app.name.swapcase()
        if not alias.exists():
            self.skipTest("requires a case-insensitive filesystem")
        output = alias / "Contents" / "preview.dmg"
        result = subprocess.run([SCRIPT, self.app, output], capture_output=True, text=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("outside the app bundle", result.stderr)
        self.assertFalse(output.exists())

    @unittest.skipUnless(DSStore and shutil.which("dmgbuild"), "requires the optional dmgbuild environment")
    def test_mounted_image_keeps_signature_link_and_finder_layout(self):
        subprocess.run(["codesign", "-s", "-", "--force", self.app], check=True, capture_output=True)
        output = self.root / "install preview.dmg"
        subprocess.run([SCRIPT, self.app, output, "uk"], check=True)
        mount = self.root / "mounted"
        mount.mkdir()
        subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-noautoopen",
                        "-mountpoint", mount, output], check=True)
        self.addCleanup(subprocess.run, ["hdiutil", "detach", mount], check=True)

        subprocess.run(["codesign", "--verify", "--deep", "--strict", mount / "TrackPeek.app"], check=True)
        self.assertEqual(os.readlink(mount / "Applications"), "/Applications")
        self.assertTrue((mount / ".background.tiff").is_file())
        with DSStore.open(str(mount / ".DS_Store"), "r") as store:
            self.assertEqual(store["."]["icvl"], (b"type", b"icnv"))
            self.assertEqual(store["."]["icvp"]["backgroundType"], 2)
            left, app_y = store["TrackPeek.app"]["Iloc"]
            right, folder_y = store["Applications"]["Iloc"]
            self.assertLess(left, right)
            self.assertEqual(app_y, folder_y)
