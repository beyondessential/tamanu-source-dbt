import sys
from pathlib import Path

import pandas as pd
from utils.dbt_utils import get_deployment_name
from utils.system_utils import cprint


def main():
    """
    Convert translation CSV files to a single Excel file.
    Merges both standard and project-specific translation files into one sheet.

    File locations:
    - Standard deployment (tamanu-source-dbt): report_translations_standard.csv (project root)
    - Project deployment:
      - report_translations_standard.csv (in dbt_packages/tamanu_source_dbt/)
      - report_translations_{deployment}.csv (project root)
    """
    # Get project root by finding dbt_project.yml
    # This works whether script is in scripts/ or dbt_packages/tamanu_source_dbt/scripts/
    current_dir = Path.cwd()
    project_root = current_dir

    # Search upwards for dbt_project.yml to find true project root
    while project_root != project_root.parent:
        if (project_root / "dbt_project.yml").exists():
            break
        project_root = project_root.parent

    if not (project_root / "dbt_project.yml").exists():
        cprint("Error: Could not find dbt_project.yml", "error")
        sys.exit(1)

    deployment_name = get_deployment_name()

    cprint("\n" + "="*60, "info")
    cprint("Converting translation files to Excel", "info")
    cprint("="*60 + "\n", "info")
    cprint(f"Deployment: {deployment_name}", "info")
    cprint(f"Project root: {project_root}", "info")

    dataframes = []
    source_files = []

    # Determine location of standard translations file
    if deployment_name == "standard":
        # In tamanu-source-dbt, standard file is at project root
        standard_file = project_root / "report_translations_standard.csv"
    else:
        # In project repos, standard file is in dbt_packages
        standard_file = project_root / "dbt_packages" / "tamanu_source_dbt" / "report_translations_standard.csv"

    # Load standard translations file
    if standard_file.exists():
        cprint(f"\nLoading standard translations...", "info")
        try:
            cprint(f"  Source: {standard_file.relative_to(project_root)}", "info")
        except ValueError:
            cprint(f"  Source: {standard_file}", "info")

        try:
            df_standard = pd.read_csv(standard_file)
            dataframes.append(df_standard)
            source_files.append(standard_file.name)
            cprint(f"  Loaded {len(df_standard)} rows", "success")
        except Exception as e:
            cprint(f"Warning: Failed to load standard file: {e}", "warning")
    else:
        try:
            cprint(f"Standard translation file not found: {standard_file.relative_to(project_root)}", "warning")
        except ValueError:
            cprint(f"Standard translation file not found: {standard_file}", "warning")

    # For non-standard deployments, also load project-specific translations
    if deployment_name != "standard":
        project_file = project_root / f"report_translations_{deployment_name}.csv"

        if project_file.exists():
            cprint(f"\nLoading project-specific translations ({deployment_name})...", "info")
            try:
                cprint(f"  Source: {project_file.relative_to(project_root)}", "info")
            except ValueError:
                cprint(f"  Source: {project_file}", "info")

            try:
                df_project = pd.read_csv(project_file)
                dataframes.append(df_project)
                source_files.append(project_file.name)
                cprint(f"  Loaded {len(df_project)} rows", "success")
            except Exception as e:
                cprint(f"Warning: Failed to load project-specific file: {e}", "warning")
        else:
            cprint(f"\nProject-specific translation file not found: {project_file.name}", "info")
            cprint(f"This is expected if the project doesn't have custom translations.", "info")

    # Merge and convert to Excel
    if dataframes:
        cprint("\n" + "="*60, "info")
        cprint("Merging translation files...", "info")
        cprint("="*60, "info")

        # Concatenate all dataframes
        merged_df = pd.concat(dataframes, ignore_index=True)
        cprint(f"Total rows: {len(merged_df)}", "info")

        # Create output filename
        if deployment_name == "standard":
            output_file = project_root / "report_translations_standard.xlsx"
        else:
            output_file = project_root / f"report_translations_{deployment_name}.xlsx"

        # Write to Excel
        try:
            merged_df.to_excel(output_file, index=False)
            cprint(f"\n✓ Created: {output_file.name}", "success")
            cprint(f"  Source files merged: {', '.join(source_files)}", "info")
            cprint(f"  Total rows: {len(merged_df)}", "info")
        except Exception as e:
            cprint(f"Error writing Excel file: {e}", "error")
            sys.exit(1)

        # Summary
        cprint("\n" + "="*60, "success")
        cprint("✓ Conversion complete!", "success")
        cprint("="*60, "success")
    else:
        cprint("\nNo translation files found", "warning")
        sys.exit(1)


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        cprint(f"Error: {e}", "error")
        sys.exit(1)
