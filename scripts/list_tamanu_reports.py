import argparse
import json
import os


def extract_and_write_to_md(base_path, output_file):
    """
    Extracts data from JSON files in the specified base path and writes it to a Markdown file.
    Args:
        base_path (str): The base path to start extracting the folder structure.
        output_file (str): The path to the output Markdown file.
    """
    with open(output_file, 'w', encoding='utf-8') as file:
        current_deployment = None

        for root, _, files in os.walk(base_path):
            for file_name in files:
                if file_name.endswith(".json"):
                    json_file_path = os.path.join(root, file_name)

                    with open(json_file_path, 'r', encoding='utf-8') as json_file:
                        data = json.load(json_file)

                    # Extract data
                    deployment = os.path.basename(root)
                    report_id = os.path.basename(json_file_path)
                    report_description = data.get("notes", "")
                    default_date_range = data.get("queryOptions", {}).get("defaultDateRange", "")
                    filters = ", ".join(
                        param.get("label", "") for param in data.get("queryOptions", {}).get("parameters", [])
                    )

                    # Write to Markdown
                    deployment_title = deployment.title()
                    if deployment_title != current_deployment:
                        current_deployment = deployment_title
                        file.write(f"# {current_deployment}\n\n")

                    file.write(f"## {report_id.replace('-', ' ').replace('.json', '').capitalize()}\n\n")
                    file.write(f"**Report Description**\n\n{report_description}\n\n")
                    file.write(f"**Filters**\n\n{filters}\n\n") if filters else ""
                    file.write(f"**Default date range**: {default_date_range}\n\n")
                    file.write("\n---\n\n")

def main():
    """
    Main function to generate a list of reports in Markdown format.
    This function parses command-line arguments to determine the base path for extracting
    the folder structure and the output file path for the generated Markdown file. It then
    processes the JSON report files and writes the results to the specified Markdown file.
    Command-Line Arguments:
        base_path (str, optional): The base path to start extracting the folder structure.
                                   Defaults to 'bases'.
        output_file (str, optional): The path to the output Markdown file.
                                     Defaults to 'list_tamanu_reports.md'.
    Example Usage:
        python list_tamanu_reports.py
        python list_tamanu_reports.py ./custom/reports ./custom/output/reports_list.md
    """
    parser = argparse.ArgumentParser(description="Generate a report list in Markdown format.")
    parser.add_argument(
        "base_path", 
        nargs="?",
        default="models/reports/config",
        help="The base path to start the folder structure extraction. Defaults to bases")
    parser.add_argument(
        "output_file", 
        nargs="?",
        default="list_tamanu_reports.md",
        help="The path to the output Markdown file. Defaults to list_tamanu_reports.md")
    args = parser.parse_args()

    # Extract data and write to Markdown
    extract_and_write_to_md(args.base_path, args.output_file)

    print(f"Report list has been written to {args.output_file}")

if __name__ == "__main__":
    main()


# import argparse
# import json
# from openpyxl import Workbook
# import os
# import re

# def extract_data_from_json(json_file_path):
#     """
#     Extracts the required data from a JSON file.
#     Args:
#         json_file_path (str): The path to the JSON file.

#     Returns:
#         dict: A dictionary containing the extracted data.
#     """
#     with open(json_file_path, 'r', encoding='utf-8') as file:
#         data = json.load(file)

#     # Extract report name, version, and description
#     extracted_data = {
#         "report_id": os.path.basename(json_file_path),
#         "report_description": data.get("notes", ""),
#         "default_date_range": data.get("queryOptions", {}).get("defaultDateRange", ""),
#         "filters": [param.get("label", "") for param in data.get("queryOptions", {}).get("parameters", [])]
#     }
#     return extracted_data

# def get_folder_structure(base_path):
#     """
#     Recursively gets the folder structure starting from the base path.

#     Args:
#         base_path (str): The base path to start the folder structure extraction.

#     Returns:
#         list: A list of dictionaries containing the folder path, report ID, about report, default date range, and filters.
#     """
#     folder_structure = []
#     for root, dirs, files in os.walk(base_path):
#         for file in files:
#             if file.endswith(".json"):
#                 json_file_path = os.path.join(root, file)
#                 extracted_data = extract_data_from_json(json_file_path)
#                 folder_structure.append({
#                     "deployment": os.path.basename(root),
#                     "report_id": extracted_data["report_id"],
#                     "report_description": extracted_data["report_description"],
#                     "default_date_range": extracted_data["default_date_range"],
#                     "filters": ", ".join(extracted_data["filters"])
#                 })
#     return folder_structure

# def write_to_excel(folder_structure, output_file):
#     """
#     Writes the folder structure to an Excel file.

#     Args:
#         folder_structure (list): The folder structure to write.
#         output_file (str): The path to the output Excel file.
#     """
#     wb = Workbook()
#     ws = wb.active
#     ws.title = "Reports"

#     # Write headers
#     ws.append(["Deployment", "Report code", "Description", "Default date range", "Filters"])

#     # Write folder structure
#     for item in folder_structure:
#         ws.append([item["deployment"], 
#                    item["report_id"], 
#                    item["report_description"], 
#                    item["default_date_range"], 
#                    item["filters"]])

#     # Save the workbook
#     wb.save(output_file)

# def write_to_md(folder_structure, output_file):
#     """
#     Writes the folder structure to a Markdown file.

#     Args:
#         folder_structure (list): The folder structure to write.
#         output_file (str): The path to the output Markdown file.
#     """
#     with open(output_file, 'w', encoding='utf-8') as file:
#         current_deployment = None

#         for item in folder_structure:
#             deployment_title = item["deployment"].title()
#             if deployment_title != current_deployment:
#                 current_deployment = deployment_title
#                 file.write(f"# {current_deployment}\n\n")
            
#             file.write(f"## {item['report_id'].replace('-', ' ').replace('.json', '').capitalize()}\n\n")
#             file.write(f"**Report Description**\n\n{item['report_description']}\n\n")
#             file.write(f"**Filters**\n\n{item['filters']}\n\n") if item['filters'] else ""
#             file.write(f"**Default date range**: {item['default_date_range']}\n\n")
#             file.write("\n---\n\n")

# def main():
#     parser = argparse.ArgumentParser(description="Generate a report list in Markdown format.")
#     parser.add_argument(
#         "base_path", 
#         nargs="?",
#         default="models/reports/config",
#         help="The base path to start the folder structure extraction. Defaults to models/reports/config")
#     parser.add_argument(
#         "output_file", 
#         nargs="?",
#         default="list_tamanu_reports.md",
#         help="The path to the output Markdown file. Defaults to list_tamanu_reports.md")
#     args = parser.parse_args()

#     # Get folder structure
#     folder_structure = get_folder_structure(args.base_path)

#     # Write to file in Markdown format
#     write_to_md(folder_structure, args.output_file)

#     print(f"Folder structure has been written to {args.output_file}")

# if __name__ == "__main__":
#     main()