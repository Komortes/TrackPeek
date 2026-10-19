#!/usr/bin/env python3
"""Check complete app translations and preserve printf argument contracts."""

from collections import Counter
import json
from pathlib import Path
import re
import sys


LANGUAGES = ("en", "uk", "ru")
PLURAL_FORMS = {
    "en": {"one", "other"},
    "uk": {"one", "few", "many", "other"},
    "ru": {"one", "few", "many", "other"},
}
ROOT = Path(__file__).resolve().parents[1]
FORMAT = re.compile(
    r"%%|%(?:(\d+)\$)?[-+# 0]*(?:\d+)?(?:\.\d+)?"
    r"(hh|ll|h|l|q|z|t|j)?([@diuoxXfFeEgGaAcCsSp])"
)


def arguments(value):
    result = Counter()
    next_position = 1
    for match in FORMAT.finditer(value):
        if match[0] == "%%":
            continue
        position = int(match[1]) if match[1] else next_position
        result[(position, (match[2] or "") + match[3])] += 1
        if not match[1]:
            next_position += 1
    return result


def validate(path):
    catalog = json.loads(path.read_text())
    problems = []
    if catalog.get("sourceLanguage") != "en":
        problems.append("the development language must be English")
    entries = catalog.get("strings", {})
    if not entries:
        problems.append("the catalog is empty")
    for key, entry in entries.items():
        values = {}
        for language in LANGUAGES:
            localization = entry.get("localizations", {}).get(language, {})
            if "variations" in localization:
                plurals = localization["variations"].get("plural", {})
                units = [form.get("stringUnit", {}) for form in plurals.values()]
                if not PLURAL_FORMS[language].issubset(plurals):
                    problems.append(f"{key!r}: {language} is missing plural forms")
            else:
                units = [localization.get("stringUnit", {})]
            if not units or any(unit.get("state") != "translated" or not unit.get("value") for unit in units):
                problems.append(f"{key!r}: missing completed {language} translation")
            else:
                values[language] = [unit["value"] for unit in units]
        if "en" in values:
            for language, translations in values.items():
                if any(arguments(value) != arguments(values["en"][0]) for value in translations):
                    problems.append(f"{key!r}: {language} changes formatting arguments")
    return len(entries), problems


def main():
    failures = []
    for name in ("Localizable", "InfoPlist"):
        path = ROOT / "Sources" / "Resources" / f"{name}.xcstrings"
        if not path.is_file():
            failures.append(f"{path}: missing catalog")
            continue
        count, problems = validate(path)
        failures.extend(f"{path.name}: {problem}" for problem in problems)
        if not problems:
            print(f"{path.name}: {count} entries complete in en, uk and ru")
    if failures:
        print("\n".join(failures), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
