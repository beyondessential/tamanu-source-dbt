import sys
import os
from pathlib import Path

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
from generate_translation_macro import generate_translation_macro


BASE_DIR = os.getcwd()
DEPLOYMENT = get_deployment_name()
SCRIPTS_DIR = Path("scripts") if DEPLOYMENT == "standard" else Path("dbt_packages") / "tamanu_source_dbt" / "scripts"
VERSION = get_deployment_version()
VERSION_DIR = os.path.join(BASE_DIR, "compiled", f"v{VERSION}")


def main():
    """Build Tamanu reporting assets for all supported languages"""
    cprint(f"\n{'='*60}", "info")
    cprint("BUILD TAMANU REPORTING ASSETS", "info")
    cprint(f"{'='*60}", "info")
    cprint(f"Version: {VERSION}", "info")
    cprint(f"Deployment: {DEPLOYMENT}", "info")
    cprint(f"Scripts directory: {SCRIPTS_DIR}", "info")
    cprint(f"{'='*60}\n", "info")   

    try:
        # Step 1: Generate survey models (only for non-standard deployments)
        if DEPLOYMENT != "standard":
            cprint("\nGenerating survey models...", "info")
            execute_command(f"python {SCRIPTS_DIR / 'generate_survey_models.py'}")
            cprint("Survey models generated successfully!", "success")
        else:
            cprint("\nSkipping survey models generation (standard deployment)", "info")

        # Step 2: Validate report configurations
        cprint("\nValidating report configurations...", "info")
        execute_command(f"python {SCRIPTS_DIR / 'validate_report_configs.py'}")
        cprint("Report configurations validated successfully!", "success")

        # Step 3: Process translations
        cprint("\n" + "="*60, "info")
        cprint("Processing translations...", "info")
        cprint("="*60, "info")

        cprint("\nChecking translations...", "info")
        execute_command(f"python {SCRIPTS_DIR / 'check_translations.py'}")
        cprint("Translations checked successfully!", "success")

        cprint("\nConverting translations to Excel file...", "info")
        execute_command(f"python {SCRIPTS_DIR / 'convert_translations_to_excel_file.py'}")
        cprint("Translations converted to Excel successfully!", "success")

        # Step 4: Build reporting assets
        cprint("\n" + "="*60, "info")
        cprint("Building reporting assets...", "info")
        cprint("="*60 + "\n", "info")

        # Get supported languages from configuration
        config = get_dbt_project_config()
        supported_languages = config.get("vars", {}).get("supported_languages", ["default"])

        cprint(
            f"Building for all supported languages: {', '.join(supported_languages)}",
            "info",
        )

        # Ensure version directory exists
        ensure_directory_exists(VERSION_DIR)
        # Clean and prepare dbt environment
        cprint("Preparing dbt environment", "info")
        execute_command("dbt clean")
        execute_command("dbt deps")

        # Regenerate the default translations macro so dbt picks up the latest CSVs
        cprint("Generating default translations macro", "info")
        generate_translation_macro()

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
        target_file = os.path.join(
            VERSION_DIR, f"reporting-docs-v{VERSION}-{DEPLOYMENT}.html"
        )
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

        # Step 5: List Tamanu reports
        cprint("\nListing Tamanu reports...", "info")
        execute_command(f"python {SCRIPTS_DIR / 'list_tamanu_reports.py'}")
        cprint("Tamanu reports listed successfully!", "success")

        # Success summary
        cprint("\n" + "="*60, "success")
        cprint("✓ BUILD COMPLETE!", "success")
        cprint("="*60, "success")
        cprint(f"\nReporting assets built for version {VERSION}", "success")
        cprint("\nNext steps:", "info")
        cprint("1. Review the generated files in compiled/", "info")
        cprint("2. Commit the changes: git add . && git commit", "info")
        cprint("3. Push to remote: git push", "info")

    except Exception as e:
        cprint(f"Error during build: {e}", "error")
        raise


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)
