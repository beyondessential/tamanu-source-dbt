# dbt Model Spec: `metric__ed_procedure` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__ed_procedure` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-007) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Linear issue** | MAUI-6907 |

Canonical definition for `ed_procedure`: one row per recorded procedure performed during the
emergency phase of an encounter. The emergency-side counterpart of
`metric__opd_procedure`, built from it directly -- same as-of-segment pattern, same output
shape, scoped to OMOP concept 9203 instead of 9202.

## Purpose

Procedures performed during emergency care, one row per procedure.

| `metric_id` | Unit | Measures |
|---|---|---|
| `ed_procedure` | count | Procedures performed in an ED phase (always 1 per row) |

**Who reads it.** The Tupaia Emergency Department dashboard's procedures table (MAUI-6907),
via a data table over this view in `tupaia-data-product`.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | BES | n/a | A count of recorded procedures scoped to the emergency setting -- no external body registers this indicator |

No AIHW METeOR element is registered. Procedure classifications (ICD-10-PCS, CPT) code what a
procedure *is*, not how a deployment should count procedure activity, and deployments differ in
what they code procedures with. This is a BES composition, `definition_source: BES`, the same
status `metric__procedure`/`metric__opd_procedure` carry.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity -- a
duplicate would double-count a procedure in any consumer that sums `value_numeric`.

`subject_id` is the Tamanu procedure id (`clinical__procedure_occurrence`'s
`procedure_occurrence_id`), matching the registry's `subject_grain: procedure`. There is one
row per procedure already, so no segment stitching is needed to find the subject. The segment
logic (BL-002) decides *inclusion*, not identity.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `ed_procedure`. FK -> `metric_definitions.metric_id` |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | The Tamanu procedure id. `not_null` |
| `period_start` | date | The date the procedure was performed (BL-003) |
| `period_end` | date | NULL -- a procedure is point-in-time (BL-003) |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1`. Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- unused by this metric |
| `facility_id` | varchar(255) | The procedure's own location's facility (BL-006). `not_null` |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `procedure` | text | The procedure as recorded, ungrouped (BL-008). Never NULL |
| `procedure_code` | text | The procedure type's reference-data code (BL-008). Never NULL |
| `is_completed` | boolean | Whether the procedure was marked completed. Never NULL |
| `age_years` | integer | Age in whole years at the procedure, unbanded (BL-008). A measure, not a dimension |
| `department` | text | The qualifying segment's own department, resolved to a name (BL-005). Never NULL |

## Data tables

The Tupaia data table over this view belongs in `tupaia-data-product`, at
`tamanu/data_tables/`, the same convention every other `metric__` model in this project uses --
filter types, aggregation and any bands are the consumer's vocabulary, not dbt's. This model
therefore carries no `data_table_*` meta.

## Business logic

- **BL-001 (a dedicated metric, not an `encounter_type` filter):** emergency procedures are
  their own metric rather than a filter over `metric__procedure`'s `encounter_type`.
  `encounter_type` is `clinical__visit_occurrence.visit_source_value`, which is the encounter's
  **current** type: an attendance that began in the ED and went on to an inpatient admission is
  retyped `admission`, which is exactly why `clinical__visit_occurrence` carries a special case
  mapping such encounters to OMOP concept 262. Filtering `metric__procedure` to `'emergency'`
  therefore drops every admitted-via-ED patient, while `metric__emergency_visit` -- which every
  other card on the ED dashboard reads -- counts them. A procedures table built that way would
  disagree with the admission-rate card beside it, and would undercount worst for the sickest
  patients. Scoping on the segment instead (BL-002) counts a procedure by the phase of care it
  happened in, so an attendance later admitted keeps the procedures of its emergency phase.

  This also follows the precedent `metric__opd_procedure` set (itself a decision, MAUI-6862):
  setting-scoped procedure metrics are kept apart rather than folded into one metric with an
  encounter-type disaggregation.

- **BL-002 (emergency scope: the segment active when the procedure happened):** a procedure is
  included when the `clinical__visit_detail` segment it resolves to carries
  `visit_detail_concept_id = 9203` (OMOP 'Emergency Room Visit'), which covers the `emergency`,
  `triage` and `observation` encounter phases (`map__omop_visit_type`) -- the same population
  `int__emergency_visits` takes its intake segment from.

  The segment is resolved in this model, with the as-of match `metric__opd_procedure` uses:
  the latest segment of the encounter that had started by the procedure's own timestamp,
  tie-broken on `visit_detail_id`, clamped to the encounter's first segment for a procedure
  timestamped before any segment began. A procedure on an encounter with no segment is dropped
  by the inner join, rather than surfaced without a setting.

  **Boarding is the admission phase.** Once the encounter is retyped as an admission its segment
  is 9201, even while the patient is still in the ED awaiting a bed. A procedure performed then
  is not counted here -- it is in `metric__procedure` under encounter type `admission`. For a
  boarding patient this metric's span therefore ends before the stay `metric__emergency_stay`
  measures, which runs to physical departure (its BL-018).

  **Known limitation: untimed procedures.** Where `start_time` is empty,
  `clinical__procedure_occurrence` dates the procedure at midnight of its date, because
  `bases/procedures` casts `date` to a date and discards its time. On the day of arrival midnight
  precedes the ED intake, so the first-segment clamp resolves the procedure to the intake segment,
  and it is counted here even if it was performed after the admission retype or after the patient
  left the ED. `start_time` is optional in Tamanu: the web form pre-fills it, but a procedure loaded
  another way -- by a migration from a previous system, for instance -- need not carry one, even
  where its `date` holds a full timestamp. The correction belongs upstream: fall back to `date`'s
  own time rather than midnight. Imaging is unaffected, since a request carries a full timestamp.

- **BL-003 (registration, count and reporting period):** `metric_id` is the constant
  `'ed_procedure'`, registered in `documentations/metrics/emergency.yml`. There is one row per
  procedure, and `value_numeric` is the constant `1`, so a consumer sums it to count procedures
  at any grain. `period_start` is the procedure date and
  `period_end` is hardcoded NULL -- a procedure is point-in-time, so there is no closing date to
  emit, the same convention `metric__opd_procedure`/`metric__pharmacy_order` use.
  `period_granularity` is `'day'`.

- **BL-004 (procedure branch only):** `clinical__procedure_occurrence` carries both a procedure
  and an imaging branch, discriminated by `procedure_type_source_value` (its own BL-001). This
  metric's population is the procedure branch only.

- **BL-005 (department attribution):** `department` is the qualifying segment's own
  `department_id`, resolved to a name through `departments` so a consumer can scope to one
  department via `metric_filters` on a readable value. It follows the segment rather than the
  procedure's own location, because `bases/locations` carries no `department_id`. Left join and
  coalesced to `'Not recorded'` -- never NULL, since Tupaia's array filter drops NULL rows.

- **BL-006 (facility attribution):** `facility_id` resolves through `bases/locations` on the
  procedure's own `location_id` -- the procedure's location, not the segment's. The join is
  **inner**: a procedure whose location does not resolve is an anomaly, excluded rather than
  attributed to a NULL facility, the same convention `metric__opd_procedure` uses.

- **BL-007 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the shared `metrics:` block in `dbt_project.yml`.

- **BL-008 (identity is emitted raw, age is the consumer's to band):** `procedure` and
  `procedure_code` are the procedure type's reference-data name and code, coalesced so neither
  is ever NULL. Emitted ungrouped -- a procedure grouping is a consumer concern, the same
  reasoning `diagnosis`/`diagnosis_code` use. `age_years` is age in whole years at the
  procedure, emitted raw and unbanded: a measure, not a dimension, absent from the registry's
  disaggregations.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain, BL-003 | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `ed_procedure` | BL-003 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-003 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-003 | `not_null` |
| AC-005 | `period_end` is always NULL | BL-003 | `dbt_expectations.expect_column_values_to_be_null` |
| AC-006 | `period_granularity` is `not_null` and always `'day'` | BL-003 | `not_null` + `accepted_values` |
| AC-007 | `value_numeric` is `not_null` and always `1` | BL-003 | `not_null` + `accepted_values` |
| AC-008 | `facility_id` is `not_null` | BL-006 | `not_null` |
| AC-009 | `procedure`, `procedure_code`, `is_completed`, `department` are `not_null` | BL-005, BL-008 | `not_null` |
| AC-010 | Only 9203 segments are counted, including on an encounter later retyped as an admission, and a procedure in the boarding (admission) segment is not | BL-001, BL-002 | unit test `test_metric__ed_procedure_segment_scope` |

## Registry entry

Registered in `documentations/metrics/emergency.yml` as `ed_procedure`, `kind: metric`,
`unit: count`, `subject_grain: procedure`, with disaggregations `facility_id`, `sex`,
`procedure`, `procedure_code`, `is_completed`, `department`.

## Dependencies

| Model | Why |
|---|---|
| `clinical__procedure_occurrence` | The procedure population and its timestamp (BL-002, BL-004) |
| `clinical__visit_detail` | The segment whose OMOP concept decides inclusion (BL-002) |
| `clinical__person` | Sex and birth date (BL-008) |
| `locations` | Facility resolution (BL-006) |
| `departments` | Department name resolution (BL-005) |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Consumers

| Consumer | Use |
|---|---|
| Tupaia ED dashboard | The procedures table, ranked high to low (MAUI-6907) |

## Related

| Artefact | Relationship |
|---|---|
| `metric__opd_procedure` | The model this was built from -- identical shape and as-of-segment pattern, scoped to 9202 instead of 9203 |
| `metric__procedure` | The all-settings procedure metric, scoped by the encounter's own current type -- BL-001 explains why that scoping cannot answer the ED question |
| `metric__emergency_visit` | The attendance population this metric's procedures sit within; both count the admitted-via-ED patient |
| `metric__emergency_stay` | Measures the ED stay to physical departure, including boarding; this metric's emergency phase ends at the admission retype (BL-002) |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-24 | Maui team | Initial draft (MAUI-6907) |
