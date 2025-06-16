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
    if report_type == 'standard':
        file_mode = "w"
    else:
        file_mode = "a"

    with open(output_file, file_mode, encoding="utf-8") as file:
        if report_type == "Standard":
            file.write(f"# List of Tamanu reports\n")

        file.write(f"## {report_type}\n")
        
        for root, _, files in os.walk(base_path):
            for file_name in files:
                if file_name.endswith(".json"):
                    json_file_path = os.path.join(root, file_name)

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
                    file.write(
                        f"### {report_id.replace('-', ' ').replace('.json', '').capitalize()}\n\n"
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
    model_type = "Standard"
    
    if os.path.exists(standard_md_file):
        # Copy the existing file to the current directory
        shutil.copy2(standard_md_file, output_file)
        cprint(f"Copied existing report list from {standard_md_file} to {output_file}", "success")
        model_type = "Custom"
        return
        
    path = "models/reports/config"
    
    # Extract data and write to Markdown
    extract_and_write_to_md(path, output_file, model_type)
    
    cprint(f"{model_type} report list has been written to {output_file}", "success")


if __name__ == "__main__":
    main()
