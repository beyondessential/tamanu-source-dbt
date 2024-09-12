import json
import os
import argparse

compiled_dir = "../target/compiled/tamanu_source_dbt/models/"

DATABASE = "current_database()"
SCHEMA = "reporting"
ROLE = "tamanu_reporting"
manifest_filename = "../target/manifest.json"

def belongs_in_level(node_name, previous_level_nodes, manifest):
    depends_on = manifest["nodes"][node_name]["depends_on"]["nodes"]
    return all([(node.split(".")[0] == 'source') | (node in previous_level_nodes) for node in depends_on])

def build_view(file_name, sql, dbt_database, dbt_schema):
    sql = sql.replace(f'"{dbt_database}"."{dbt_schema}"', f'"{SCHEMA}"')
    sql = sql.replace(f'"{dbt_database}"."public"', f'"public"')
    table_name = file_name[:-4] 
    template = f'CREATE OR REPLACE VIEW "{SCHEMA}"."{table_name}" AS (\n{sql});\n'
    return template   

def view_from_model(model_name, dbt_database, dbt_schema, manifest):
    path = manifest["nodes"][model_name]["path"]
    file_name = path.split("\\")[-1]
    with open(os.path.join(compiled_dir, path), "r") as f:
        sql = f.read()
    return build_view(file_name, sql, dbt_database, dbt_schema)

def generate_build_script(dbt_database, dbt_schema, file):
    with open(manifest_filename, "r") as f:
        manifest = json.loads(f.read())

    models = [m for m in manifest["nodes"].keys() if m.split(".")[0] == 'model']

    levels = []
    processed_nodes = []
    while len(processed_nodes) < len(models):
        this_level_nodes = [node for node in models if belongs_in_level(node, processed_nodes, manifest) & (node not in processed_nodes)]
        processed_nodes += this_level_nodes
        levels.append(this_level_nodes)

    scripts = [f"CREATE SCHEMA IF NOT EXISTS {SCHEMA};\n",
               f"ALTER DEFAULT PRIVILEGES IN SCHEMA {SCHEMA} GRANT SELECT ON TABLES TO {ROLE};\n"]
    for i in range(len(levels)):
        scripts += [view_from_model(model, dbt_database, dbt_schema, manifest) for model in levels[i]]

    with open(file, "w") as f:
        f.write("\n".join(scripts))

if __name__=="__main__":
    parser = argparse.ArgumentParser(description='Generate the build script for deployment with database: tamanu_sync and schema: reporting')
    parser.add_argument('-d', '--dbt_database', default='tamanu_sync', help='database of dbt models (defaults to tamanu_sync)')
    parser.add_argument('-s', '--dbt_schema', default='reporting', help='schema of dbt models (defaults to public)')
    parser.add_argument('-f', '--file', default='reporting_schema_build_script.sql', help='output file of the script for deployment (defaults to reporting_schema_build_script.sql)')
    args = parser.parse_args()
    generate_build_script(dbt_database=args.dbt_database, dbt_schema=args.dbt_schema, file=args.file)