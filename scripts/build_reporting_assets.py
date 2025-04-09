import sys

from utils import (
    execute_command,
    generate_import_report_script,
    generate_project_reports,
    generate_reporting_schema_script,
    hide_macros_from_docs,
    hide_tests_from_docs,
)


def main():
    args = sys.argv[1:]
    target_index = args.index("--target") + 1 if "--target" in args else -1
    target = args[target_index] if target_index > 0 else "demoland"

    print(f"Generating build script for target: {target}")

    # Execute DBT commands
    execute_command("dbt clean")
    execute_command("dbt deps")
    execute_command(f"dbt run --target {target} --select tag:{target}")
    execute_command(f"dbt docs generate --target {target} --select tag:{target}")
    execute_command(f"dbt compile --target {target} --select tag:{target}")

    # Hide macros and tests from documentation
    hide_macros_from_docs()
    hide_tests_from_docs()

    # Generate scripts and reports
    generate_reporting_schema_script(target)
    generate_project_reports(target)
    generate_import_report_script()


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        print(f"Error: {err}")
        sys.exit(1)
