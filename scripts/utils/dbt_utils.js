const { write_file, read_file } = require("./file_utils");
const path = require("path");

const BASE_DIR = path.resolve(__dirname, "../..");

/**
 * Hides macros from the documentation in the provided manifest file.
 * It sets the 'show' flag to false for all macros in the manifest.
 */
function hide_macros_from_docs() {
  manifest_path = path.join(BASE_DIR, "target", "manifest.json");
  const manifest = read_file(manifest_path, "json");

  const macros = Object.keys(manifest.macros).filter((key) =>
    key.startsWith("macro")
  );

  // If no macros are found, warn and return
  if (macros.length === 0) {
    console.warn(`No macros found.`);
    return;
  }

  // Hide each macro from the documentation
  macros.forEach((macro) => {
    manifest.macros[macro].docs = manifest.macros[macro].docs || {};
    manifest.macros[macro].docs.show = false;
  });

  write_file(manifest_path, manifest, "json");
}

/**
 * Hides tests from the documentation in the provided manifest file.
 * It sets the 'show' flag to false for all tests in the manifest.
 */
function hide_tests_from_docs() {
  const manifest = read_file(
    path.join(BASE_DIR, "target", "manifest.json"),
    "json"
  );
  const tests = Object.keys(manifest.nodes).filter((key) =>
    key.startsWith("test")
  );

  // If no tests are found, warn and return
  if (tests.length === 0) {
    console.warn(`No tests found.`);
    return;
  }

  // Hide each test from the documentation
  tests.forEach((test) => {
    manifest.nodes[test].docs = manifest.nodes[test].docs || {};
    manifest.nodes[test].docs.show = false;
  });

  write_file(manifest_path, manifest, "json");
}

/**
 * Retrieves the deployment version from the 'dbt_project.yml' file.
 *
 * @returns {string} - The version string from the dbt_project.yml file.
 * @throws {Error} - If there is an error reading the 'dbt_project.yml' file.
 */
const get_deployment_version = () => {
  try {
    const configPath = path.join(BASE_DIR, "dbt_project.yml");
    const fileContents = read_file(configPath, "utf8");

    const versionLine = fileContents.match(/^version:\s*(.*)$/m);
    if (versionLine && versionLine[1]) {
      return versionLine[1].trim().replace(/['"]/g, "");
    }
    throw new Error("Version not found in dbt_project.yml");
  } catch (error) {
    console.error("Error reading dbt_project.yml:", error);
    process.exit(1);
  }
};

module.exports = {
  hide_macros_from_docs,
  hide_tests_from_docs,
  get_deployment_version,
};
