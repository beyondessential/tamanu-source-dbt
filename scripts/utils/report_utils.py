import json
import os
import re

from .dbt_utils import (
    get_dbt_project_vars,
    get_deployment_name,
    get_deployment_version,
    get_project_name,
)
from .file_utils import ensure_directory_exists, read_file, write_file
from .system_utils import cprint, execute_command

SCHEMA = "reporting"
ROLE = "tamanu_reporting"
BASE_DIR = os.getcwd()
PROJECT_NAME = get_project_name()
DEPLOYMENT = get_deployment_name()
VERSION = get_deployment_version()
DBT_PACKAGE_DIR = os.path.join(BASE_DIR, "dbt_packages", "tamanu_source_dbt")
VERSION_DIR = os.path.join(BASE_DIR, "compiled", f"v{VERSION}")


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


def generate_project_reports(language):
    """
    Generates reports for the given target by compiling model nodes tagged with "reports".
    Nodes tagged "restricted" (i.e. sensitive-facility dataset views) are excluded when
    has_sensitive_facility is false. has_sensitive_facility is read from dbt_project.yml via get_dbt_project_vars(),
    not from the dbt runtime context.

    Args:
        language (str): The language to use for report generation.

    Returns:
        None: Creates compiled report JSON files in the reports directory.
    """
    manifest_path = os.path.join(BASE_DIR, "target", "manifest.json")
    manifest = read_file(manifest_path, "json")

    project_vars = get_dbt_project_vars()
    has_sensitive_facility = project_vars.get("has_sensitive_facility", False)

    nodes = [
        key
        for key in manifest["nodes"]
        if key.startswith("model")
        and "reports" in manifest["nodes"][key].get("tags", [])
        and (
            has_sensitive_facility
            or "restricted" not in manifest["nodes"][key].get("tags", [])
        )
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

        # Include language in filename (only add suffix if not default)
        lang_suffix = f"-{language}" if language != "default" else ""
        filename = f"{report['name']}-v{VERSION}-{DEPLOYMENT}{lang_suffix}.json"
        output_file = os.path.join(VERSION_DIR, filename)

        compile_report(report["database"], sql_file, config_file, output_file)
        cprint(f"Compiled report: {filename}", "success")


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
// Build-less images (Tamanu 2.60+) run the CLI from TS source via tsx and ship no dist/
// bundle; older images ship the bundled ./dist/app.bundle.js. Pick whichever is present.
const distBundle = "./dist/app.bundle.js";
const baseCommand = fs.existsSync(distBundle)
  ? `node ${distBundle} importReport`
  : "node --import tsx app importReport";

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


class ReportingSchemaDependencyError(Exception):
    """A model cannot be ordered into the reporting schema build script."""


def _describe_excluded_dependency(manifest, dep):
    """Say why a dependency is absent from the reporting schema.

    Args:
        manifest (dict): The parsed dbt manifest.
        dep (str): Unique ID of the dependency.

    Returns:
        str: A phrase naming the resource kind or the tag that keeps it out.
    """
    if dep.startswith("seed"):
        return (
            "a seed, and the reporting schema is dropped and rebuilt from views alone, so "
            "seed rows never reach a deployment -- hold them in a map__ model instead"
        )
    if dep.startswith("snapshot"):
        return "a snapshot, which the reporting schema does not create"

    tags = manifest["nodes"].get(dep, {}).get("tags", [])
    if "restricted" in tags:
        return 'tagged "restricted", which is excluded while has_sensitive_facility is false'
    for tag in ("reports", "internal"):
        if tag in tags:
            return f'tagged "{tag}", which is excluded from the reporting schema'
    return "not a model the reporting schema creates"


def _describe_stall(manifest, remaining, selectable):
    """Explain why the ordering stopped with models still unplaced.

    Args:
        manifest (dict): The parsed dbt manifest.
        remaining (list): Unique IDs of the models still unordered.
        selectable (set): Unique IDs of every model the reporting schema will create.

    Returns:
        str: A multi-line explanation naming each blocking model and dependency.
    """
    def name(node):
        return manifest["nodes"][node]["name"]

    blocked = {}
    for node in remaining:
        excluded = sorted(
            dep
            for dep in manifest["nodes"][node]["depends_on"]["nodes"]
            if not dep.startswith("source") and dep not in selectable
        )
        if excluded:
            blocked[node] = excluded

    if not blocked:
        return "Circular dependency between reporting schema models: " + ", ".join(
            sorted(name(node) for node in remaining)
        )

    lines = ["Models the reporting schema cannot create:"]
    for node in sorted(blocked, key=name):
        for dep in blocked[node]:
            lines.append(
                f"  {name(node)} depends on {dep}, which is "
                f"{_describe_excluded_dependency(manifest, dep)}"
            )

    waiting = sorted(set(remaining) - set(blocked), key=name)
    if waiting:
        lines.append("Blocked behind them: " + ", ".join(name(node) for node in waiting))
    return "\n".join(lines)


def order_models_for_schema(manifest, nodes):
    """Order models so each view is created after the views it selects from.

    Sources are left out of the ordering: they resolve to tables the deployment already
    has, under their own schema.

    Args:
        manifest (dict): The parsed dbt manifest.
        nodes (list): Unique IDs of the models the reporting schema will create.

    Returns:
        list: `nodes` in creation order.

    Raises:
        ReportingSchemaDependencyError: A model depends on something the reporting schema
            never creates, or the models form a cycle.
    """
    selectable = set(nodes)
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
            remaining = [node for node in nodes if node not in processed]
            raise ReportingSchemaDependencyError(
                _describe_stall(manifest, remaining, selectable)
            )

        for node in current:
            processed.add(node)
            ordered.append(node)

    return ordered


def generate_reporting_schema_script():
    """
    Generates a SQL script to create views in the reporting schema.

    The script is generated based on the model nodes that do not have the "reports" or
    "internal" tag and are compiled in the project. Dependencies between models are resolved
    before generating the views in the schema. Nodes tagged "internal" (e.g. the
    metric_definitions registry) are dbt-package-internal and never materialised into the
    deployable reporting schema. Nodes tagged "restricted" (i.e. sensitive-facility dataset
    views) are excluded when has_sensitive_facility is false. has_sensitive_facility is read
    from dbt_project.yml via get_dbt_project_vars(), not from the dbt runtime context.

    Returns:
        None: Writes the SQL schema build script to the views directory.
    """
    manifest_path = os.path.join(BASE_DIR, "target", "manifest.json")
    manifest = read_file(manifest_path, "json")

    project_vars = get_dbt_project_vars()
    has_sensitive_facility = project_vars.get("has_sensitive_facility", False)

    nodes = [
        key
        for key in manifest["nodes"]
        if key.startswith("model")
        and "reports" not in manifest["nodes"][key].get("tags", [])
        and "internal" not in manifest["nodes"][key].get("tags", [])
        and (
            has_sensitive_facility
            or "restricted" not in manifest["nodes"][key].get("tags", [])
        )
    ]

    if not nodes:
        cprint(f"No models found", "error")
        return

    ordered = order_models_for_schema(manifest, nodes)

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
        name = model.get("config", {}).get("alias") or model["name"]
        scripts.append(
            f'create or replace view "{SCHEMA}"."{name}" as (\n{cleaned_sql}\n);'
        )

    ensure_directory_exists(VERSION_DIR)
    output_file = os.path.join(
        VERSION_DIR, f"reporting-schema-v{VERSION}-{DEPLOYMENT}.sql"
    )
    write_file(output_file, "\n".join(scripts))
