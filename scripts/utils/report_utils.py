import os
import re
import json
from pathlib import Path

from .dbt_utils import (
    get_deployment_name,
    get_deployment_version,
    get_project_name,
    get_dbt_project_vars,
)
from .file_utils import ensure_directory_exists, read_file, write_file
from .system_utils import cprint

SCHEMA = "reporting"
ROLE = "reporting"
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
        output_file = os.path.join(
            VERSION_DIR, f"{report['name']}-v{VERSION}-{DEPLOYMENT}.json"
        )

        compile_report(report["database"], sql_file, config_file, output_file)
        cprint(
            f"Compiled report: {report['name']}-v{VERSION}-{DEPLOYMENT}.json", "success"
        )


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


def _get_report_nodes(manifest):
    """Get all report nodes from the manifest."""
    return [
        key
        for key in manifest["nodes"]
        if key.startswith("model")
        and "reports" in manifest["nodes"][key].get("tags", [])
    ]


def _get_config_file_path(report):
    """Get the config file path for a report."""
    base_path = DBT_PACKAGE_DIR if report["package_name"] != PROJECT_NAME else BASE_DIR
    return os.path.join(base_path, report["original_file_path"]).replace(".sql", ".json").replace("sql", "config")


def _process_sql_for_language(sql, language):
    """Process SQL content to inject language parameters into translation calls."""
    if language == "default":
        return sql
    
    # Apply translation call processing for each function type
    patterns = [
        r'"([^"]*translate_label\([^)]+)\)"',
        r'"([^"]*translate_value\([^)]+)\)"',
        r'"([^"]*translate_column_value\([^)]+)\)"'
    ]
    
    processed_sql = sql
    for pattern in patterns:
        processed_sql = re.sub(
            pattern,
            lambda m: f'"{process_translation_call(m.group(1), language)}"',
            processed_sql,
        )
    
    return processed_sql


def _create_language_config(base_config, base_name, language):
    """Create language-specific configuration."""
    config = base_config.copy()
    if language != "default":
        config["name"] = f"{config.get('name', base_name)} ({language.upper()})"
    return config


def _finalize_report_config(config, sql_content, database):
    """Finalize the report configuration with processed SQL."""
    query = re.sub(r"\r?\n\s+", "\n", sql_content)
    config["query"] = re.sub(f'"{database}"\\.', "", query)
    version = ".".join(VERSION.split(".")[:2])
    config["tamanuVersion"] = f"~{version}.0"
    return config


def generate_multilingual_reports():
    """Generate multilingual reports directly from compiled base reports."""
    languages = get_dbt_project_vars("languages") or ["default"]
    if len(languages) == 1:
        return

    ensure_directory_exists(VERSION_DIR)
    
    manifest_path = os.path.join(BASE_DIR, "target", "manifest.json")
    manifest = read_file(manifest_path, "json")
    report_nodes = _get_report_nodes(manifest)

    for node in report_nodes:
        report = manifest["nodes"][node]
        base_name = report["name"]
        
        sql_file = os.path.join(BASE_DIR, report["compiled_path"])
        config_file = _get_config_file_path(report)
        
        if not os.path.exists(sql_file) or not os.path.exists(config_file):
            continue
            
        base_sql = read_file(sql_file)
        base_config = read_file(config_file, "json")

        for language in languages:
            sql_content = _process_sql_for_language(base_sql, language)
            config = _create_language_config(base_config, base_name, language)
            config = _finalize_report_config(config, sql_content, report["database"])

            lang_suffix = "" if language == "default" else f"_{language}"
            output_name = f"{base_name}{lang_suffix}-v{VERSION}-{DEPLOYMENT}.json"
            write_file(os.path.join(VERSION_DIR, output_name), config, "json")

            cprint(f"Generated multilingual report: {output_name}", "success")


def process_translation_call(call_text, language):
    """Process a translation function call to add language parameter."""
    # Handle translate_label calls
    if "translate_label(" in call_text:
        # Replace translate_label('key') with translate_label('key', 'language')
        call_text = re.sub(
            r"translate_label\('([^']+)'\)",
            f"translate_label('\\1', '{language}')",
            call_text,
        )
    
    # Handle translate_value calls
    if "translate_value(" in call_text:
        # Replace translate_value('key', value) with translate_value('key', value, 'language')
        call_text = re.sub(
            r"translate_value\('([^']+)',\s*([^)]+)\)",
            f"translate_value('\\1', \\2, '{language}')",
            call_text,
        )
    
    # Handle translate_column_value calls
    if "translate_column_value(" in call_text:
        # Replace translate_column_value('key', value) with translate_column_value('key', value, 'language')
        call_text = re.sub(
            r"translate_column_value\('([^']+)',\s*([^)]+)\)",
            f"translate_column_value('\\1', \\2, '{language}')",
            call_text,
        )
    
    return call_text
