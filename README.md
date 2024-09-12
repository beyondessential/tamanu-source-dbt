# Tamanu standard models

A dbt project of Tamanu's standard models. This includes:
- raw (or source) schema (incomplete documentation and validation test)
- reporting schema (incomplete documentation)
- aggregation schema (upcoming)

## Generating a .yml documentation file for tables

The codegen package has a macro `generate_source` that will create a skeleton .yml file.

Run `dbt run-operation generate_source --args '{"schema_name": "public", "table_names": ["table_name1", "table_name2"], "generate_columns": True, "include_descriptions": True, include_data_types: True}'`

Replace "table_name1" and "table_name2" with the names of the new tables. 

## SQL linting

We use SQLFluff and the configuration file is located in the root folder and is named `.sqlfluff`.

There are two commands available to run:
- `sqlfluff lint models` - Lints the file (does not apply fix)
- `sqlfluff fix models` - Fixes the SQL files

## Generate the build script for deployments

After building the models `dbt build --profiles-dir .\config --target test`, navigate to the `.\scripts\` folder run 
`py .\generate_build_script.py`. This will generate the build script for deployment with filename 
`reporting_schema_build_script.sql`. Rename this file by appending the version number (i.e. 
`reporting_schema_build_script_v2.16.0.sql`). Alternatively the script accepts arguments for dbt_database, dbt_schema and 
out_file (e.g. `py .\generate_build_script.py -d tamanu_sync -s reporting -f reporting_schema_build_script_v2.16.0.sql`)

To ensure the build script is appropriate for deployment, ensure the name of the database is stripped and references are 
made to the `public` or `reporting` schema.

## Versioning

We will use semantic versioning `< major >`.`< minor >`.`< patch >`. This number will mirror Tamanu's release 
`< major >`.`< minor >` version numbers with the `< patch >` number for patching within this repository.

## Creating a release

1. Click on "Releases"
2. Click "Draft a new release"
3. You can select a branch to make the release from, but usually you'd release from `main`.
4. Give your release a "tag". This is the version number of the release.
