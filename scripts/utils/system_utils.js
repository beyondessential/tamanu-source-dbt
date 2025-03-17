const { execSync } = require("child_process");

/**
 * Executes a shell command synchronously and prints the command output to the console.
 * If the command fails, the process exits with an error message.
 *
 * @param {string} command - The shell command to execute.
 */
function execute_command(command) {
  try {
    console.log(`\nRunning: ${command}\n`);
    execSync(command, { stdio: "inherit", shell: true });
  } catch (err) {
    console.error(`Error while running command: ${command}`);
    process.exit(1);
  }
}

module.exports = {
  execute_command,
};
