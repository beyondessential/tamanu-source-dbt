const path = require("path");
const { get_deployment_version } = require("./dbt_utils");
const {
  read_file,
  write_file,
  ensure_directory_exists,
} = require("./file_utils");

const SCHEMA = "reporting";
const ROLE = "reporting";
const BASE_DIR = path.resolve(__dirname, "../..");
const REPORTS_DIR = path.resolve(BASE_DIR, "compiled", "reports");
const VIEWS_DIR = path.resolve(BASE_DIR, "compiled", "views");

/**
 * Compiles a report by reading a SQL file and its associated configuration,
 * modifying the configuration, and then writing the result to an output file.
 *
 * @param {string} database - The database name used to replace in the SQL query.
 * @param {string} sql_file - The path to the SQL file to read.
 * @param {string} config_file - The path to the JSON configuration file.
 * @param {string} output_file - The path where the compiled report will be written.
 */
function compile_report(database, sql_file, config_file, output_file) {
  try {
    const sql = read_file(sql_file);
    const json = read_file(config_file, "json");

    json.query = sql
      .replace(/\r?\n\s+/g, "\n")
      .replace(new RegExp(`"${database}".`, "g"), "");

    json.db_schema = SCHEMA;
    write_file(output_file, json, "json");
  } catch (err) {
    console.error(`Error processing files: ${err.message}`);
    process.exit(1);
  }
}

/**
 * Generates project reports based on a target tag and a manifest file.
 * It filters models in the manifest, compiles reports for matching models,
 * and writes them to a specific directory.
 *
 * @param {string} target - The target tag used to filter models.
 */
function generate_project_reports(target) {
  const manifest = read_file(
    path.join(BASE_DIR, "target", "manifest.json"),
    "json"
  );
  const nodes = Object.keys(manifest.nodes).filter(
    (key) =>
      key.startsWith("model") &&
      manifest.nodes[key].tags &&
      manifest.nodes[key].tags.includes("reports") &&
      manifest.nodes[key].tags.includes(target)
  );

  if (nodes.length === 0) {
    console.warn(`No report models found for target: ${target}`);
    return;
  }

  ensure_directory_exists(REPORTS_DIR);

  for (const node of nodes) {
    const report = manifest.nodes[node];
    const sql_file = path.join(BASE_DIR, report.compiled_path);
    const config_file = path
      .join(BASE_DIR, report.original_file_path)
      .replace(".sql", ".json")
      .replace("sql", "config");
    const output_file = path.join(REPORTS_DIR, `${report.name}.json`);

    compile_report(report.database, sql_file, config_file, output_file);
    console.log(`Compiled report: ${report.name}.sql`);
  }
}

/**
 * Generates the import reports script to process the compiled reports.
 * This script will execute the import commands for each report JSON file.
 */
function generate_import_report_script() {
  const script_content = `const fs = require("fs");
  const path = require("path");
  const { exec } = require("child_process");
  const { readFile } = require("fs/promises");

  const folderPath = path.resolve(".");
  const baseCommand = "node ./dist/app.bundle.js importReport";

  fs.readdir(folderPath, async (err, files) => {
    if (err) {
      console.error(\`Error reading directory: \${err.message}\`);
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
        const fileContent = await readFile(filePath, "utf-8");
        const json = JSON.parse(fileContent);
        const reportName = json.name;

        const command = \`\${baseCommand} -n '\${reportName}' -f "\${filePath}"\`;

        console.log(\`Executing command: \${command}\`);

        exec(command, (err, stdout, stderr) => {
          if (err) {
            console.error(\`Error executing command for file \${file}: \${err.message}\`);
            return;
          }

          if (stderr) {
            console.error(\`Error output for file \${file}: \${stderr}\`);
            return;
          }

          console.log(\`Success for file \${file}: \${stdout}\`);
        });
      } catch (err) {
        console.error(\`Error processing file \${file}: \${err.message}\`);
      }
    }
  });`;

  ensure_directory_exists(REPORTS_DIR);

  const output_path = path.join(REPORTS_DIR, "import_reports.js");

  try {
    write_file(output_path, script_content);
    console.log(`Script created successfully at: ${output_path}`);
  } catch (err) {
    console.error(`Failed to write the script file: ${err.message}`);
  }
}

/**
 * Generates a reporting schema script by compiling models in the targeted project.
 * It orders models based on their dependencies, and writes a script to create or replace views.
 *
 * @param {string} target - The target tag used to filter models.
 */
function generate_reporting_schema_script(target) {
  const manifest = read_file(
    path.join(BASE_DIR, "target", "manifest.json"),
    "json"
  );
  const nodes = Object.keys(manifest.nodes).filter(
    (key) =>
      key.startsWith("model") &&
      manifest.nodes[key].tags &&
      !manifest.nodes[key].tags.includes("reports")
  );

  if (nodes.length === 0) {
    console.warn(`No models found with the target: ${target}`);
    return;
  }

  let processedNodes = new Set();
  let orderedNodes = [];

  while (processedNodes.size < nodes.length) {
    let currentLevel = nodes.filter((node) => {
      let dependencies = manifest.nodes[node].depends_on.nodes || [];
      return dependencies.every(
        (dep) => dep.startsWith("source") || processedNodes.has(dep)
      );
    });

    if (currentLevel.length === 0) {
      console.error(
        "Error: Circular dependency detected or missing dependencies."
      );
      process.exit(1);
    }

    currentLevel.forEach((node) => {
      processedNodes.add(node);
      orderedNodes.push(node);
    });
  }

  const scripts = [
    `drop schema if exists ${SCHEMA} cascade;`,
    `create schema ${SCHEMA};`,
    `alter default privileges in schema ${SCHEMA} grant select on tables to ${ROLE};`,
  ];

  orderedNodes.forEach((node) => {
    const model = manifest.nodes[node];
    const compiled_path = path.join(BASE_DIR, model.compiled_path);
    const sql = read_file(compiled_path).replace(
      new RegExp(`"${model.database}"\\.`, "g"),
      ``
    );

    scripts.push(
      `create or replace view "${SCHEMA}"."${model.name}" as (\n${sql}\n);`
    );
  });

  ensure_directory_exists(VIEWS_DIR);
  write_file(
    path.join(
      VIEWS_DIR,
      `reporting_schema_build_script_v${get_deployment_version()}.sql`
    ),
    scripts.join("\n")
  );
}

module.exports = {
  compile_report,
  generate_project_reports,
  generate_import_report_script,
  generate_reporting_schema_script,
};
