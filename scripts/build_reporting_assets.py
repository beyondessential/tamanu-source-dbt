import sys
import os
import shutil
import argparse
import yaml

from utils import (
    execute_command,
    generate_import_report_script,
    generate_project_reports,
    generate_reporting_schema_script,
    hide_macros_from_docs,
    hide_tests_from_docs,
)
from utils.analytics_utils import generate_analytics_metadata
from utils.dbt_utils import (
    get_deployment_name,
    get_deployment_version,
    get_dbt_project_config,
)
from utils.file_utils import ensure_directory_exists
from utils.system_utils import cprint

BASE_DIR = os.getcwd()
DEPLOYMENT = get_deployment_name()
VERSION = get_deployment_version()
VERSION_DIR = os.path.join(BASE_DIR, "compiled", f"v{VERSION}")


def get_supported_languages():
    """Get the list of supported languages from dbt_project.yml"""
    config = get_dbt_project_config()
    return config.get("vars", {}).get("supported_languages", ["default"])


def update_dbt_project_language(language):
    """Update the language variable in dbt_project.yml"""
    config_path = os.path.join(BASE_DIR, "dbt_project.yml")

    with open(config_path, "r") as f:
        config = yaml.safe_load(f)

    config["vars"]["language"] = language

    with open(config_path, "w") as f:
        yaml.dump(config, f, default_flow_style=False, sort_keys=False)

    cprint(f"Updated dbt_project.yml language to: {language}", "info")


def move_dbt_docs(language=None):
    """Move dbt docs to the compiled directory with proper naming."""
    ensure_directory_exists(VERSION_DIR)

    source_file = os.path.join(BASE_DIR, "target", "static_index.html")

    if language and language != "default":
        target_file = os.path.join(
            VERSION_DIR, f"reporting-docs-v{VERSION}-{DEPLOYMENT}-{language}.html"
        )
    else:
        target_file = os.path.join(
            VERSION_DIR, f"reporting-docs-v{VERSION}-{DEPLOYMENT}.html"
        )

    if os.path.exists(source_file):
        shutil.move(source_file, target_file)
        cprint(f"Moved dbt docs: {os.path.basename(target_file)}", "success")
    else:
        cprint(f"Warning: static_index.html not found at {source_file}", "warning")


def generate_reporting_schema_script_for_language(language=None):
    """Generate reporting schema script with optional language suffix"""
    try:
        # Call the existing function
        generate_reporting_schema_script()

        # If language is specified and not default, rename the file
        if language and language != "default":
            original_file = os.path.join(
                VERSION_DIR, f"reporting-schema-v{VERSION}-{DEPLOYMENT}.sql"
            )
            language_file = os.path.join(
                VERSION_DIR, f"reporting-schema-v{VERSION}-{DEPLOYMENT}-{language}.sql"
            )

            if os.path.exists(original_file):
                shutil.move(original_file, language_file)
                cprint(
                    f"Generated reporting schema for language: {language}", "success"
                )

    except Exception as e:
        cprint(
            f"Error generating reporting schema for {language or 'default'}: {e}",
            "warning",
        )


def generate_reports_for_language(language):
    """Generate language-specific reports only"""
    cprint(f"Generating reports for language: {language}", "info")
    
    # Update the language in dbt_project.yml
    update_dbt_project_language(language)
    
    # Generate language-specific reports
    generate_project_reports()
    
    cprint(f"Completed report generation for language: {language}", "success")


def build_dbt_assets():
    """Build all dbt assets (run once, language-agnostic)"""
    cprint(f"Building dbt assets", "info")
    
    # Execute DBT commands once
    execute_command("dbt clean")
    execute_command("dbt deps")
    execute_command(f"dbt run --profiles-dir config")
    execute_command(f"dbt docs generate --profiles-dir config --static")
    execute_command(f"dbt compile --profiles-dir config")

    # Hide macros and tests from documentation
    hide_macros_from_docs()
    hide_tests_from_docs()
    
    cprint(f"Completed dbt asset build", "success")




def restore_original_language():
    """Restore the original language setting to first supported language"""
    supported_languages = get_supported_languages()
    first_language = supported_languages[0] if supported_languages else "default"
    update_dbt_project_language(first_language)


def main():
    parser = argparse.ArgumentParser(description="Build Tamanu reporting assets")
    parser.add_argument(
        "--language",
        type=str,
        help="Build for specific language (e.g., 'en', 'fr', 'es', 'to'). Use 'all' to build for all supported languages.",
    )
    parser.add_argument(
        "--list-languages",
        action="store_true",
        help="List all supported languages and exit",
    )

    args = parser.parse_args()

    # Handle list languages option
    if args.list_languages:
        supported_languages = get_supported_languages()
        cprint(f"Supported languages: {', '.join(supported_languages)}", "info")
        return

    # Ensure version directory exists
    ensure_directory_exists(VERSION_DIR)

    try:
        if args.language:
            if args.language.lower() == "all":
                # Optimized build for all supported languages
                supported_languages = get_supported_languages()
                cprint(
                    f"Building for all supported languages: {', '.join(supported_languages)}",
                    "info",
                )

                # Build dbt assets once (language-agnostic)
                build_dbt_assets()

                # Generate language-specific reports for each language
                for language in supported_languages:
                    generate_reports_for_language(language)

                # Generate language-agnostic assets once
                generate_reporting_schema_script()
                generate_analytics_metadata()
                move_dbt_docs()  # Move docs for default language

                cprint(
                    f"Multi-language build completed for {len(supported_languages)} languages!",
                    "success",
                )

            else:
                # Optimized build for specific language
                supported_languages = get_supported_languages()
                if args.language not in supported_languages:
                    cprint(
                        f"Error: Language '{args.language}' not in supported languages: {', '.join(supported_languages)}",
                        "error",
                    )
                    sys.exit(1)

                # Build dbt assets once (language-agnostic)
                build_dbt_assets()

                # Generate language-specific reports
                generate_reports_for_language(args.language)

                # Generate language-agnostic assets once
                generate_reporting_schema_script()
                generate_analytics_metadata()
                move_dbt_docs()

                cprint(f"Build completed for language: {args.language}", "success")
        else:
            # Default behavior - optimized build for current language
            cprint(f"Generating build script for current language", "info")

            # Build dbt assets once (language-agnostic)
            build_dbt_assets()

            # Generate language-specific reports for current language
            current_language = get_dbt_project_config().get("vars", {}).get("language", "default")
            generate_reports_for_language(current_language)

            # Generate language-agnostic assets once
            generate_reporting_schema_script()
            generate_analytics_metadata()
            move_dbt_docs()

            cprint("Build completed for current language", "success")

    except Exception as e:
        cprint(f"Error during build: {e}", "error")
        raise
    finally:
        # Always restore the original language setting
        restore_original_language()


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)
