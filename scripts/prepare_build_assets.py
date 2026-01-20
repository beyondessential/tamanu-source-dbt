"""
Prepare and Build Tamanu Reporting Assets

This script prepares models and builds reporting assets after a Tamanu version upgrade.
It should be run after the version has been upgraded and source models refreshed
(typically via the GitHub Actions workflow).

The script performs the following steps:
1. Generate survey models (for non-standard deployments)
2. Validate report configurations
3. Process translations (check, generate macro, convert to Excel)
4. Build reporting assets
5. List Tamanu reports

Usage:
    python scripts/prepare_build_assets.py
"""

import argparse
import sys

from utils import (
    cprint,
    execute_command,
    get_deployment_name,
    get_deployment_version,
)


def generate_survey_models() -> None:
    """
    Run the generate_survey_models.py script to create survey models.
    """
    try:
        cprint("\nGenerating survey models...", "info")
        execute_command("python scripts/generate_survey_models.py")
        cprint("Survey models generated successfully!", "success")

    except Exception as e:
        cprint(f"Error generating survey models: {e}", "error")
        raise


def validate_report_configs() -> None:
    """
    Run the validate_report_configs.py script to validate report configurations.
    """
    try:
        cprint("\nValidating report configurations...", "info")
        execute_command("python scripts/validate_report_configs.py")
        cprint("Report configurations validated successfully!", "success")

    except Exception as e:
        cprint(f"Error validating report configs: {e}", "error")
        raise


def check_translations() -> None:
    """
    Run the check_translations.py script to check translation files.
    """
    try:
        cprint("\nChecking translations...", "info")
        execute_command("python scripts/check_translations.py")
        cprint("Translations checked successfully!", "success")

    except Exception as e:
        cprint(f"Error checking translations: {e}", "error")
        raise


def generate_translation_macro() -> None:
    """
    Run the generate_translation_macro.py script to generate translation macros.
    """
    try:
        cprint("\nGenerating translation macro...", "info")
        execute_command("python scripts/generate_translation_macro.py")
        cprint("Translation macro generated successfully!", "success")

    except Exception as e:
        cprint(f"Error generating translation macro: {e}", "error")
        raise


def convert_translations_to_excel() -> None:
    """
    Run the convert_translations_to_excel_file.py script to convert translations.
    """
    try:
        cprint("\nConverting translations to Excel file...", "info")
        execute_command("python scripts/convert_translations_to_excel_file.py")
        cprint("Translations converted to Excel successfully!", "success")

    except Exception as e:
        cprint(f"Error converting translations to Excel: {e}", "error")
        raise


def build_reporting_assets() -> None:
    """
    Run the build_reporting_assets.py script to regenerate reporting assets.
    """
    try:
        cprint("\nBuilding reporting assets...", "info")
        execute_command("python scripts/build_reporting_assets.py")
        cprint("Reporting assets built successfully!", "success")

    except Exception as e:
        cprint(f"Error building reporting assets: {e}", "error")
        raise


def list_tamanu_reports() -> None:
    """
    Run the list_tamanu_reports.py script to list all reports.
    """
    try:
        cprint("\nListing Tamanu reports...", "info")
        execute_command("python scripts/list_tamanu_reports.py")
        cprint("Tamanu reports listed successfully!", "success")

    except Exception as e:
        cprint(f"Error listing Tamanu reports: {e}", "error")
        raise


def main():
    """Main preparation and build process."""
    parser = argparse.ArgumentParser(
        description="Prepare models and build Tamanu reporting assets",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
This script should be run after upgrading the Tamanu version and refreshing source models.
It prepares all models and builds the reporting assets for deployment.

Typical workflow:
  1. Run GitHub Actions workflow to upgrade version and refresh sources
  2. Merge the PR
  3. Run this script locally: python scripts/prepare_build_assets.py
        """
    )

    args = parser.parse_args()

    try:
        # Get current version and deployment info
        current_version = get_deployment_version()
        deployment_name = get_deployment_name()

        cprint(f"\n{'='*60}", "info")
        cprint("PREPARE AND BUILD REPORTING ASSETS", "info")
        cprint(f"{'='*60}", "info")
        cprint(f"Version: {current_version}", "info")
        cprint(f"Deployment: {deployment_name}", "info")
        cprint(f"{'='*60}\n", "info")

        # Step 1: Generate survey models (only for non-standard deployments)
        if deployment_name != "standard":
            generate_survey_models()
        else:
            cprint("\nSkipping survey models generation (standard deployment)", "info")

        # Step 2: Validate report configurations
        validate_report_configs()

        # Step 3: Process translations
        cprint("\n" + "="*60, "info")
        cprint("Processing translations...", "info")
        cprint("="*60, "info")
        check_translations()
        generate_translation_macro()
        convert_translations_to_excel()

        # Step 4: Build reporting assets
        build_reporting_assets()

        # Step 5: List Tamanu reports
        list_tamanu_reports()

        # Success summary
        cprint("\n" + "="*60, "success")
        cprint("✓ BUILD COMPLETE!", "success")
        cprint("="*60, "success")
        cprint(f"\nReporting assets built for version {current_version}", "success")
        cprint("\nNext steps:", "info")
        cprint("1. Review the generated files in compiled/", "info")
        cprint("2. Commit the changes: git add . && git commit", "info")
        cprint("3. Push to remote: git push", "info")

    except KeyboardInterrupt:
        cprint("\n\nBuild cancelled by user", "warning")
        sys.exit(1)
    except Exception as e:
        cprint(f"\n\nBuild failed: {e}", "error")
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except Exception as err:
        cprint(f"Error: {err}", "error")
        sys.exit(1)
