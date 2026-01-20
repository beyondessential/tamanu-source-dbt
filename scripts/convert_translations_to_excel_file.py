import sys
from pathlib import Path

import pandas as pd
from utils.dbt_utils import get_deployment_name
from utils.system_utils import cprint


def convert_csv_to_excel(csv_file_path: Path) -> Path:
    """
    Convert a CSV file to Excel format.

    Args:
        csv_file_path: Path to the CSV file

    Returns:
        Path: Path to the created Excel file

    Raises:
        Exception: If conversion fails
    """
    excel_file_path = csv_file_path.with_suffix(".xlsx")

    try:
        df = pd.read_csv(csv_file_path)
        df.to_excel(excel_file_path, index=False)
        cprint(f"Converted: {csv_file_path.name} → {excel_file_path.name}", "success")
        return excel_file_path
    except Exception as e:
        cprint(f"Conversion failed for {csv_file_path.name}: {e}", "error")
        raise


def main():
    """
    Convert translation CSV files to Excel format.
    Handles both standard and project-specific translation files.

    File locations:
    - Standard deployment (tamanu-source-dbt): report_translations_standard.csv (project root)
    - Project deployment:
      - report_translations_standard.csv (in dbt_packages/tamanu_source_dbt/)
      - report_translations_{deployment}.csv (project root)
    """
    # Get project root (parent of scripts directory)
    script_dir = Path(__file__).resolve().parent
    project_root = script_dir.parent

    deployment_name = get_deployment_name()

    cprint("\n" + "="*60, "info")
    cprint("Converting translation files to Excel", "info")
    cprint("="*60 + "\n", "info")
    cprint(f"Deployment: {deployment_name}", "info")
    cprint(f"Project root: {project_root}", "info")

    converted_files = []

    # Determine location of standard translations file
    if deployment_name == "standard":
        # In tamanu-source-dbt, standard file is at project root
        standard_file = project_root / "report_translations_standard.csv"
    else:
        # In project repos, standard file is in dbt_packages
        standard_file = project_root / "dbt_packages" / "tamanu_source_dbt" / "report_translations_standard.csv"

    # Convert standard translations file
    if standard_file.exists():
        cprint(f"\nConverting standard translations...", "info")
        try:
            cprint(f"  Source: {standard_file.relative_to(project_root)}", "info")
        except ValueError:
            cprint(f"  Source: {standard_file}", "info")

        try:
            excel_file = convert_csv_to_excel(standard_file)
            converted_files.append(excel_file)
        except Exception as e:
            cprint(f"Warning: Failed to convert standard file: {e}", "warning")
    else:
        try:
            cprint(f"Standard translation file not found: {standard_file.relative_to(project_root)}", "warning")
        except ValueError:
            cprint(f"Standard translation file not found: {standard_file}", "warning")

    # For non-standard deployments, also look for project-specific translations
    if deployment_name != "standard":
        project_file = project_root / f"report_translations_{deployment_name}.csv"

        if project_file.exists():
            cprint(f"\nConverting project-specific translations ({deployment_name})...", "info")
            try:
                cprint(f"  Source: {project_file.relative_to(project_root)}", "info")
            except ValueError:
                cprint(f"  Source: {project_file}", "info")

            try:
                excel_file = convert_csv_to_excel(project_file)
                converted_files.append(excel_file)
            except Exception as e:
                cprint(f"Warning: Failed to convert project-specific file: {e}", "warning")
        else:
            cprint(f"\nProject-specific translation file not found: {project_file.name}", "info")
            cprint(f"This is expected if the project doesn't have custom translations.", "info")

    # Summary
    cprint("\n" + "="*60, "success")
    cprint(f"✓ Converted {len(converted_files)} file(s)", "success")
    cprint("="*60, "success")

    if converted_files:
        cprint("\nGenerated files:", "info")
        for file in converted_files:
            cprint(f"  - {file.name}", "info")
    else:
        cprint("\nNo files were converted", "warning")
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        cprint(f"Error: {e}", "error")
        sys.exit(1)
