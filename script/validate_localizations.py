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
    r"%%|%(?:(?P<position>\d+)\$)?[-+# 0]*"
    r"(?P<width>\d+|\*(?:\d+\$)?)?"
    r"(?:\.(?P<precision>\d*|\*(?:\d+\$)?))?"
    r"(?P<length>hh|ll|h|l|q|z|t|j)?(?P<type>[@diuoxXfFeEgGaAcCsSp])"
)


def arguments(value):
    result = Counter()
    next_position = 1
    for match in FORMAT.finditer(value):
        if match[0] == "%%":
            continue
        # A star consumes an integer argument before the formatted value.
        # Positional stars allow translators to reorder the same arguments.
        for field in ("width", "precision"):
            amount = match[field] or ""
            if amount.startswith("*"):
                position = int(amount[1:-1]) if amount.endswith("$") else next_position
                result[(position, "d")] += 1
                if not amount.endswith("$"):
                    next_position += 1
        position = int(match["position"]) if match["position"] else next_position
        result[(position, (match["length"] or "") + match["type"])] += 1
        if not match["position"]:
            next_position += 1
    return result


def validate(path):
    try:
        catalog = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return 0, [f"invalid JSON at line {error.lineno}, column {error.colno}: {error.msg}"]
    except (OSError, UnicodeError) as error:
        return 0, [f"cannot read catalog: {error}"]
    if not isinstance(catalog, dict):
        return 0, ["catalog must be a JSON object"]
    problems = []
    if catalog.get("sourceLanguage") != "en":
        problems.append("the development language must be English")
    entries = catalog.get("strings", {})
    if not isinstance(entries, dict):
        return 0, problems + ["strings must be a JSON object"]
    if not entries:
        problems.append("the catalog is empty")
    for key, entry in entries.items():
        if not isinstance(entry, dict):
            problems.append(f"{key!r}: invalid entry, expected a JSON object")
            continue
        localizations = entry.get("localizations", {})
        if not isinstance(localizations, dict):
            problems.append(f"{key!r}: invalid localizations, expected a JSON object")
            continue
        values = {}
        for language in LANGUAGES:
            localization = localizations.get(language, {})
            if not isinstance(localization, dict):
                problems.append(f"{key!r}: missing completed {language} translation")
                continue
            if "variations" in localization:
                variations = localization["variations"]
                plurals = variations.get("plural", {}) if isinstance(variations, dict) else None
                if not isinstance(plurals, dict):
                    problems.append(f"{key!r}: invalid {language} plural forms, expected a JSON object")
                    continue
                units = [form.get("stringUnit", {}) if isinstance(form, dict) else None for form in plurals.values()]
                if not PLURAL_FORMS[language].issubset(plurals):
                    problems.append(f"{key!r}: {language} is missing plural forms")
            else:
                units = [localization.get("stringUnit", {})]
            if not units or any(
                not isinstance(unit, dict)
                or unit.get("state") != "translated"
                or not isinstance(unit.get("value"), str)
                or not unit["value"]
                for unit in units
            ):
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
