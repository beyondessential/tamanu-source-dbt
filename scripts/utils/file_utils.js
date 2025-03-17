const fs = require("fs");

/**
 * Ensures that a file exists at the specified path. If the file does not exist, the process is terminated.
 *
 * @param {string} file_path - The path to the file to check for existence.
 */
function ensure_file_exists(file_path) {
  if (!fs.existsSync(file_path)) {
    console.error(`Error: File not found: ${file_path}`);
    process.exit(1);
  }
}

/**
 * Reads a file from the specified path and returns its contents. If the file is of type 'json', it will be parsed.
 *
 * @param {string} file_path - The path to the file to read.
 * @param {string} [type="text"] - The type of file being read, either 'text' or 'json'. Defaults to 'text'.
 * @returns {string|object} - Returns the file contents as a string (for text files) or a parsed object (for JSON files).
 */
function read_file(file_path, type = "text") {
  try {
    ensure_file_exists(file_path);
    const data = fs.readFileSync(file_path, "utf-8");
    return type === "json" ? JSON.parse(data) : data;
  } catch (err) {
    console.error(`Error reading file ${file_path}: ${err.message}`);
    process.exit(1);
  }
}

/**
 * Writes data to a file at the specified path. The data is written either as text or JSON based on the specified type.
 *
 * @param {string} file_path - The path to the file where the data will be written.
 * @param {string|object} data - The data to write to the file, either as a string or as an object.
 * @param {string} [type="text"] - The type of file being written, either 'text' or 'json'. Defaults to 'text'.
 */
function write_file(file_path, data, type = "text") {
  try {
    let content;
    if (type === "json") {
      content = JSON.stringify(data, null, 2);
    } else if (type === "text") {
      content = data;
    } else {
      throw new Error(`Unsupported file type: ${type}`);
    }
    fs.writeFileSync(file_path, content, "utf-8");
  } catch (err) {
    console.error(`Error writing file ${file_path}: ${err.message}`);
    process.exit(1);
  }
}

/**
 * Ensures that a directory exists at the specified path. If the directory does not exist, it will be created.
 *
 * @param {string} dir_path - The path to the directory to check/create.
 */
function ensure_directory_exists(dir_path) {
  if (!fs.existsSync(dir_path)) {
    fs.mkdirSync(dir_path, { recursive: true });
  }
}

/**
 * Copies all files from one folder to another.
 *
 * @param {string} sourceDir - The path to the source directory.
 * @param {string} destinationDir - The path to the destination directory.
 */
function copy_files_from_directory(sourceDir, destinationDir) {
  try {
    const files = fs.readdirSync(sourceDir);
    files.forEach((file) => {
      const sourceFilePath = `${sourceDir}/${file}`;
      const destFilePath = `${destinationDir}/${file}`;
      if (fs.statSync(sourceFilePath).isFile()) {
        fs.copyFileSync(sourceFilePath, destFilePath);
        console.log(`File copied from ${sourceFilePath} to ${destFilePath}`);
      }
    });
  } catch (err) {
    console.error(
      `Error copying files from ${sourceDir} to ${destinationDir}: ${err.message}`
    );
    process.exit(1);
  }
}

/**
 * Removes a directory and all its contents.
 *
 * @param {string} dirPath - The path to the directory to be removed.
 */
function remove_directory(dirPath) {
  try {
    if (fs.existsSync(dirPath)) {
      fs.rmSync(dirPath, { recursive: true, force: true });
      console.log(
        `Directory ${dirPath} and all its contents have been removed.`
      );
    } else {
      console.error(`Error: Directory not found: ${dirPath}`);
    }
  } catch (err) {
    console.error(`Error removing directory ${dirPath}: ${err.message}`);
    process.exit(1);
  }
}

module.exports = {
  read_file,
  write_file,
  remove_directory,
  ensure_file_exists,
  ensure_directory_exists,
  copy_files_from_directory,
};
