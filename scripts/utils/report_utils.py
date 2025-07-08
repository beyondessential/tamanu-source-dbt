import os
import re

from .dbt_utils import get_deployment_version, get_project_name
from .file_utils import ensure_directory_exists, read_file, write_file
from .system_utils import cprint

SCHEMA = "reporting"
ROLE = "reporting"
BASE_DIR = os.getcwd()
PROJECT_NAME = get_project_name()
VERSION = get_deployment_version()
DBT_PACKAGE_DIR = os.path.join(BASE_DIR, "dbt_packages", "tamanu_source_dbt")
VERSION_DIR = os.path.join(BASE_DIR, "compiled", f"v{VERSION}")

if PROJECT_NAME == 'tamanu_source_dbt':
    DEPLOYMENT = 'standard'
else:
    DEPLOYMENT = PROJECT_NAME.split("_")[-1]


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
    """
    try:
        sql = read_file(sql_file)
        config = read_file(config_file, "json")

        query = re.sub(r"\r?\n\s+", "\n", sql)
        config["query"] = re.sub(f'"{database}"\\.', "", query)
        version = ".".join(VERSION.split(".")[:2])
        config["tamanuVersion"] = f"~{version}.0"

        write_file(output_file, config, "json")
    except Exception as e:
        cprint(f"Error processing files: {e}", "error")
        exit(1)


def generate_project_reports():
    """
    Generates reports for the given target by compiling model nodes tagged with "reports".

    Args:
        target (str): The target tag to filter the report models.

    Returns:
        None: Creates compiled report JSON files in the reports directory.
    """
    manifest_path = os.path.join(BASE_DIR, "target", "manifest.json")
    manifest = read_file(manifest_path, "json")

    nodes = [
        key
        for key in manifest["nodes"]
        if key.startswith("model")
        and "reports" in manifest["nodes"][key].get("tags", [])
    ]

    if not nodes:
        cprint(f"No report models found", "error")
        return

    ensure_directory_exists(VERSION_DIR)

    for node in nodes:
        report = manifest["nodes"][node]

        sql_file = os.path.join(BASE_DIR, report["compiled_path"])
        config_file = (
            os.path.join(
                (
                    DBT_PACKAGE_DIR
                    if report["package_name"] != PROJECT_NAME
                    else BASE_DIR
                ),
                report["original_file_path"],
            )
            .replace(".sql", ".json")
            .replace("sql", "config")
        )
        output_file = os.path.join(VERSION_DIR, f"{report['name']}-v{VERSION}-{DEPLOYMENT}.json")

        compile_report(report["database"], sql_file, config_file, output_file)
        cprint(f"Compiled report: {report['name']}-v{VERSION}-{DEPLOYMENT}.json", "success")


def generate_import_report_script():
    """
    Generates a Python script to import the compiled report JSON files.

    The generated script will iterate over all JSON files in the reports directory
    and execute a command to import each report using a Node.js application.

    Returns:
        None: Writes the Python script to the reports directory.
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

    ensure_directory_exists(VERSION_DIR)
    output_path = os.path.join(VERSION_DIR, "import_reports.js")
    write_file(output_path, script)

    cprint(f"Script created successfully at: {output_path}", "success")


def generate_reporting_schema_script():
    """
    Generates a SQL script to create views in the reporting schema.

    The script is generated based on the model nodes that do not have the "reports" tag and
    are compiled in the project. Dependencies between models are resolved before generating
    the views in the schema.

    Args:
        target (str): The target tag to filter models for generating views.

    Returns:
        None: Writes the SQL schema build script to the views directory.
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
        cprint(f"No models found", "error")
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
            cprint("Error: Circular dependency or missing dependency.", "error")
            exit(1)

        for node in current:
            processed.add(node)
            ordered.append(node)

    scripts = [
        f"drop schema if exists {SCHEMA} cascade;",
        f"create schema {SCHEMA};",
        f"grant usage on schema {SCHEMA} to {ROLE};",
        f"alter default privileges in schema {SCHEMA} grant select on tables to {ROLE};",
    ]

    for node in ordered:
        model = manifest["nodes"][node]
        if model["compiled_path"] is None:
            cprint(f"Model {model['name']} has no compiled path, skipping.", "warning")
            continue
        compiled_sql = read_file(os.path.join(BASE_DIR, model["compiled_path"]))
        cleaned_sql = re.sub(f'"{model["database"]}"\\.', "", compiled_sql)
        scripts.append(
            f'create or replace view "{SCHEMA}"."{model["name"]}" as (\n{cleaned_sql}\n);'
        )

    ensure_directory_exists(VERSION_DIR)
    output_file = os.path.join(
        VERSION_DIR, f"reporting-schema-v{VERSION}-{DEPLOYMENT}.sql"
    )
    write_file(output_file, "\n".join(scripts))
