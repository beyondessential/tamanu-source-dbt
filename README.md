# Tamanu standard models

A dbt project of Tamanu's standard models. This includes:

- raw (or source) schema (incomplete documentation and validation test)
- reporting schema (incomplete documentation)
- analytics schema (upcoming)

## Generating a .yml documentation file for tables

The codegen package has a macro `generate_source` that will create a skeleton .yml file.

Run `dbt run-operation generate_source --args '{"schema_name": "public", "table_names": ["table_name1", "table_name2"], "generate_columns": True, "include_descriptions": True, include_data_types: True}'`

Replace "table_name1" and "table_name2" with the names of the new tables.

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

This script generates a list of all reports in the repository and outputs the result in a Markdown file.

### Usage
To generate a report list:

```
python list_tamanu_reports.py
```

## Versioning

We will use semantic versioning `< major >`.`< minor >`.`< patch >`. This number will mirror Tamanu's release
`< major >`.`< minor >` version numbers with the `< patch >` number for patching within this repository.

## Creating a release

1. Click on "Releases"
2. Click "Draft a new release"
3. You can select a branch to make the release from, but usually you'd release from `main`.
4. Give your release a "tag". This is the version number of the release.
