import argparse
import json
import os

from utils.system_utils import cprint


def extract_and_write_to_md(base_path, output_file, mode):
    """
    Extracts data from JSON files in the specified base path and writes it to a Markdown file.
    Args:
        base_path (str): The base path to start extracting the folder structure.
        output_file (str): The path to the output Markdown file.
        mode (str): The mode for opening the output file ('standard' or 'custom').
    """
    if mode == 'standard':
        file_mode = "w"
    else:
        file_mode = "a"

    with open(output_file, file_mode, encoding="utf-8") as file:
        if mode == "standard":
            file.write(f"# List of Tamanu reports\n")
            file.write("## Standard\n")
        else:
            file.write(f"## Custom\n")

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
    standard_path = "dbt_packages/tamanu_source_dbt/models/reports/config"
    custom_path = "models/reports/config"
    output_file = "list_tamanu_reports.md"
    
    # Extract data and write to Markdown
    extract_and_write_to_md(standard_path, output_file, 'standard')
    extract_and_write_to_md(custom_path, output_file, 'custom')

    cprint(f"Report list has been written to {output_file}", "success")


if __name__ == "__main__":
    main()
