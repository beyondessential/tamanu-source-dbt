# AI Rules for tamanu-source-dbt

## Project Overview
tamanu-source-dbt is used to transform data to create datasets in a reporting schema that is optimised for performance as views. This is a dbt (data build tool) project that processes Tamanu healthcare system data.

## Core Principles
- Always follow the established data flow: sources (including logs) → bases → datasets → reports
- Maintain data integrity and quality at each transformation layer
- Prioritise performance and readability in SQL code
- Ensure comprehensive documentation for all models

## Model Layer Requirements
When working with models, always respect the following hierarchy:

### `models/sources`
- Describes Tamanu's schema and performs data integrity checks
- Origin point for most documentation blocks
- **Never modify source definitions as this is defined in another repository.**

### `models/logs`
- **Logs are a specialised type of sources** that capture system activity and audit trails
- Use `logs__tamanu` as the source name and `logs` schema (different from regular sources)
- Follow the same source principles: data integrity checks and comprehensive documentation
- Origin point for log-related data transformations and audit reporting
- **Never modify log source definitions as this is defined in another repository.**

### `models/bases` 
- Strips out deleted data and metadata from tables
- Shared with the data warehouse as the `staging` model
- **Always filter out soft-deleted records and test patients using appropriate conditions**

### `models/datasets`
- Builds on top of `bases` models
- De-normalises data for easy reporting consumption
- **Focus on creating user-friendly, denormalised views**

### `models/reports`
- Based on `datasets` models with customised translations applied
- **Apply translations consistently using established patterns**

## Documentation Requirements
- **Mandatory**: Each model except those in `reports` must have a corresponding .yml file
- Include comprehensive name and description for both the model and all columns
- Maintain professional, clear, and respectful tone in all documentation
- Reference existing doc blocks when possible to maintain consistency
- **Always document new columns when adding them to existing models**

## Translation Management
- Keep translation string lists concise and avoid duplication
- **Always check for existing translations before creating new ones**
- Follow established naming conventions for translation keys
- **Translation labels must be prefixed with a concept** (e.g., patient, user, encounter) to maintain organisation and avoid conflicts

## Code Style Standards
- **Mandatory**: Use `.sqlfluff` for SQL code style enforcement
- Run `sqlfluff fix` before committing changes
- Follow consistent indentation and formatting patterns
- Use meaningful aliases and avoid ambiguous column references
- **Always test SQL syntax before committing**
- **Use Australian English spelling** in all documentation, comments, and text (e.g., "optimise" not "optimize", "colour" not "color", "centre" not "center")

## Testing Standards
- **Required**: Implement integrity tests using dbt built-in tests for all models
- **Required**: Unit tests for business logic using dbt built-in tests or dbt-utils
- Test critical relationships and constraints
- **Always run `dbt test` before finalising changes**
- Document test failures and resolution steps

## File Management Guidelines
- Follow established naming conventions: `{table_name}.sql` and `{table_name}.yml`
- Place files in appropriate directories based on model layer
- **Never delete files without understanding downstream dependencies**
- Use `dbt deps` to manage package dependencies

## Development Workflow
1. Understand the data flow and existing model dependencies
2. Create or modify models following layer-appropriate patterns
3. Add comprehensive documentation in .yml files
4. Implement appropriate tests
5. Run `sqlfluff fix` for code formatting
6. Execute `dbt test` to validate changes
7. Use `dbt run` to build and verify models
