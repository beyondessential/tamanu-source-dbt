import sys
import os
import csv
import json

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
    move_file,
)

BASE_DIR = os.getcwd()
DEPLOYMENT = get_deployment_name()
VERSION = get_deployment_version()
VERSION_DIR = os.path.join(BASE_DIR, "compiled", f"v{VERSION}")


def load_translations():
    def read_csv(rel_path):
        path = os.path.join(BASE_DIR, rel_path)
        if not os.path.exists(path):
            return {}
        mapping = {}
        with open(path, newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                string_id = row.get("stringId")
                text = row.get("default")
                if string_id and text is not None:
                    mapping[string_id] = text
        return mapping

    standard = read_csv("report_translations_standard.csv")
    if not standard:
        standard = read_csv(
            os.path.join(
                "dbt_packages", "tamanu_source_dbt", "report_translations_standard.csv"
            )
        )

    localised = read_csv("report_translations_localised.csv")
    merged = {}
    merged.update(standard)
    merged.update(localised)
    return merged


def main():
    """Build Tamanu reporting assets for all supported languages"""
    config = get_dbt_project_config()
    supported_languages = config.get("vars", {}).get("supported_languages", ["default"])
    translations = load_translations()

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

        vars_for_run = json.dumps({"report_translations": translations})

        cprint("Building dbt models and documentation", "info")
        execute_command(f"dbt run --profiles-dir config --vars '{vars_for_run}'")
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

            vars_for_compile = json.dumps(
                {"language": language, "report_translations": translations}
            )

            execute_command(
                f"dbt compile --profiles-dir config --vars '{vars_for_compile}'"
            )

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
