@./.maui/knowledge/AGENT.base.md
@./.maui/knowledge/standards/git-conventions.md
@./.maui/knowledge/standards/sql-conventions.md
@./.maui/knowledge/standards/dbt-conventions.md
@./.maui/knowledge/standards/metadata.md
@./.maui/knowledge/standards/tamanu-conventions.md
@./.maui/knowledge/standards/agent-patterns.md

---

## Repository: tamanu-source-dbt

Mono-repo for Tamanu and Tupaia reporting. Provides source base models for `data-staging` and deployment-specific `tamanu-dbt-*` repos.

## Change log base models

Change log base models extract from `{{ source('logs__tamanu', 'changes') }}` and must filter out test patient data. The pattern varies by how close the entity is to the patient:

**Direct patient entity** (e.g. `patient_additional_data_change_logs`): `record_id` is the patient ID, so use the `base_history_from_log` macro and filter inline:

```sql
with filtered_changes as (
    {{ base_history_from_log('patient_additional_data') }}
        and record_id != '{{ var("test_patient") }}'
)
```

**Patient-adjacent entity** (e.g. `outpatient_appointments_change_logs`): filter on `patient_id` extracted from the historical `record_data` snapshot. This preserves change logs for soft-deleted records and reflects the patient association at the time of the change:

```sql
from {{ source('logs__tamanu', 'changes') }} c
where c.table_name = 'appointments'
    and c.record_deleted_at is null
    and (c.record_data ->> 'patient_id') != '{{ var("test_patient") }}'
```

**Encounter-adjacent entity** (e.g. `invoices_change_logs`): join through the entity to encounters to reach the patient:

```sql
from {{ source('logs__tamanu', 'changes') }} c
join {{ source('tamanu', 'invoices') }} i on i.id = c.record_id
    and i.deleted_at is null
join {{ source('tamanu', 'encounters') }} e on e.id = i.encounter_id
    and e.deleted_at is null
    and e.patient_id != '{{ var("test_patient") }}'
where c.table_name = 'invoices'
    and c.record_deleted_at is null
```

Always filter `c.record_deleted_at is null` regardless of pattern.

## Base model conventions

- All base model `.yml` files require a domain-specific `config.tags` — use the tag that matches the entity type: `clinical` (clinical entities), `reference` (reference/lookup data), `log` (change log models), `administration` (admin entities), `patient` (patient-specific models)
- Do not add `data_tests` to base model `.yml` files — tests are already defined on source models and would run twice
- Base models reference source tables with `{{ source('tamanu', 'table_name') }}` directly
- Dataset macros must use `ref()` to reference base models, never `source()` directly
- If a source table has no base model yet, create one before referencing it in a dataset macro

## Macro folder layout

Macros that wrap a model layer live in `macros/<layer>/`, mirroring `models/<layer>/`:

- `macros/bases/` — utilities used by base models (e.g. `base_history_from_log`, `get_metadata_from_changes`)
- `macros/datasets/` — `<entity>_dataset(is_sensitive)` macros materialised by `ds__<entity>` and `ds__sensitive_<entity>`
- `macros/reports/` — `<report>_report(...)` macros called by SQL files under `models/reports/sql/{standard,sensitive}/`

Cross-cutting utilities (`datetime.sql`, `translations.sql`, `parameter.sql`, etc.) stay at the top of `macros/`.

## Documentation (doc blocks)

Column descriptions are defined once in `models/sources/<table>.md` and reused throughout the model hierarchy via `{{ doc('key') }}`:

- `models/sources/<table>.md` — defines `{% docs table__<table> %}` and `{% docs <table>__<column> %}` blocks
- Base model `.yml` files reference these with `{{ doc('table__<table>') }}` (description) and `{{ doc('<table>__<column>') }}` (column descriptions)
- Dataset `.yml` files reference the same source-layer doc blocks for columns they expose

Generic doc blocks (e.g. `generic__id`, `generic__visibility_status`) are in `models/sources/generic.md`.

Never write inline descriptions in `.yml` files when a `{{ doc() }}` reference exists — always prefer the reusable doc block.

## Reports

Reports live under `models/reports/` and are organised into two categories:

- `standard/` — general reports available to all users
- `sensitive/` — versions of standard reports that include personally identifiable or clinically sensitive columns

Every sensitive report has a corresponding standard report. The naming convention is:
- Standard: `<name>.sql` / `<name>.json`
- Sensitive equivalent: `sensitive-<name>.sql` / `sensitive-<name>.json`

When creating a new sensitive report, always create the standard version first, then the sensitive variant prefixed with `sensitive-`.

File naming conventions:
- Patient-level data: `<description>-line-list.sql`
- Aggregated/summary data: `<description>-summary.sql` or `<description>-summary-by-<grouping>.sql`

Each report has a matching config in `models/reports/config/standard/` or `models/reports/config/sensitive/`.

When the standard and sensitive variants share non-trivial SELECT/WHERE logic, extract it into a macro at `macros/reports/<name>.sql` parameterised on `is_sensitive`, and reduce each SQL file to a single `{{ <name>_report(is_sensitive=...) }}` call. The macro picks `ds__<name>` vs `ds__sensitive_<name>` based on the flag. See `encounter_summary_report` and `admissions_line_list_report` for the pattern.

Never edit `list_tamanu_reports.md` — it is auto-generated by `scripts/list_tamanu_reports.py`.

## Translation system

- Source: `report_translations_standard.csv` → generates `macros/default_translations.sql`
- Usage: `{{ translate_label('field_name') }}` — auto-prefixes with `report.reporting.`
- Label conventions: sentence casing (e.g. "Patient name"), concept prefixes (e.g. `patient_name`, not `name`)
- Run `python scripts/generate_translation_macro.py` if the CSV changes

## Patch propagation script

`scripts/propagate_patch.py` has a test suite at `scripts/tests/test_propagate_patch.py`.
Run the tests whenever `propagate_patch.py` or its test file changes:

```bash
cd scripts && python -m pytest tests/test_propagate_patch.py -v
```

## Pre-commit checklist

```bash
sqlfluff fix .
dbt test --profiles-dir config
python scripts/validate_report_configs.py
python scripts/check_translations.py
# if report_translations_standard.csv changed:
python scripts/generate_translation_macro.py
```

---

## Codebase navigation

Reference locations for common pattern lookups — use these as starting points rather than
scanning the whole codebase:

| What you need | Where to look |
|---------------|---------------|
| Base model example | `models/bases/encounters.sql` + `models/bases/encounters.yml` |
| Dataset macro example | `macros/datasets/admissions.sql` |
| Report macro example | `macros/reports/admissions_line_list.sql` |
| Standard report example | `models/reports/sql/standard/admissions-line-list.sql` |
| Sensitive report example | `models/reports/sql/sensitive/sensitive-admissions-line-list.sql` |
| Report config example (standard) | `models/reports/config/standard/admissions-line-list.json` |
| Report config example (sensitive) | `models/reports/config/sensitive/sensitive-admissions-line-list.json` |
| Datetime macros | `macros/datetime.sql` |
| Translation macro | `macros/translations.sql` (hand-authored); `macros/default_translations.sql` is generated from the CSV — do not edit directly |
| Translation source | `report_translations_standard.csv` |
| Source doc blocks | `models/sources/<table>.md` |
| Deployment repo list | `.github/deployment-repos.yml` |

Quick search commands:

```bash
# Find all models referencing a base model
grep -r "ref('<model_name>')" models/
# e.g. grep -r "ref('encounters')" models/

# Find all models using a specific macro
grep -r "{{ <macro_name>" models/ macros/
# e.g. grep -r "{{ translate_label" models/ macros/

# Find reports not yet using a macro (e.g. locate old patterns to replace)
grep -r "<old_pattern>" models/reports/
# e.g. grep -r "at time zone" models/reports/
```

---

## Common multi-file workflows

For full step-by-step guides, see `.maui/knowledge/runbooks/`. Summary of when to use
parallel agents for each workflow:

**Adding a new report pair (standard + sensitive):**
Follow `.maui/knowledge/runbooks/new-report.md`. Before writing any SQL, search
`models/reports/sql/standard/` for the closest existing report to use as a template.
Check translation coverage in parallel with finding the template.

**Rolling out a new macro to existing models:**
Follow `.maui/knowledge/runbooks/macro-change-impact.md`. Search for all affected files
before editing any of them — use parallel searches across model layers (bases, datasets,
reports) to build the complete list first.

**Creating a new base model:**
Check in parallel: (1) does a source definition already exist in `models/sources/`?
(2) does a doc block file exist in `models/sources/<table>.md`? (3) find a peer base
model in the same domain tag (`clinical`, `reference`, `log`, `administration`, `patient`)
to use as a reference. Only then create the new files.
