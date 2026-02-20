# Development Workflow

## tamanu-source-dbt

**Before committing**: sqlfluff fix → dbt test → validate scripts

**Pull requests**: Clear description, testing notes, request review

**Main branch**: `main` (protected)
**Feature branches**: Descriptive names (e.g., `feature/patient-report`, `fix/translation-bug`)
**Commit messages**: Imperative mood (e.g., "Add report", "Fix bug")

## tamanu-dbt-* (country projects)

1. Activate virtual environment
2. Create/modify models following layer patterns
3. Add documentation (`.yml` for custom models)
4. Implement tests
5. Run `sqlfluff fix` → `dbt test` → validate scripts
6. Use `dbt run` to verify
7. Regenerate surveys when definitions change
8. Build reporting assets before deployment

### Project setup
- Update `dbt_project.yml` with project name, profile, version
- Configure `config/profiles.yml` with database connections
- Set `.env` for credentials
- Mirror Tamanu release version numbers
