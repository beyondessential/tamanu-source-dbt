import re
import sys
from datetime import datetime
from pathlib import Path

from utils.file_utils import ensure_directory_exists, write_file
from utils.report_utils import create_report_config, create_report_sql
from utils.system_utils import get_arg_value

BASE_DIR = Path(__file__).parent.parent
SQL_DIR = BASE_DIR / "models" / "reports" / "sql"
CONFIG_DIR = BASE_DIR / "models" / "reports" / "config"


def get_report_filename(name):
    """Convert a report name to a valid filename."""
    filename = name.lower().strip()
    filename = re.sub(r"[\s_]+", "-", filename)
    filename = re.sub(r"[^a-z0-9-]", "", filename)
    filename = re.sub(r"-+", "-", filename)
    return filename.strip("-")


def main():
    args = sys.argv[1:]
    project = get_arg_value(args, "--project", "-p", "generic")
    report_name = get_arg_value(
        args, "--name", "-n", f"report-{datetime.now().strftime('%Y%m%d_%H%M%S')}"
    )

    print(f"\nGenerating files for '{report_name}' in '{project}'")

    ensure_directory_exists(str(CONFIG_DIR))
    ensure_directory_exists(str(SQL_DIR))

    report = get_report_filename(report_name)
    config_file = CONFIG_DIR / project / f"{report}.json"
    sql_file = SQL_DIR / project / f"{report}.sql"

    if config_file.exists() or sql_file.exists():
        print(f"One or more files already exists.")
        return

    config_content = create_report_config(report_name)
    sql_content = create_report_sql()

    write_file(str(config_file), config_content, file_type="json")
    write_file(str(sql_file), sql_content, file_type="text")

    print(f"\nSuccessfully created config and sql files for '{report_name}'!")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"Error creating files: {e}")
        sys.exit(1)
