# Tamanu standard models

A dbt project of Tamanu's standard models. This includes:

- raw (or source) schema
- reporting schema
- analytics schema (upcoming)

## SQL linting

We use SQLFluff and the configuration file is located in the root folder and is named `.sqlfluff`.

There are two commands available to run:

- `sqlfluff lint models` - Lints the file (does not apply fix)
- `sqlfluff fix models` - Fixes the SQL files

## Refresh Tamanu source models
To refresh the source models from the Tamanu repository, execute the following command:
`python scripts/refresh_tamanu_source.py`

This command pulls the source model information from the Tamanu repository based on the version specified in the dbt_project.yml file. All models located under the `tamanu/database/model/central-server/public/` folder (remote tamanu repository) will be copied to the `models/sources/` folder (local repository).

## Generate the build script for deployments

Execute the following command:
`python ./scripts/build_reporting_assets.py --target <target_environment>`

Replace <target_environment> with the desired deployment environment (e.g., fiji, palau). By default, it targets demoland.

This command generates views, reports, and an import script for deployment in the .\compiled\ folder. The following outputs are created:

- Dataset SQL scripts: Saved in compiled/views/reporting_schema_build_script_<target_version>.sql.
- Compiled report JSON files: Saved in compiled/reports.
- Import script: Saved as compiled/reports/importReports.js

## Generate survey models
To automatically generate dbt models and documentation for surveys from database, execute the following command:
```
python scripts/generate_survey_models.py
```
This will generate models and documentation for all surveys in the Tamanu database.

## Script to list Tamanu reports

This script generates a list of all reports in the repository grouped by deployment, and outputs the result in a Markdown file.

### Usage
The script accepts two optional command-line arguments:

base_path (optional): The base path to start extracting the folder structure. Defaults to ./models/reports/config.
output_file (optional): The path to the output Markdown file. Defaults to ./output/list_tamanu_reports.md.

### Command-Line Arguments
base_path: The directory where the script will look for JSON report files. If not provided, it defaults to ./reports/config.
output_file: The file path where the generated Markdown report will be saved. If not provided, it defaults to ./output/list_tamanu_reports.md.

### Example
To generate a report list using the default paths:

```
python list_tamanu_reports.py
```

To specify a custom base path and output file:

```
python list_tamanu_reports.py ./custom/reports ./custom/output/reports_list.md
```

The output will be a Markdown file containing a structured list of reports, grouped by deployment, with details such as report description, filters, and default date range.


## Versioning

We will use semantic versioning `< major >`.`< minor >`.`< patch >`. This number will mirror Tamanu's release
`< major >`.`< minor >` version numbers with the `< patch >` number for patching within this repository.

## Creating a release

1. Click on "Releases"
2. Click "Draft a new release"
3. You can select a branch to make the release from, but usually you'd release from `main`.
4. Give your release a "tag". This is the version number of the release.
