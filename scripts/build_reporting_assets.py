import sys

from utils import (
    execute_command,
    generate_import_report_script,
    generate_project_reports,
    generate_reporting_schema_script,
    hide_macros_from_docs,
    hide_tests_from_docs,
)
from utils.system_utils import cprint


def main():
    cprint(f"Generating build script", "info")

    # Execute DBT commands
    execute_command("dbt clean")
    execute_command("dbt deps")
    execute_command(
        f"dbt run --profiles-dir config"
    )
    execute_command(
        f"dbt docs generate --profiles-dir config"
    )
    execute_command(
        f"dbt compile --profiles-dir config"
    )
# 
    # # Hide macros and tests from documentation
    hide_macros_from_docs()
    hide_tests_from_docs()

    # Generate scripts and reports
    generate_reporting_schema_script()
    generate_project_reports()
    generate_import_report_script()


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)
