import os
import re

from dbt_utils import get_deployment_version
from file_utils import ensure_directory_exists, read_file, write_file

SCHEMA = "reporting"
ROLE = "reporting"
BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "../.."))
REPORTS_DIR = os.path.join(BASE_DIR, "compiled", "reports")
VIEWS_DIR = os.path.join(BASE_DIR, "compiled", "views")


def compile_report(database, sql_file, config_file, output_file):
    """
    Compiles a report by processing the SQL and config files and generating a JSON output.

    Args:
        database (str): The name of the database used in the report.
        sql_file (str): The path to the SQL file.
        config_file (str): The path to the configuration file.
        output_file (str): The path to the output JSON file.

    Returns:
        None: Writes the compiled configuration to the output file.

    Raises:
        Exception: If there is an error reading or processing the files.
    """
    try:
        sql = read_file(sql_file)
        config = read_file(config_file, "json")

        query = re.sub(r"\r?\n\s+", "\n", sql)
        config["query"] = re.sub(f'"{database}"\.', "", query)
        config["db_schema"] = SCHEMA

        write_file(output_file, config, "json")
    except Exception as e:
        print(f"Error processing files: {e}")
        exit(1)


def generate_project_reports(target):
    """
    Generates reports for the given target by compiling model nodes tagged with "reports".

    Args:
        target (str): The target tag to filter the report models.

    Returns:
        None: Creates compiled report JSON files in the reports directory.

    Raises:
        Exception: If no report models are found for the target, or if there is an error in processing.
    """
    manifest_path = os.path.join(BASE_DIR, "target", "manifest.json")
    manifest = read_file(manifest_path, "json")

    nodes = [
        key
        for key in manifest["nodes"]
        if key.startswith("model")
        and "reports" in manifest["nodes"][key].get("tags", [])
        and target in manifest["nodes"][key].get("tags", [])
    ]

    if not nodes:
        print(f"No report models found for target: {target}")
        return

    ensure_directory_exists(REPORTS_DIR)

    for node in nodes:
        report = manifest["nodes"][node]
        sql_file = os.path.join(BASE_DIR, report["compiled_path"])
        config_file = (
            os.path.join(BASE_DIR, report["original_file_path"])
            .replace(".sql", ".json")
            .replace("sql", "config")
        )
        output_file = os.path.join(REPORTS_DIR, f"{report['name']}.json")

        compile_report(report["database"], sql_file, config_file, output_file)
        print(f"Compiled report: {report['name']}.sql")


def generate_import_report_script():
    """
    Generates a Python script to import the compiled report JSON files.

    The generated script will iterate over all JSON files in the reports directory
    and execute a command to import each report using a Node.js application.

    Returns:
        None: Writes the Python script to the reports directory.

    Raises:
        Exception: If there is an error reading the JSON files or executing the commands.
    """
    script = """const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");

const folderPath = path.resolve(".");
const baseCommand = "node ./dist/app.bundle.js importReport";

fs.readdir(folderPath, async (err, files) => {
  if (err) {
    console.error(`Error reading directory: ${err.message}`);
    return;
  }

  const jsonFiles = files.filter((file) => file.endsWith(".json"));
  if (jsonFiles.length === 0) {
    console.log("No JSON files found in the folder.");
    return;
  }

  for (const file of jsonFiles) {
    const filePath = path.join(folderPath, file);
    try {
      const fileContent = await fs.promises.readFile(filePath, "utf-8");
      const json = JSON.parse(fileContent);
      const reportName = json.name;
      const command = `${baseCommand} -n '${reportName}' -f "${filePath}"`;
      console.log(`Executing command: ${command}`);
      exec(command, (err, stdout, stderr) => {
        if (err) {
          console.error(`Error executing command for file ${file}: ${err.message}`);
          return;
        }
        if (stderr) {
          console.error(`Error output for file ${file}: ${stderr}`);
          return;
        }
        console.log(`Success for file ${file}: ${stdout}`);
      });
    } catch (err) {
      console.error(`Error processing file ${file}: ${err.message}`);
    }
  }
});
"""

    ensure_directory_exists(REPORTS_DIR)
    output_path = os.path.join(REPORTS_DIR, "import_reports.js")
    write_file(output_path, script)

    print(f"Script created successfully at: {output_path}")


def generate_reporting_schema_script(target):
    """
    Generates a SQL script to create views in the reporting schema.

    The script is generated based on the model nodes that do not have the "reports" tag and
    are compiled in the project. Dependencies between models are resolved before generating
    the views in the schema.

    Args:
        target (str): The target tag to filter models for generating views.

    Returns:
        None: Writes the SQL schema build script to the views directory.

    Raises:
        Exception: If circular dependencies are detected or if there is an error in processing.
    """
    manifest_path = os.path.join(BASE_DIR, "target", "manifest.json")
    manifest = read_file(manifest_path, "json")

    nodes = [
        key
        for key in manifest["nodes"]
        if key.startswith("model")
        and "reports" not in manifest["nodes"][key].get("tags", [])
    ]

    if not nodes:
        print(f"No models found with the target: {target}")
        return

    processed = set()
    ordered = []

    while len(processed) < len(nodes):
        current = [
            node
            for node in nodes
            if node not in processed
            and all(
                dep.startswith("source") or dep in processed
                for dep in manifest["nodes"][node]["depends_on"]["nodes"]
            )
        ]
        if not current:
            print("Error: Circular dependency or missing dependency.")
            exit(1)

        for node in current:
            processed.add(node)
            ordered.append(node)

    scripts = [
        f"drop schema if exists {SCHEMA} cascade;",
        f"create schema {SCHEMA};",
        f"alter default privileges in schema {SCHEMA} grant select on tables to {ROLE};",
    ]

    for node in ordered:
        model = manifest["nodes"][node]
        compiled_sql = read_file(os.path.join(BASE_DIR, model["compiled_path"]))
        cleaned_sql = re.sub(f'"{model["database"]}"\\.', "", compiled_sql)
        scripts.append(
            f'create or replace view "{SCHEMA}"."{model["name"]}" as (\n{cleaned_sql}\n);'
        )

    ensure_directory_exists(VIEWS_DIR)
    output_file = os.path.join(
        VIEWS_DIR, f"reporting_schema_build_script_v{get_deployment_version()}.sql"
    )
    write_file(output_file, "\n".join(scripts))
