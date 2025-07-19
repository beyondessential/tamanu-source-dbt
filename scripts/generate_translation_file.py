import os
import re
from pathlib import Path

import pandas as pd
from utils.dbt_utils import get_dbt_project_vars, get_deployment_name, get_deployment_version, get_project_name
from utils.file_utils import ensure_directory_exists, read_file, upload_to_s3
from utils.system_utils import cprint

BASE_DIR = Path(os.getcwd())
PKG_BASE_DIR = BASE_DIR / "dbt_packages" / "tamanu_source_dbt"
BASE_SQL_DIR = BASE_DIR / "models" / "reports" / "sql"
PKG_BASE_SQL_DIR = PKG_BASE_DIR / "models" / "reports" / "sql"
PROJECT_NAME = get_project_name()
DEPLOYMENT = get_deployment_name()
VERSION = get_deployment_version()
VERSION_DIR = BASE_DIR / "compiled" / f"v{VERSION}"
TRANSLATION_PATTERN = (
    r"\{\{\s*translate_label\(['\"]([^'\"]+)['\"],\s*['\"]([^'\"]+)['\"]\)\s*\}\}"
)


def main():
    try:
        # Collect SQL files from both BASE_SQL_DIR and PKG_BASE_SQL_DIR
        sql_files = []
        
        # Check PKG_BASE_SQL_DIR
        if PKG_BASE_SQL_DIR.exists():
            pkg_sql_files = list(PKG_BASE_SQL_DIR.rglob("*.sql"))
            sql_files.extend(pkg_sql_files)
            cprint(f"Found {len(pkg_sql_files)} SQL files in {PKG_BASE_SQL_DIR}", "info")
        else:
            cprint(f"PKG_BASE_SQL_DIR does not exist: {PKG_BASE_SQL_DIR}", "warning")
        
        # Check BASE_SQL_DIR
        if BASE_SQL_DIR.exists():
            base_sql_files = list(BASE_SQL_DIR.rglob("*.sql"))
            sql_files.extend(base_sql_files)
            cprint(f"Found {len(base_sql_files)} SQL files in {BASE_SQL_DIR}", "info")
        else:
            cprint(f"BASE_SQL_DIR does not exist: {BASE_SQL_DIR}", "warning")
        
        cprint(f"Total SQL files found: {len(sql_files)}", "info")

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
                cprint(f"Error processing {sql_file}: {e}", "error")

        if not translations:
            cprint("No translations found in any SQL files", "error")
            return

        df = pd.DataFrame(
            list(dict.fromkeys(translations)),
            columns=["stringId", get_dbt_project_vars("language")],
        ).sort_values("stringId")

        ensure_directory_exists(str(VERSION_DIR))
        
        output_filename = f"report-translations-v{VERSION}-{DEPLOYMENT}.csv"
        output_file = VERSION_DIR / output_filename

        df.to_csv(output_file, index=False)
        cprint(f"Translations saved to {output_file}", "success")

        if os.getenv("GITHUB_ACTIONS"):
            bucket = os.getenv("BUCKET", "").replace("s3://", "")
            if not bucket:
                raise ValueError("BUCKET environment variable is not set")
            key = f"{VERSION}/{output_filename}"
            upload_to_s3(output_file, bucket, key)

    except Exception as e:
        cprint(f"Error: {e}", "error")


if __name__ == "__main__":
    main()
