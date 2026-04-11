import re
from pathlib import Path

from utils.dbt_utils import get_deployment_name
from utils.file_utils import read_file
from utils.system_utils import cprint
from utils.translation_utils import assert_no_default_overrides, read_translations_csv

DEPLOYMENT = get_deployment_name()


def extract_translate_labels_from_file(file_path):
    content = read_file(file_path, file_type="text")
    pattern = r"translate_label\(['\"]([^'\"]+)['\"]\)"
    return re.findall(pattern, content)


def _short_ids(csv_dict):
    return {
        sid[len("report.reporting."):]
        for sid in csv_dict
        if sid.startswith("report.reporting.")
    }


def main():
    if DEPLOYMENT == "standard":
        csv_path = Path("report_translations_standard.csv")
        if not csv_path.exists():
            cprint(f"⚠️ File does not exist: {csv_path}", "warning")
        translations = _short_ids(read_translations_csv(csv_path))
        sql_folders = [Path("models/reports/sql")]
    else:
        standard_csv_path = Path(
            "dbt_packages/tamanu_source_dbt/report_translations_standard.csv"
        )
        deployment_csv_path = Path(f"report_translations_{DEPLOYMENT}.csv")

        standard = read_translations_csv(standard_csv_path)
        localised = read_translations_csv(deployment_csv_path)

        assert_no_default_overrides(localised, standard)

        translations_standard = _short_ids(standard)
        translations_deployment = _short_ids(localised)

        if not translations_deployment:
            cprint(
                f"\nℹ️ No deployment-specific translations file found for"
                f" {DEPLOYMENT}, using standard translations only.",
                "info",
            )

        translations = translations_standard | translations_deployment
        sql_folders = [
            Path("models/reports/sql"),
            Path("dbt_packages/tamanu_source_dbt/models/reports/sql"),
        ]

    referenced_translations = set()
    file_referencing_translations = {}

    for folder in sql_folders:
        for sql_file in folder.rglob("*.sql"):
            labels = extract_translate_labels_from_file(sql_file)
            file_referencing_translations[str(sql_file)] = labels
            referenced_translations.update(labels)

    cprint(f"Found {len(translations)} translations", "info")
    cprint(
        f"Found {len(referenced_translations)} unique translate_label calls"
        " across all SQL files",
        "info",
    )

    missing_translations = referenced_translations - translations
    if missing_translations:
        cprint(f"\n❌ MISSING TRANSLATIONS ({len(missing_translations)}):", "error")
        for missing_translation in sorted(missing_translations):
            files_referencing_missing_translation = [
                file
                for file, translation_labels in file_referencing_translations.items()
                if missing_translation in translation_labels
            ]
            cprint(
                f"  - {missing_translation} (used in:"
                f" {', '.join(files_referencing_missing_translation)})",
                "error",
            )

        cprint("\nTo fix, add the following to the translation file:", "warning")
        for missing_translation in sorted(missing_translations):
            cprint(f"report.reporting.{missing_translation}", "warning")
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
            label for label in translation_labels if label not in translations
        ]
        status = "❌" if missing_in_file else "✅"
        cprint(
            f"{status} {file}: {len(translation_labels)} calls,"
            f" {len(missing_in_file)} missing",
            "info",
        )
        if missing_in_file:
            cprint(f"Missing: {', '.join(missing_in_file)}", "error")


if __name__ == "__main__":
    main()
