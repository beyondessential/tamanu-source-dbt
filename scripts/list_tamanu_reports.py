import argparse
import json
import os
import shutil

from utils.system_utils import cprint


def extract_and_write_to_md(base_path, output_file, report_type):
    """
    Extracts data from JSON files in the specified base path and writes it to a Markdown file.
    Args:
        base_path (str): The base path to start extracting the folder structure.
        output_file (str): The path to the output Markdown file.
        report_type (str): The report_type being listed ('Standard' or 'Custom').
    """
    if report_type == 'Standard':
        file_mode = "w"
    else:
        file_mode = "a"

    with open(output_file, file_mode, encoding="utf-8") as file:
        if report_type == "Standard":
            file.write("# List of Tamanu reports\n\n")
            folder_heading = "##"
        else:
            file.write(f"\n## {report_type}\n\n")
            folder_heading = "###"

        # Build set of report names that have a sensitive equivalent
        sensitive_dir = os.path.join(base_path, 'sensitive')
        sensitive_names = set()
        if os.path.isdir(sensitive_dir):
            for f in os.listdir(sensitive_dir):
                if f.endswith(".json") and f.startswith("sensitive-"):
                    sensitive_names.add(f[len("sensitive-"):])

        # Group files by folder, in specified order, excluding sensitive
        folder_order = ['standard', 'custom']
        folders = {}
        for root, _, files in os.walk(base_path):
            json_files = sorted(f for f in files if f.endswith(".json"))
            if json_files:
                folder_name = os.path.relpath(root, base_path)
                if folder_name not in ('sensitive', '.') and folder_name in folder_order:
                    folders[folder_name] = [os.path.join(root, f) for f in json_files]

        for folder_name in (f for f in folder_order if f in folders):
            file.write(f"{folder_heading} {folder_name.capitalize()}\n\n")

            for json_file_path in folders[folder_name]:
                with open(json_file_path, "r", encoding="utf-8") as json_file:
                    data = json.load(json_file)

                # Extract data
                report_id = os.path.basename(json_file_path)
                report_description = data.get("notes", "")
                default_date_range = data.get("queryOptions", {}).get(
                    "defaultDateRange", ""
                )
                filters = ", ".join(
                    param.get("label", "")
                    for param in data.get("queryOptions", {}).get("parameters", [])
                )

                # Write to Markdown
                has_sensitive = report_id in sensitive_names
                sensitive_marker = " *(sensitive version available)*" if has_sensitive else ""
                file.write(
                    f"### {report_id.replace('-', ' ').replace('.json', '').capitalize()}{sensitive_marker}\n\n"
                )
                file.write(f"**Report Description**\n\n{report_description}\n\n")
                file.write(f"**Filters**\n\n{filters}\n\n") if filters else ""
                file.write(f"**Default date range**: {default_date_range}\n\n")
                file.write("\n---\n\n")


def main():
    """
    Main function to generate a list of reports in Markdown format.
    Example Usage:
        python list_tamanu_reports.py
    """
    # Check if the pre-existing list_tamanu_reports.md exists in dbt_packages
    standard_md_file = "dbt_packages/tamanu_source_dbt/list_tamanu_reports.md"
    output_file = "list_tamanu_reports.md"
    report_type = "Standard"
    
    if os.path.exists(standard_md_file):
        # Copy the existing file to the current directory
        shutil.copy2(standard_md_file, output_file)
        cprint(f"Copied existing report list from {standard_md_file} to {output_file}", "success")
        report_type = "Custom"
        return
        
    path = "models/reports/config"
    
    # Extract data and write to Markdown
    extract_and_write_to_md(path, output_file, report_type)
    
    cprint(f"{report_type} report list has been written to {output_file}", "success")


if __name__ == "__main__":
    main()
