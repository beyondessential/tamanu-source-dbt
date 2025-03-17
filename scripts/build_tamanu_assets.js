const {
  generate_project_reports,
  generate_import_report_script,
  generate_reporting_schema_script,
} = require("./utils/report_utils");

const {
  hide_macros_from_docs,
  hide_tests_from_docs,
} = require("./utils/dbt_utils");

const { execute_command } = require("./utils/system_utils");

function main() {
  const args = process.argv.slice(2);
  const targetIndex = args.indexOf("--target") + 1;
  const target = targetIndex > 0 ? args[targetIndex] : "demoland";

  console.log(`Generating build script for target: ${target}`);
  execute_command("dbt clean");
  execute_command("dbt deps");
  execute_command(`dbt run --target ${target} --select tag:${target}`);
  execute_command(`dbt compile --target ${target} --select tag:${target}`);
  execute_command(
    `dbt docs generate --target ${target} --select tag:${target}`
  );

  hide_macros_from_docs();
  hide_tests_from_docs();
  generate_reporting_schema_script(target);
  generate_project_reports(target);
  generate_import_report_script();
}

if (require.main === module) {
  try {
    main();
  } catch (err) {
    console.error(`Error: ${err.message}`);
    process.exit(1);
  }
}
