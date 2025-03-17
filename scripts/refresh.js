const simpleGit = require("simple-git");
const fs = require("fs-extra");
const path = require("path");
const os = require("os");
const { exec } = require("child_process");
const yaml = require("yaml");

const repoUrl = "https://github.com/beyondessential/tamanu.git";

const project = path.resolve(__dirname, "..");
const config = path.join(project, "dbt_project.yml");
const destination = path.join(project, "models", "sources");

const inMemoryRepository = path.join(os.tmpdir(), "tamanu-repository");

const runCommand = (command, cwd = process.cwd()) => {
  return new Promise((resolve, reject) => {
    exec(command, { cwd }, (error, stdout, stderr) => {
      if (error) {
        console.error(`Error executing ${command}:`, stderr);
        reject(error);
      } else {
        resolve(stdout);
      }
    });
  });
};

const getVersion = () => {
  try {
    const dbtConfig = fs.readFileSync(config, "utf8");
    const parsedYAML = yaml.parse(dbtConfig);
    return parsedYAML.version; // Ensure `version` exists in dbt_project.yml
  } catch (error) {
    console.error("Error reading dbt_project.yml:", error);
    process.exit(1);
  }
};

// Clone specific branch, copy files, and cleanup
(async () => {
  try {
    const version = getVersio();
    const branchName = `release/${version}`;
    console.log(`Detected version: ${version}`);
    console.log(`Cloning branch '${branchName}'...`);

    await runCommand(
      `git clone --branch ${branchName} --depth 1 ${repoUrl} ${inMemoryRepository}`
    );

    const sourceFolder = path.join(inMemoryRepository, "database");

    // Check if source folder exists
    if (!fs.existsSync(sourceFolder)) {
      throw new Error(
        `Source folder "${sourceFolder}" does not exist in the repository.`
      );
    }

    console.log("Copying database folder...");
    await fs.copy(sourceFolder, destination, { overwrite: true });

    console.log("Files copied successfully! Cleaning up...");

    // Remove the cloned repo
    await fs.remove(inMemoryRepository);
    console.log("Cleanup complete.");
  } catch (error) {
    console.error("Error:", error);
  }
})();
