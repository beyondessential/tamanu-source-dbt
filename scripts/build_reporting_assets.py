import sys
import os

from utils import (
    cprint,
    ensure_directory_exists,
    execute_command,
    generate_analytics_metadata,
    generate_reporting_schema_script,
    generate_project_reports,
    get_dbt_project_config,
    get_deployment_name,
    get_deployment_version,
    hide_macros_from_docs,
    hide_tests_from_docs,
    move_file
)

BASE_DIR = os.getcwd()
DEPLOYMENT = get_deployment_name()
VERSION = get_deployment_version()
VERSION_DIR = os.path.join(BASE_DIR, "compiled", f"v{VERSION}")


def main():
    """Build Tamanu reporting assets for all supported languages"""
    # Get supported languages from configuration
    config = get_dbt_project_config()
    supported_languages = config.get("vars", {}).get("supported_languages", ["default"])

    cprint(
        f"Building for all supported languages: {', '.join(supported_languages)}",
        "info",
    )

    # Ensure version directory exists
    ensure_directory_exists(VERSION_DIR)

    try:
        # Clean and prepare dbt environment
        cprint("Preparing dbt environment", "info")
        execute_command("dbt clean")
        execute_command("dbt deps")
        
        # Build dbt models and generate documentation
        cprint("Building dbt models and documentation", "info")
        execute_command("dbt run --profiles-dir config")
        execute_command("dbt docs generate --profiles-dir config --static")

        # Customise documentation by hiding macros and tests
        hide_macros_from_docs()
        hide_tests_from_docs()
        
        # Generate language-agnostic reporting assets
        cprint("Generating reporting assets", "info")
        generate_reporting_schema_script()
        generate_analytics_metadata()
        
        # Move documentation to versioned directory
        source_file = os.path.join(BASE_DIR, "target", "static_index.html")
        target_file = os.path.join(VERSION_DIR, f"reporting-docs-v{VERSION}-{DEPLOYMENT}.html")
        move_file(source_file, target_file)

        # Generate language-specific reports for each supported language
        cprint("Generating language-specific reports", "info")
        for language in supported_languages:
            cprint(f"Generating reports for language: {language}", "info")
            
            # Compile dbt models with the language variable passed via --vars
            execute_command(f'dbt compile --profiles-dir config --vars "{{language: {language}}}"')
            
            # Generate language-specific reports
            generate_project_reports(language)
            
            cprint(f"Completed report generation for language: {language}", "success")

        cprint(
            f"Multi-language build completed for {len(supported_languages)} languages!",
            "success",
        )

    except Exception as e:
        cprint(f"Error during build: {e}", "error")
        raise


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)
