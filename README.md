# Tamanu standard models

A dbt project of Tamanu's standard models. This includes:
- raw (or source) schema (incomplete documentation and validation test)
- reporting schema (in progress)
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

## Versioning

We will use a 2-part version number < major >.< minor >. This number will mirror Tamanu's release number.

## Creating a release

1. Click on "Releases"
2. Click "Draft a new release"
3. You can select a branch to make the release from, but usually you'd release from `main`.
4. Give your release a "tag". This is the version number of the release.
