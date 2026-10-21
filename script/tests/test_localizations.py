import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest


def translated(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def catalog(key="Open %@", values=None):
    return {
        "sourceLanguage": "en",
        "version": "1.0",
        "strings": {
            key: {
                "localizations": values or {
                    "en": translated("Open %@"),
                    "uk": translated("Відкрити %@"),
                    "ru": translated("Открыть %@"),
                }
            }
        },
    }


def plural(values):
    return {"variations": {"plural": {form: translated(value) for form, value in values.items()}}}


class LocalizationValidationTests(unittest.TestCase):
    """Exercise the same CLI used by CI against isolated, real catalog files."""

    def setUp(self):
        self.workspace = tempfile.TemporaryDirectory()
        self.addCleanup(self.workspace.cleanup)
        self.root = Path(self.workspace.name)
        script_directory = self.root / "script"
        script_directory.mkdir()
        self.script = script_directory / "validate_localizations.py"
        shutil.copy2(Path(__file__).resolve().parents[1] / self.script.name, self.script)
        self.resources = self.root / "Sources/Resources"
        self.resources.mkdir(parents=True)
        self.write_catalog(catalog())
        self.write_catalog(catalog("NSAppleEventsUsageDescription", {
            "en": translated("TrackPeek controls your music."),
            "uk": translated("TrackPeek керує вашою музикою."),
            "ru": translated("TrackPeek управляет вашей музыкой."),
        }), "InfoPlist")

    def write_catalog(self, data, name="Localizable"):
        path = self.resources / f"{name}.xcstrings"
        path.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        return path

    def run_validator(self):
        return subprocess.run([sys.executable, str(self.script)], capture_output=True, text=True)

    def assert_rejected(self, message):
        result = self.run_validator()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn(message, result.stderr)
        self.assertNotIn("Traceback", result.stderr)
        return result

    def test_complete_catalogs_succeed_and_report_both_files(self):
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Localizable.xcstrings: 1 entries complete in en, uk and ru", result.stdout)
        self.assertIn("InfoPlist.xcstrings: 1 entries complete in en, uk and ru", result.stdout)
        self.assertEqual(result.stderr, "")

    def test_english_remains_the_development_language(self):
        data = catalog()
        data["sourceLanguage"] = "uk"
        self.write_catalog(data)
        self.assert_rejected("Localizable.xcstrings: the development language must be English")

    def test_missing_catalog_fails_without_suppressing_other_catalog_result(self):
        (self.resources / "Localizable.xcstrings").unlink()
        result = self.assert_rejected("Localizable.xcstrings: missing catalog")
        self.assertIn("InfoPlist.xcstrings: 1 entries complete", result.stdout)

    def test_invalid_json_has_a_catalog_scoped_error_without_a_traceback(self):
        (self.resources / "Localizable.xcstrings").write_text('{"strings":', encoding="utf-8")
        self.assert_rejected("Localizable.xcstrings: invalid JSON")

    def test_invalid_utf8_has_a_catalog_scoped_error_without_a_traceback(self):
        (self.resources / "Localizable.xcstrings").write_bytes(b"\xff\xfe")
        self.assert_rejected("Localizable.xcstrings: cannot read catalog")

    def test_invalid_catalog_shapes_are_rejected_without_a_traceback(self):
        cases = [
            ([], "catalog must be a JSON object"),
            ({"sourceLanguage": "en", "strings": []}, "strings must be a JSON object"),
            ({"sourceLanguage": "en", "strings": {"Open %@": []}}, "invalid entry"),
            ({"sourceLanguage": "en", "strings": {"Open %@": {"localizations": []}}}, "invalid localizations"),
        ]
        for data, message in cases:
            with self.subTest(data=data):
                self.write_catalog(data)
                self.assert_rejected(message)

    def test_empty_catalog_is_rejected(self):
        self.write_catalog({"sourceLanguage": "en", "strings": {}})
        self.assert_rejected("the catalog is empty")

    def test_missing_incomplete_empty_or_nonstring_translations_are_rejected(self):
        for invalid in (None, {}, {"stringUnit": {"state": "new", "value": "Відкрити %@"}},
                        translated(""), translated(42), translated(True), []):
            with self.subTest(localization=invalid):
                data = catalog()
                localizations = data["strings"]["Open %@"]["localizations"]
                if invalid is None:
                    del localizations["uk"]
                else:
                    localizations["uk"] = invalid
                self.write_catalog(data)
                self.assert_rejected("missing completed uk translation")

    def test_complete_language_specific_plural_forms_succeed(self):
        self.write_catalog(self.plural_catalog())
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stderr)

    def plural_catalog(self):
        return catalog("%lld item", {
            "en": plural({"one": "%lld item", "other": "%lld items"}),
            "uk": plural({"one": "%lld елемент", "few": "%lld елементи", "many": "%lld елементів", "other": "%lld елемента"}),
            "ru": plural({"one": "%lld элемент", "few": "%lld элемента", "many": "%lld элементов", "other": "%lld элемента"}),
        })

    def test_each_language_requires_its_plural_forms(self):
        for language, form in (("en", "other"), ("uk", "few"), ("ru", "many")):
            with self.subTest(language=language, form=form):
                data = self.plural_catalog()
                del data["strings"]["%lld item"]["localizations"][language]["variations"]["plural"][form]
                self.write_catalog(data)
                self.assert_rejected(f"{language} is missing plural forms")

    def test_malformed_plural_containers_are_rejected_without_a_traceback(self):
        for variations in (None, [], {"plural": []}, {"plural": {"one": None}}):
            with self.subTest(variations=variations):
                data = self.plural_catalog()
                data["strings"]["%lld item"]["localizations"]["uk"]["variations"] = variations
                self.write_catalog(data)
                self.assert_rejected("uk")

    def test_every_plural_branch_preserves_format_arguments_including_english(self):
        for language, form in (("en", "other"), ("uk", "few"), ("ru", "many")):
            with self.subTest(language=language, form=form):
                data = self.plural_catalog()
                data["strings"]["%lld item"]["localizations"][language]["variations"]["plural"][form] = translated("Items")
                self.write_catalog(data)
                self.assert_rejected(f"{language} changes formatting arguments")

    def test_missing_substitutions_and_changed_argument_types_are_rejected(self):
        for value in ("Відкрити", "Відкрити %lld", "Відкрити %@ %@"):
            with self.subTest(value=value):
                data = catalog()
                data["strings"]["Open %@"]["localizations"]["uk"] = translated(value)
                self.write_catalog(data)
                self.assert_rejected("uk changes formatting arguments")

    def test_escaped_percent_does_not_consume_a_substitution(self):
        self.write_catalog(catalog("%@ at %lld%%", {
            "en": translated("%@ at %lld%%"),
            "uk": translated("%@ — %lld%%"),
            "ru": translated("%1$@ — %2$lld%%"),
        }))
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_translations_can_reorder_explicitly_positioned_arguments(self):
        self.write_catalog(catalog("%@: %lld", {
            "en": translated("%@: %lld"),
            "uk": translated("%2$lld — %1$@"),
            "ru": translated("%2$lld: %1$@"),
        }))
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_repeated_positioned_arguments_cannot_be_silently_dropped(self):
        self.write_catalog(catalog("%1$@ / %1$@", {
            "en": translated("%1$@ / %1$@"),
            "uk": translated("%1$@"),
            "ru": translated("%1$@ / %1$@"),
        }))
        self.assert_rejected("uk changes formatting arguments")

    def test_dynamic_width_and_precision_arguments_cannot_be_dropped(self):
        self.write_catalog(catalog("%*.*f seconds", {
            "en": translated("%*.*f seconds"),
            "uk": translated("секунди"),
            "ru": translated("%*.*f секунды"),
        }))
        self.assert_rejected("uk changes formatting arguments")

    def test_dynamic_width_and_precision_can_be_explicitly_positioned(self):
        self.write_catalog(catalog("%*.*f seconds", {
            "en": translated("%*.*f seconds"),
            "uk": translated("%3$*1$.*2$f секунди"),
            "ru": translated("%3$*1$.*2$f секунды"),
        }))
        result = self.run_validator()
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
