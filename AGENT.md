@./.maui/knowledge/AGENT.base.md
@./.maui/knowledge/standards/git-conventions.md
@./.maui/knowledge/standards/sql-conventions.md
@./.maui/knowledge/standards/dbt-conventions.md
@./.maui/knowledge/standards/metadata.md
@./.maui/knowledge/standards/tamanu-conventions.md

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

**Patient-adjacent entity** (e.g. `outpatient_appointments_change_logs`): join to the entity's source table and filter on `patient_id` directly:

```sql
from {{ source('logs__tamanu', 'changes') }} c
join {{ source('tamanu', 'appointments') }} a on a.id = c.record_id
    and a.deleted_at is null
    and a.patient_id != '{{ var("test_patient") }}'
where c.table_name = 'appointments'
    and c.record_deleted_at is null
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

- All base model `.yml` files require `config.tags: [reference]` — this applies to every base model, including junction/item-level tables
- Do not add `data_tests` to base model `.yml` files — tests are already defined on source models and would run twice
- Base models reference source tables with `{{ source('tamanu', 'table_name') }}` directly
- Dataset macros must use `ref()` to reference base models, never `source()` directly
- If a source table has no base model yet, create one before referencing it in a dataset macro

## Documentation (doc blocks)

Column descriptions are defined once in `models/sources/<table>.md` and reused throughout the model hierarchy via `{{ doc('key') }}`:

- `models/sources/<table>.md` — defines `{% docs table__<table> %}` and `{% docs <table>__<column> %}` blocks
- Base model `.yml` files reference these with `{{ doc('table__<table>') }}` (description) and `{{ doc('<table>__<column>') }}` (column descriptions)
- Dataset `.yml` files reference the same source-layer doc blocks for columns they expose

Generic doc blocks (e.g. `generic__id`, `generic__visibility_status`) are in `models/sources/generic.md`.

Never write inline descriptions in `.yml` files when a `{{ doc() }}` reference exists — always prefer the reusable doc block.

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

## File naming

- Reports: `<description>-line-list.sql` with a matching config in `models/reports/config/`
- Never edit `list_tamanu_reports.md` — auto-generated
