import sys
import os
import shutil

from utils import (
    execute_command,
    generate_multilingual_reports,
    generate_project_reports,
    generate_reporting_schema_script,
    hide_macros_from_docs,
    hide_tests_from_docs,
)
from utils.analytics_utils import generate_analytics_metadata
from utils.dbt_utils import get_deployment_name, get_deployment_version
from utils.file_utils import ensure_directory_exists
from utils.system_utils import cprint

BASE_DIR = os.getcwd()
DEPLOYMENT = get_deployment_name()
VERSION = get_deployment_version()
VERSION_DIR = os.path.join(BASE_DIR, "compiled", f"v{VERSION}")


def move_dbt_docs():
    """Move dbt docs to the compiled directory with proper naming."""
    ensure_directory_exists(VERSION_DIR)

    source_file = os.path.join(BASE_DIR, "target", "static_index.html")
    target_file = os.path.join(
        VERSION_DIR, f"reporting-docs-v{VERSION}-{DEPLOYMENT}.html"
    )

    if os.path.exists(source_file):
        shutil.move(source_file, target_file)
        cprint(
            f"Moved dbt docs: reporting-docs-v{VERSION}-{DEPLOYMENT}.html", "success"
        )
    else:
        cprint(f"Warning: static_index.html not found at {source_file}", "warning")


def main():
    cprint(f"Generating build script", "info")

    # Execute DBT commands
    execute_command("dbt clean")
    execute_command("dbt deps")
    execute_command(f"dbt run --profiles-dir config")
    execute_command(f"dbt docs generate --profiles-dir config --static")
    execute_command(f"dbt compile --profiles-dir config")

    # Hide macros and tests from documentation
    hide_macros_from_docs()
    hide_tests_from_docs()
    
    # Generate scripts and reports
    generate_reporting_schema_script()
    generate_project_reports()
    
    # Generate multilingual reports directly from compiled base reports
    generate_multilingual_reports()
    
    # Generate analytics metadata
    generate_analytics_metadata()
    move_dbt_docs()


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)
