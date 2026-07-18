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
from generate_metric_definitions_macro import generate_metric_definitions_macro


BASE_DIR = os.getcwd()
DEPLOYMENT = get_deployment_name()
SCRIPTS_DIR = Path("scripts") if DEPLOYMENT == "standard" else Path("dbt_packages") / "tamanu_source_dbt" / "scripts"
VERSION = get_deployment_version()
VERSION_DIR = os.path.join(BASE_DIR, "compiled", f"v{VERSION}")


def main():
    """Build Tamanu reporting assets for all supported languages"""
    cprint(f"\nBuilding Tamanu reporting assets v{VERSION} ({DEPLOYMENT})", "info")

    try:
        # Build reporting assets
        config = get_dbt_project_config()
        supported_languages = config.get("vars", {}).get("supported_languages", ["default"])

        cprint(f"Building for languages: {', '.join(supported_languages)}", "info")

        ensure_directory_exists(VERSION_DIR)
        execute_command("dbt clean --profiles-dir config")
        execute_command("dbt deps --profiles-dir config")

        # Generate translation macro before any dbt compilation
        generate_translation_macro()

        # Generate the metric-definitions macro only for the standard package
        # build. Deployment repos consume the package's canonical
        # get_metric_definitions macro directly (via macro-paths); running
        # this here for a deployment would regenerate a local
        # macros/metric_definitions.sql and delete the package's copy,
        # reintroducing a duplicate-macro collision on the deployment's next
        # `dbt deps` (see tamanu-dbt-msf-kule OQ-10).
        if DEPLOYMENT == "standard":
            generate_metric_definitions_macro()

        # Generate survey models (only for non-standard deployments)
        if DEPLOYMENT != "standard":
            cprint("Generating survey models...", "info")
            execute_command(f"python {SCRIPTS_DIR / 'generate_survey_models.py'}")

        # Validate report configurations
        cprint("Validating report configurations...", "info")
        execute_command(f"python {SCRIPTS_DIR / 'validate_report_configs.py'}")

        # Process translations
        cprint("Processing translations...", "info")
        execute_command(f"python {SCRIPTS_DIR / 'check_translations.py'}")

        execute_command("dbt run --profiles-dir config")
        execute_command("dbt docs generate --profiles-dir config --static")

        hide_macros_from_docs()
        hide_tests_from_docs()

        generate_reporting_schema_script()
        generate_analytics_metadata()

        source_file = os.path.join(BASE_DIR, "target", "static_index.html")
        target_file = os.path.join(
            VERSION_DIR, f"reporting-docs-v{VERSION}-{DEPLOYMENT}.html"
        )
        move_file(source_file, target_file)

        # Generate language-specific reports
        for language in supported_languages:
            execute_command(f'dbt compile --profiles-dir config --vars "{{language: {language}}}"')
            generate_project_reports(language)

        cprint(f"\n✓ Build complete for version {VERSION}", "success")

    except Exception as e:
        cprint(f"Error during build: {e}", "error")
        raise


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)
