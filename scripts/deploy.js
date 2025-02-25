const { readFile, writeFile } = require("node:fs/promises");
const { execSync } = require("child_process");
const path = require("path");
const fs = require("fs");
const { Console } = require("node:console");

const SCHEMA = "reporting";
const ROLE = "reporting";
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
      .replace(new RegExp(`"${modelDatabase}".`, "g"), "");
    json.dbSchema = SCHEMA;
    await writeFile(outputFile, JSON.stringify(json, null, 2), "utf-8");
  } catch (err) {
    console.error(`Error processing files: ${err.message}`);
    process.exit(1);
  }
}

function executeCommand(command) {
  try {
    console.log(`\nRunning: ${command}\n`);
    execSync(command, { stdio: "inherit", shell: true });
  } catch (err) {
    console.error(`Error while running command: ${command}`);
    console.error(err.message);
    process.exit(1);
  }
}

function ensureFileExists(filePath) {
  if (!fs.existsSync(filePath)) {
    console.error(`Error: File not found: ${filePath}`);
    process.exit(1);
  }
}

function ensureDirectoryExists(dirPath) {
  if (!fs.existsSync(dirPath)) {
    fs.mkdirSync(dirPath, { recursive: true });
  }
}

function parseManifest() {
  ensureFileExists(MANIFEST_PATH);
  return JSON.parse(fs.readFileSync(MANIFEST_PATH, "utf-8"));
}

function generateProjectDatasets(target) {
  const manifest = parseManifest();
  const models = Object.keys(manifest.nodes).filter(
    (key) =>
      key.startsWith("model") &&
      manifest.nodes[key].tags &&
      !manifest.nodes[key].tags.includes("reports")
  );

  if (models.length === 0) {
    console.warn(`No models found with the target: ${target}`);
    return;
  }

  let processedNodes = new Set();
  let orderedModels = [];

  while (processedNodes.size < models.length) {
    let currentLevel = models.filter((model) => {
      let dependencies = manifest.nodes[model].depends_on.nodes || [];
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

    currentLevel.forEach((model) => {
      processedNodes.add(model);
      orderedModels.push(model);
    });
  }

  const scripts = [
    `drop schema if exists ${SCHEMA} cascade;`,
    `create schema ${SCHEMA};`,
    `alter default privileges in schema ${SCHEMA} grant select on tables to ${ROLE};`,
  ];

  orderedModels.forEach((model) => {
    const modelPath = manifest.nodes[model].path;
    const compiledModelPath = path.join(COMPILED_MODELS_DIR, modelPath);
    if (fs.existsSync(compiledModelPath)) {
      const sql = fs
        .readFileSync(compiledModelPath, "utf-8")
        .replace(new RegExp(`"${manifest.nodes[model].database}"\\.`, "g"), ``);
      scripts.push(
        `create or replace view "${SCHEMA}"."${path.basename(
          modelPath,
          path.extname(modelPath)
        )}" as (\n${sql}\n);`
      );
    } else {
      console.warn(`Model file not found: ${compiledModelPath}`);
    }
  });

  ensureDirectoryExists(VIEWS_DIR);
  fs.writeFileSync(
    path.join(VIEWS_DIR, "reporting_schema_build_script.sql"),
    scripts.join("\n")
  );
}

async function generateProjectReports(target) {
  const manifest = parseManifest();

  const reportModels = Object.keys(manifest.nodes).filter(
    (key) =>
      key.startsWith("model") &&
      manifest.nodes[key].tags &&
      manifest.nodes[key].tags.includes("reports") &&
      manifest.nodes[key].tags.includes(target)
  );

  if (reportModels.length === 0) {
    console.warn(`No report models found for target: ${target}`);
    return;
  }

  ensureDirectoryExists(REPORTS_DIR);

  for (const model of reportModels) {
    const modelPath = manifest.nodes[model].path;
    const compiledModelPath = path.join(COMPILED_MODELS_DIR, modelPath);
    if (fs.existsSync(compiledModelPath)) {
      const configFilePath = compiledModelPath
        .replace(
          path.join("..", "target", "compiled", "tamanu_source_dbt", "models"),
          path.join("..", "models")
        )
        .replace(".sql", ".json")
        .replace("sql", "config");
      const outputFilePath = path.join(
        REPORTS_DIR,
        `${path.basename(modelPath, ".sql")}.json`
      );
      await compileReport(
        manifest.nodes[model].database,
        compiledModelPath,
        configFilePath,
        outputFilePath
      );
      console.log(`Compiled report: ${path.basename(modelPath, ".sql")}`);
    } else {
      console.warn(`Compiled model file not found: ${compiledModelPath}`);
    }
  }
}

function generateImportReportScript() {
  const scriptContent = `const fs = require("fs");
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

  ensureDirectoryExists(REPORTS_DIR);
  const outputPath = path.join(REPORTS_DIR, "importReports.js");

  try {
    fs.writeFileSync(outputPath, scriptContent, "utf8");
    console.log(`Script created successfully at: ${outputPath}`);
  } catch (err) {
    console.error(`Failed to write the script file: ${err.message}`);
  }
}

async function main() {
  const args = process.argv.slice(2);
  const targetIndex = args.indexOf("--target") + 1;
  const target = targetIndex > 0 ? args[targetIndex] : "demoland";

  console.log(`Generating build script for target: ${target}`);
  executeCommand("dbt clean");
  executeCommand("dbt deps");
  executeCommand(`dbt run --target ${target} --select tag:${target}`);
  executeCommand(`dbt compile --target ${target} --select tag:${target}`);

  generateProjectDatasets(target);
  await generateProjectReports(target);
  generateImportReportScript();
}

if (require.main === module) {
  main().catch((err) => {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  });
}
