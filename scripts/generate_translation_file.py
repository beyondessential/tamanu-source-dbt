import re
from pathlib import Path

import pandas as pd
from utils.dbt_utils import get_dbt_project_vars, get_deployment_version
from utils.file_utils import ensure_directory_exists, read_file

BASE_DIR = Path(__file__).parent.parent
SQL_DIR = BASE_DIR / "models" / "reports" / "sql"
TRANSLATION_DIR = BASE_DIR / "compiled" / "translations"
TRANSLATION_PATTERN = (
    r"\{\{\s*translate_string\(['\"]([^'\"]+)['\"],\s*['\"]([^'\"]+)['\"]\)\s*\}\}"
)


def main():
    try:
        ensure_directory_exists(SQL_DIR)
        sql_files = list(SQL_DIR.rglob("*.sql"))
        print(f"Found {len(sql_files)} SQL files in {SQL_DIR}")

        translation_prefix = get_dbt_project_vars("translation_prefix")
        translations = []

        for sql_file in sql_files:
            try:
                content = read_file(str(sql_file))
                matches = re.findall(TRANSLATION_PATTERN, content)
                translations.extend(
                    (f"{translation_prefix}.{match[0]}", match[1]) for match in matches
                )
            except Exception as e:
                print(f"Error processing {sql_file}: {e}")

        if not translations:
            print("No translations found in any SQL files")
            return

        df = pd.DataFrame(
            list(dict.fromkeys(translations)),
            columns=["stringId", get_dbt_project_vars("language")],
        ).sort_values("stringId")

        ensure_directory_exists(TRANSLATION_DIR)
        output_file = (
            TRANSLATION_DIR / f"report_translations_v{get_deployment_version()}.csv"
        )
        df.to_csv(output_file, index=False)
        print(f"Translations saved to {output_file}")

    except Exception as e:
        print(f"Error: {e}")


if __name__ == "__main__":
    main()
