const { readFile, writeFile } = require("node:fs/promises");
const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");

const SCHEMA = "reporting";
const ROLE = "tamanu_reporting";
const MANIFEST_PATH = "../target/manifest.json";
const COMPILED_MODELS_DIR = "../target/compiled/tamanu_source_dbt/models/";
const VIEWS_DIR = "../compiled/views";
const REPORTS_DIR = "../compiled/reports";

async function compileReport(modelDatabase, sqlFile, configFile, outputFile) {
  try {
    const sql = await readFile(sqlFile, "utf-8");
    const json = JSON.parse(await readFile(configFile, "utf-8"));
    json.query = sql
      .replace(/\r?\n\s+/g, "\n")
      .replace(new RegExp(`"${modelDatabase}".`, "g"), ``);
    json.dbSchema = SCHEMA;
    await writeFile(outputFile, JSON.stringify(json, null, 2), "utf-8");
  } catch (err) {
    console.error(`Error processing files: ${err.message}`);
    process.exit(1);
  }
}

function executeCommand(command) {
  /** Run a command synchronously and print output in real time.*/
  try {
    console.log(`\nRunning: ${command}\n`);
    const output = execSync(command, { stdio: "inherit", shell: true });
  } catch (error) {
    console.error(`Error while running command: ${command}`);
    console.error(error.message);
    process.exit(1);
  }
}

function fileExists(filePath) {
  /** Check if a file exists. */
  if (!fs.existsSync(filePath)) {
    console.error(`Error: File not found: ${filePath}`);
    process.exit(1);
  }
}

function createDirectory(dir) {
  /** Create the directory if it doesn't exist. */
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function generateProjectDatasets(target) {
  fileExists(MANIFEST_PATH);

  const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf-8"));

  // Step 1: Identify models
  const models = Object.keys(manifest.nodes).filter(
    (model) =>
      model.startsWith("model") &&
      manifest.nodes[model].tags &&
      !manifest.nodes[model].tags.includes("reports")
  );

  if (models.length === 0) {
    console.warn(`No models with the ${target} tag found.`);
    return;
  }

  // Step 2: Include upstream dependencies of tagged models
  const modelsToProcess = new Set(models);

  models.forEach((model) => {
    const stack = [...manifest.nodes[model].depends_on.nodes];
    while (stack.length) {
      const dependency = stack.pop();
      if (!modelsToProcess.has(dependency) && dependency.startsWith("model")) {
        modelsToProcess.add(dependency);
        stack.push(...(manifest.nodes[dependency].depends_on.nodes || []));
      }
    }
  });

  // Step 3: Topologically sort models to process
  const sortedModels = [];
  const processedModels = new Set();

  while (processedModels.size < modelsToProcess.size) {
    const readyToProcess = Array.from(modelsToProcess).filter(
      (model) =>
        !processedModels.has(model) &&
        (manifest.nodes[model].depends_on.nodes || []).every(
          (dep) => dep.startsWith("source") || processedModels.has(dep)
        )
    );

    readyToProcess.forEach((model) => {
      sortedModels.push(model);
      processedModels.add(model);
    });
  }

  // Step 4: Generate SQL scripts
  const scripts = [
    `CREATE SCHEMA IF NOT EXISTS ${SCHEMA};`,
    `ALTER DEFAULT PRIVILEGES IN SCHEMA ${SCHEMA} GRANT SELECT ON TABLES TO ${ROLE};`,
  ];

  sortedModels.forEach((model) => {
    const modelPath = manifest.nodes[model].path;
    const modelDatabase = manifest.nodes[model].database;
    const viewName = path.basename(modelPath, path.extname(modelPath));
    const compiledModelPath = path.join(COMPILED_MODELS_DIR, modelPath);

    if (fs.existsSync(compiledModelPath)) {
      const sql = fs
        .readFileSync(compiledModelPath, "utf-8")
        .replace(new RegExp(`"${modelDatabase}"\\.public`, "g"), `"public"`);
      scripts.push(
        `CREATE OR REPLACE VIEW "${SCHEMA}"."${viewName}" AS (\n${sql}\n);`
      );
    } else {
      console.warn(`Warning: Model file ${compiledModelPath} not found.`);
    }
  });

  // Step 5: Write output to a file
  createDirectory(VIEWS_DIR);
  const outputFilename = path.join(VIEWS_DIR, `datasets.sql`);

  fs.writeFileSync(outputFilename, scripts.join("\n"));
}

function generateProjectReports(target) {
  fileExists(MANIFEST_PATH);

  const manifest = JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf-8"));

  const reportModels = Object.keys(manifest.nodes).filter(
    (model) =>
      model.startsWith("model") &&
      manifest.nodes[model].tags &&
      manifest.nodes[model].tags.includes("reports") &&
      manifest.nodes[model].tags.includes(target)
  );

  if (reportModels.length === 0) {
    console.warn(`No models with the ${target} tag found.`);
    return;
  }

  try {
    createDirectory(REPORTS_DIR);
    reportModels.forEach(async (model) => {
      const modelPath = manifest.nodes[model].path;
      const modelDatabase = manifest.nodes[model].database;
      const reportName = path.basename(modelPath, path.extname(modelPath));
      const compiledModelPath = path.join(COMPILED_MODELS_DIR, modelPath);

      if (fs.existsSync(compiledModelPath)) {
        const sqlFile = compiledModelPath;
        const configFile = compiledModelPath
          .replace("../target/compiled/tamanu_source_dbt/models", "../models")
          .replace(".sql", ".json")
          .replace("sql", "config");
        const outputFile = path.join(REPORTS_DIR, `${reportName}.json`);
        await compileReport(modelDatabase, sqlFile, configFile, outputFile);
        console.log(`${reportName} compiled successfully.`);
      } else {
        console.warn(`Warning: Model file ${compiledModelPath} not found.`);
      }
    });
  } catch (err) {
    console.error(`Error processing report: ${err.message}`);
    process.exit(1);
  }
}

function generateImportReportScript(target) {
  const scriptContent = `const fs = require('fs');
const path = require('path');
const { exec } = require('child_process');

const folderPath = '..\\\\';

const baseCommand = 'node .\\\\dist\\\\app.bundle.js importReport';

fs.readdir(folderPath, (err, files) => {
  if (err) {
    console.error(\`Error reading directory: \${err.message}\`);
    return;
  }

  const jsonFiles = files.filter(file => file.endsWith('.json'));

  if (jsonFiles.length === 0) {
    console.log('No JSON files found in the folder.');
    return;
  }

  jsonFiles.forEach(file => {
    const filePath = path.join(folderPath, file);
    const json = JSON.parse(await readFile(filePath, "utf-8"));
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
  });
});`;

  createDirectory(REPORTS_DIR);
  const outputPath = path.join(REPORTS_DIR, "importReports.js");

  fs.writeFile(outputPath, scriptContent, "utf8", (err) => {
    if (err) {
      console.error(`Failed to write the script file: ${err.message}`);
      return;
    }
    console.log(`Script created successfully at: ${outputPath}`);
  });
}

async function main() {
  const args = process.argv.slice(2);
  const targetArgIndex =
    args.indexOf("--target") !== -1 ? args.indexOf("--target") + 1 : -1;
  const target = targetArgIndex !== -1 ? args[targetArgIndex] : "demoland";

  console.log(`Generating build script for ${target}`);
  executeCommand("dbt clean");
  executeCommand("dbt deps");
  executeCommand(`dbt compile --target ${target} --select tag:${target}`);
  generateProjectDatasets(target);
  generateProjectReports(target);
  generateImportReportScript(target);
}

if (require.main === module) {
  main();
}
