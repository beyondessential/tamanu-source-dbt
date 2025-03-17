const path = require("path");
const os = require("os");

const { execute_command } = require("./utils/system_utils");
const { get_deployment_version } = require("./utils/dbt_utils");
const {
  copy_files_from_directory,
  remove_directory,
} = require("./utils/file_utils");

const REPO_URL = "https://github.com/beyondessential/tamanu.git";

const BASE_DIR = path.resolve(__dirname, "..");
const TEMP_DIR = path.join(os.tmpdir(), "tamanu");
const DBT_SOURCE_DIR = path.join(BASE_DIR, "models", "sources");
const REPO_SOURCE_DIR = path.join(
  TEMP_DIR,
  "database",
  "model",
  "central-server",
  "public"
);

function main() {
  const version = get_deployment_version();
  const branchName = `release/${version.split(".").slice(0, 2).join(".")}`;
  console.log(`Detected version: ${version}`);
  console.log(`Cloning branch '${branchName}' from repository '${REPO_URL}'`);
  execute_command(
    `git clone --branch ${branchName} --depth 1 ${REPO_URL} ${TEMP_DIR}`
  );

  console.log("Copying database folder...");
  copy_files_from_directory(REPO_SOURCE_DIR, DBT_SOURCE_DIR);

  console.log("Files copied successfully! Cleaning up...");
  remove_directory(TEMP_DIR);

  console.log("Cleanup complete.");
}

if (require.main === module) {
  try {
    main();
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
}
