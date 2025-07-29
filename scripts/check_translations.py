import re
from pathlib import Path

from utils.file_utils import read_file
from utils.system_utils import cprint

REPORTS_SQL_FOLDER = Path("models/reports/sql")
TRANSLATION_FILE = Path("report_translations.xlsx")


def extract_translate_labels_from_file(file_path):
    content = read_file(file_path, file_type="text")
    pattern = r"translate_label\(['\"]([^'\"]+)['\"]\)"
    return re.findall(pattern, content)


def load_translations_from_file(file_path):
    df = read_file(file_path, file_type="excel")
    return {
        sid[len("report.reporting.") :]
        for sid in df["stringId"]
        if sid.startswith("report.reporting.")
    }


def main():
    translations = load_translations_from_file(TRANSLATION_FILE)
    cprint(f"Found {len(translations)} translations in {TRANSLATION_FILE}", "info")

    referenced_translations = set()
    file_referencing_translations = {}

    for sql_file in REPORTS_SQL_FOLDER.glob("*.sql"):
        labels = extract_translate_labels_from_file(sql_file)
        file_referencing_translations[sql_file.name] = labels
        referenced_translations.update(labels)

    cprint(
        f"Found {len(referenced_translations)} unique translate_label calls across all SQL files",
        "info",
    )

    missing_translations = referenced_translations - translations
    if missing_translations:
        cprint(
            f"\n❌ MISSING TRANSLATIONS ({len(missing_translations)}):\nThe following translate_label calls do NOT have corresponding entries in the translation file:",
            "error",
        )
        for missing_translation in sorted(missing_translations):
            files_referencing_missing_translation = [
                file
                for file, translation_labels in file_referencing_translations.items()
                if missing_translation in translation_labels
            ]
            cprint(
                f"  - {missing_translation} (used in: {', '.join(files_referencing_missing_translation)})",
                "error",
            )

        cprint(f"\nTo fix, add the following to {TRANSLATION_FILE}:", "warning")
        for missing_translation in sorted(missing_translations):
            cprint(f"report.reporting.{missing_translation},<translation>", "warning")
    else:
        cprint("\n✅ ALL TRANSLATIONS FOUND!", "success")

    unused_translations = translations - referenced_translations
    if unused_translations:
        cprint(f"\n⚠️ UNUSED TRANSLATIONS ({len(unused_translations)}):", "warning")
        for unused_translation in sorted(unused_translations):
            cprint(f"  - {unused_translation}", "warning")

    cprint("\n📊 SUMMARY BY FILE:", "info")
    for file, translation_labels in sorted(file_referencing_translations.items()):
        missing_in_file = [
            translation_label
            for translation_label in translation_labels
            if translation_label not in translations
        ]
        status = "❌" if missing_in_file else "✅"
        cprint(
            f"{status} {file}: {len(translation_labels)} calls, {len(missing_in_file)} missing",
            "info",
        )
        if missing_in_file:
            cprint(f"Missing: {', '.join(missing_in_file)}", "error")


if __name__ == "__main__":
    main()
