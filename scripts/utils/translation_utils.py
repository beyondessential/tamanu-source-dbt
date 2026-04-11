import csv
import os
import sys

from .system_utils import cprint


def read_translations_csv(path):
    """Read a translations CSV into {stringId: {lang: text}} with Jinja quote escaping.

    Uses csv.DictReader so empty cells are empty strings, not NaN.
    """
    if not os.path.exists(path):
        return {}
    mapping = {}
    with open(path, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            string_id = row.get("stringId")
            if not string_id:
                continue
            if string_id not in mapping:
                mapping[string_id] = {}
            for lang, text in row.items():
                if lang != "stringId" and text:
                    text_escaped = text.replace("\\", "\\\\").replace("'", "\\'")
                    mapping[string_id][lang] = text_escaped
    return mapping


def find_default_overrides_for_standard(localised, standard):
    """Return stringIds from localised that define 'default' but already exist in
    standard.

    Both arguments are dicts in the form {stringId: {lang: text}} as returned by
    read_translations_csv.
    """
    return [
        string_id
        for string_id, lang_dict in localised.items()
        if string_id in standard and "default" in lang_dict
    ]


def assert_no_default_overrides(localised, standard):
    """Print an error and exit(1) if localised defines 'default' for any standard
    stringId."""
    errors = find_default_overrides_for_standard(localised, standard)
    if errors:
        cprint(
            f"\n❌ ERROR: 'default' translations defined for standard stringIds"
            f" ({len(errors)}):",
            "error",
        )
        cprint(
            "Project CSVs should only add language-specific translations (e.g. 'en')"
            " for standard stringIds.",
            "error",
        )
        for sid in sorted(errors):
            cprint(f"  - {sid}", "error")
        sys.exit(1)
