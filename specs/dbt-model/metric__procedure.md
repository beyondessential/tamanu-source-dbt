# dbt Model Spec: `metric__procedure` (canonical definition)

## Identity

| | |
|---|---|
| **Name** | `metric__procedure` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-005) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

## Purpose

A count of recorded clinical procedures, in any encounter setting, at per-procedure grain.
`visit_detail_concept_id`, `visit_detail_concept_name` and `encounter_type` carry the setting the procedure was performed in,
so a consumer scopes to outpatient or inpatient activity by filtering this one metric.

## Definition sources

`definition_source: BES`. No external body registers a procedure count as a single
indicator -- procedure classifications (e.g. ICD-10-PCS, CPT) code what a procedure is, not
how a deployment should count procedure activity, and deployments differ in what they code
procedures with. Pending alignment with the deploying country's national HMIS definition.

## Grain

One row per procedure: `subject_id` is `clinical__procedure_occurrence.procedure_occurrence_id`,
which is `procedures.id` unchanged. `value_numeric` is always `1`, so summing it counts
procedures at any grouping.

## Output schema

| Column | Type | Meaning |
|---|---|---|
| `metric_id` | text | Always `'procedure'` (BL-002) |
| `variant_id` | text | NULL -- standard definition, no deployment variant |
| `subject_id` | varchar(255) | The Tamanu procedure id (grain) |
| `period_start` | date | The date the procedure was performed (BL-002) |
| `period_end` | date | NULL -- a procedure is point-in-time (BL-002) |
| `period_granularity` | text | Always `'day'` (BL-002) |
| `value_numeric` | numeric | Always `1` (BL-002) |
| `value_boolean` | boolean | NULL -- unused |
| `facility_id` | varchar(255) | The facility of the segment the procedure was performed in (BL-004). `not_null` (AC-007) |
| `encounter_type` | varchar(255) | The deployment's own encounter type for that segment (BL-003). `not_null` (AC-014) |
| `visit_detail_concept_id` | integer | The resolved segment's OMOP Visit concept: 9201, 9202, 9203 or 0 (BL-010) |
| `visit_detail_concept_name` | text | Its OMOP name, e.g. Outpatient Visit (BL-010) |
| `sex` | varchar(255) | The patient's sex, from `clinical__person` |
| `procedure` | text | The procedure as recorded, ungrouped (BL-006). Never NULL |
| `procedure_code` | text | The procedure type's reference-data code (BL-006). Never NULL |
| `is_completed` | boolean | Whether the procedure was marked completed (BL-006) |
| `age_years` | integer | Age in whole years at the procedure, unbanded (BL-007). A measure, not a dimension |
| `department` | text | The department of that segment, resolved to a name (BL-009). Never NULL |

## Business logic

- **BL-001 (population is the procedure branch):** sourced from
  `clinical__procedure_occurrence` filtered to `procedure_type_source_value = 'procedure'`.
  That model carries both a procedure and an imaging branch (its BL-001) -- imaging is
  `metric__imaging_request`'s population, not this one's.

- **BL-002 (registration + reporting period):** the emitted `metric_id` is registered in
  `documentations/metrics/procedure.yml` and resolves in `metric_definitions`.
  `period_start` is the procedure date and `period_granularity` is `'day'` -- Tamanu records
  a procedure against a date, so there is no sub-day period to report. `period_end` is NULL:
  a procedure is point-in-time and has no closing event. `value_numeric` is `1` per row and
  additive at every grain.

- **BL-003 (setting is the segment's, not the encounter's):** `encounter_type` is the
  `clinical__visit_detail` segment's own `visit_detail_source_value`, read through the
  `visit_detail_id` that `clinical__procedure_occurrence` resolves (its BL-005). It is the
  phase the encounter was in when the procedure was performed, so a procedure performed
  during a triage phase of an encounter later admitted reads as `triage`. The join is
  **inner**: a procedure whose segment did not resolve carries a NULL FK and is dropped
  rather than surfaced without a setting.

- **BL-004 (facility attribution):** `facility_id` is resolved through `bases/locations` on
  the resolved segment's own `care_site_id` -- the same source `metric__imaging_request`
  uses, so a procedure and an imaging request belonging to one segment agree on facility.
  For an encounter that moved, this is the facility the patient was at when the procedure
  was performed. An encounter with no recorded history has a single whole-visit segment
  (`clinical__visit_detail` BL-005), so for those it is the encounter's own location. The
  join is **inner**, so a procedure whose segment's care site does not resolve is excluded
  rather than attributed to a NULL facility.

- **BL-005 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the `metrics:` block in `dbt_project.yml` (shared
  across the layer).

- **BL-006 (procedure identity is emitted raw):** `procedure` and `procedure_code` are the
  reference-data name and code as recorded, ungrouped -- deployments differ in what they
  code procedures with, so any grouping is applied downstream over `procedure_code`. Both
  fall back so neither is ever NULL: Tupaia exposes them as array filters, and an array
  filter drops a NULL row. `is_completed` is the recorded flag, coalesced to `false`.

- **BL-007 (age is the consumer's to band):** `age_years` is age in whole years at the
  procedure date. An age classification is a presentation choice a deployment may set
  differently, so the consumer's data table bands it. A measure, not a dimension: absent
  from the registry's disaggregations.

- **BL-009 (department):** the resolved segment's own `department_id`, resolved to a name
  through `departments` so a consumer scopes to one department (e.g. Dental) via
  `metric_filters` on a readable value, the same convention procedure identity (BL-006)
  uses rather than an opaque Tamanu id. `bases/locations` carries no `department_id`, so it
  comes off the segment directly. Never NULL -- falls back to `'Not recorded'`.
- **BL-010 (visit concept):** `visit_detail_concept_id` and `visit_detail_concept_name` are the resolved segment's OMOP Visit concept and its name, as `clinical__visit_detail` carries them.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`, `ac_metric__procedure_grain`) |
| AC-002 | `metric_id` is `not_null` | BL-002 | `not_null` (`ac_metric__procedure_metric_id_not_null`) |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-002 | `relationships` (`error`, `ac_metric__procedure_metric_id_registered`) |
| AC-004 | `metric_id` is always `procedure` | BL-002 | `accepted_values` (`ac_metric__procedure_metric_id_values`) |
| AC-005 | `period_start` is `not_null` | BL-002 | `not_null` (`ac_metric__procedure_period_start_not_null`) |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-002 | `not_null` + `accepted_values` (`ac_metric__procedure_value_numeric_not_null` / `_is_one`) |
| AC-007 | `facility_id` is `not_null` | BL-004 | `not_null` (`ac_metric__procedure_facility_id_not_null`) |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` (`ac_metric__procedure_subject_id_not_null`) |
| AC-009 | `period_end` is always NULL | BL-002 | `dbt_expectations.expect_column_values_to_be_null` (`ac_metric__procedure_period_end_null`) |
| AC-010 | `period_granularity` is `not_null` and always `'day'` | BL-002 | `not_null` + `accepted_values` (`ac_metric__procedure_period_granularity_not_null` / `_is_day`) |
| AC-011 | `procedure` is `not_null` | BL-006 | `not_null` (`ac_metric__procedure_procedure_not_null`) |
| AC-012 | `procedure_code` is `not_null` | BL-006 | `not_null` (`ac_metric__procedure_procedure_code_not_null`) |
| AC-013 | `is_completed` is `not_null` | BL-006 | `not_null` (`ac_metric__procedure_is_completed_not_null`) |
| AC-014 | `encounter_type` is `not_null` | BL-003 | `not_null` (`ac_metric__procedure_encounter_type_not_null`) |
| AC-016 | `department` is `not_null` | BL-009 | `not_null` (`ac_metric__procedure_department_not_null`) |
| AC-017 | Each row carries its own segment's `encounter_type`, a procedure whose segment did not resolve (NULL FK) is dropped, the imaging branch is excluded, a 9202 segment that is not `clinic` still carries 9202, and a 9203 segment carries 9203 | BL-001, BL-003, BL-010 | dbt unit test `test_metric__procedure_segment_scope` |
| AC-018 | `facility_id` follows the segment's `care_site_id`, including where the procedure's own `location_id` names a different facility or is absent | BL-004 | dbt unit test `test_metric__procedure_facility_attribution` |
| AC-019 | The as-of match and first-segment clamp that resolve the segment | `clinical__procedure_occurrence` BL-005 | dbt unit test `test_clinical__procedure_occurrence_visit_detail_resolution` (upstream) |

Test names are unnumbered (`ac_metric__procedure_<column>_<check>`), matching
`metric__procedure.yml`'s own convention rather than the `ac_NNN_...` scheme -- this spec's
AC numbering is for cross-reference within this document only.

## Dependencies

| Model | Layer | Used for |
|---|---|---|
| `clinical__procedure_occurrence` | `clinical` | Procedure identity, date, completion flag, and the resolved `visit_detail_id` (BL-001) |
| `clinical__visit_detail` | `clinical` | The segment's encounter type, visit concept, care site and department (BL-003, BL-004, BL-009, BL-010) |
| `clinical__person` | `clinical` | Sex and birth date for `age_years` |
| `locations` | `bases/` | Facility id of the resolved segment's care site (BL-004) |
| `departments` | `bases/` | Department name for the resolved segment (BL-009) |

## Consumers

Tupaia data tables over this model are configured in `tupaia-data-product` at
`tamanu/data_tables/`, one file per data table.

## Related

| Artefact | Relationship |
|---|---|
| `clinical__procedure_occurrence` | The clinical-layer source, which resolves the segment once for every metric over it (its BL-005) |
| `metric__imaging_request` | The imaging-branch counterpart over the same clinical model, resolving facility from the same segment `care_site_id` |
| `metric__emergency_visit`, `metric__emergency_stay` | Emergency reporting, on their own scoping rules and at encounter grain -- not a population this metric reproduces |

## Change log

| Date | Change | Issue |
|---|---|---|
| 2026-10-03 | `encounter_setting` retired: a consumer scopes a setting on `visit_detail_concept_id` and labels it with `visit_detail_concept_name` | -- |
| 2026-09-28 | Facility resolved from the segment's `care_site_id`; OPD/IPD scoped metrics folded into this one behind the segment's OMOP Visit concept; `department` added | -- |
