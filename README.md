# Tamanu source documentation

A dbt package for documenting and validating Tamanu's source data

## Creating a .yml documentation file for a new table

The codegen package has a macro `generate_source` that will create a skeleton .yml file.

Run `dbt run-operation generate_source --args '{"schema_name": "public", "table_names": ["table_name1", "table_name2"], "generate_columns": True, "include_descriptions": True, include_data_types: True}'`

Replace "table_name1" and "table_name2" with the names of the new tables. 

## Versioning

We will use a 2-part version number < major >.< minor >. This number will mirror Tamanu's release number.

## Creating a release

1. Click on "Releases"
2. Click "Draft a new release"
3. You can select a branch to make the release from, but usually you'd release from `main`.
4. Give your release a "tag". This is the version number of the release.

## Generating the documentation file for sharing or serving on a website

1. Run `dbt docs generate`
2. Execute python file `utils/docs_single_html.py`
3. `target/index2.html` is ready to be shared or served.