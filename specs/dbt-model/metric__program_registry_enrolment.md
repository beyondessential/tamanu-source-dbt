# dbt Model Spec: `metric__program_registry_enrolment` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__program_registry_enrolment` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware — `table` on `analytics*`, `view` everywhere else |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-08-24 |
| **Last updated** | 2026-08-24 |

## Purpose

Make program registry membership reportable. A program registry is how Tamanu follows a patient
through a long-running care programme — HIV, TB, an NCD register — and until now that membership
was visible only in a line list (`ds__patient_program_registrations`) and in the registry screen.
A consumer could read who was enrolled; it could not count enrolments over time, break them down
by cascade position, or measure retention.

The measure is deliberately **registry-agnostic**. One metric serves every registry a deployment
configures, because the programme-specific part of a cascade is the clinical status list, and that
is a disaggregation rather than a definition. An HIV cascade is a group-by on
`clinical_status_code`; TB retention is the same query with a different `registry_code`.

Where a standards body defines a programme indicator over the same population — WHO HIV treatment
coverage, an MSF standard indicator — that indicator is registered in its own right and this
metric does not substitute for it. This one answers *who is enrolled, where are they in the
programme, and are they still in it*.

## Definition sources

| Source | Reference |
|---|---|
| Tamanu program registries | The deployment's own registry configuration — registry code, clinical status list, `currently_at_type` |
| BES | `program_registry_enrolment` in `documentations/metrics/program_registry.yml` |

No external standard defines the enrolment: it is Tamanu's own construct, so the definition
follows the source system.

## Grain

One row per patient enrolment in a program registry — the same grain as `clinical__episode`,
which is one row per `patient_program_registrations` record. `subject_id` is the episode id, a
composite of patient and registry, so a patient holds one row per registry they are enrolled in
and a distinct count of `subject_id` within one `registry_code` is a patient count.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Constant `program_registry_enrolment` |
| `variant_id` | text | NULL — the standard definition |
| `subject_id` | varchar | `clinical__episode.episode_id` |
| `period_start` | timestamp | Enrolment datetime |
| `period_end` | timestamp | End of the enrolment; NULL while open |
| `period_granularity` | text | Constant `minute` |
| `value_numeric` | numeric | Constant 1 |
| `value_boolean` | boolean | NULL — unused |
| `registry_code` / `registry_name` | varchar | The registry the enrolment is in |
| `clinical_status_code` / `clinical_status` | varchar | Cascade position; NULL where unset |
| `registration_status` | text | `active` or `inactive` |
| `episode_end_source` | text | `deactivation` or `status change`; NULL while open |
| `currently_at_type` | text | `facility` or `village`, as the registry configures |
| `currently_at_id` | varchar | Where the patient is followed now |
| `facility_id` | varchar | The registering facility |
| `sex` | varchar | |
| `age_years` | integer | At enrolment, unbanded |

## Data tables

Configured in `tupaia-data-product` at `tamanu/data_tables/`, not here (BL-013).
`program_registry_enrolment__standard.yml` is the standard presentation: the registry and the
cascade position as filters, age banded to the WHO primary classification, and the currently-at
facility crosswalked to a Tupaia entity code.

## Business logic

- **BL-001:** The metric implements the `program_registry_enrolment` definition registered in
  `documentations/metrics/program_registry.yml`. The registry row carries the definition; this
  model is its implementation.
- **BL-002:** `period_start` is the enrolment datetime and `period_end` the end of the enrolment,
  both at minute grain, so an enrolment open on a given day is one whose `period_start` has passed
  and whose `period_end` is null or later. `period_end` is NULL while the enrolment is open.
- **BL-003:** One row per enrolment, `value_numeric` constant 1, so summing it counts enrolments
  at any grain and nothing is pre-aggregated.
- **BL-004:** Every registry the deployment configures is emitted, identified by `registry_code`.
  The code rather than the name: a registry can be renamed, and a data table written against the
  name would then report nothing.
- **BL-005:** `clinical_status_code` carries the patient's current position in the registry's own
  status list, as a disaggregation. It is nullable — an enrolment with no status set has no
  cascade position, and inventing one would report a clinical fact that does not exist.
- **BL-006:** Retention is derived from the boundaries rather than asserted: the exited share is
  `sum(value_numeric) filter (where period_end is not null) / sum(value_numeric)`.
  `episode_end_source` names which rule resolved the boundary, so a consumer can separate a
  deactivation from a logged status change, and is NULL exactly when `period_end` is.
- **BL-007:** `currently_at_id` is where the patient is followed now, read with
  `currently_at_type`, which names whether that is a facility or a village.
- **BL-008:** `facility_id` is the registering facility, which is not necessarily where the
  patient is followed now. Nullable: a registration recorded without one is still a registration.
- **BL-009:** `age_years` is age in whole years at enrolment.
- **BL-010:** Sourced only from `clinical__episode` and `clinical__person` (D10). The person join
  is inner, which drops nothing — `clinical__episode`'s own AC-010 guarantees the person exists.
- **BL-011:** A row is patient-identifiable: `subject_id` embeds the patient id, and registry
  membership is itself the sensitive fact. `pii: true`, `classification: restricted`, and a
  consumer's data table names its permission group explicitly rather than inheriting the
  deployment's general user group.

  The model carries no `restricted` **tag**, so it ships in the compiled reporting bundle like
  every other `metric__` view. The tag and the classification are different axes: the tag gates a
  model on `has_sensitive_facility`, which is a deployment feature rather than a statement about
  PII, so tagging this would withhold the metric from every deployment without sensitive
  facilities — the opposite of what is wanted. The shipped schema is patient-identifiable by
  design: `bases/patients` and `ds__patient_program_registrations` are both `pii: true`,
  `classification: restricted` and both ship, the latter carrying patient names alongside the
  registry and clinical status that back the program-registry reports. This metric adds no class
  of exposure that schema does not already hold.
- **BL-012:** The Tamanu ids for facility, village and registry are emitted as they are.
  Translating them to a consumer's identifiers — a Tupaia entity code, a DHIS2 org unit — is a
  consumer-layer concern.
- **BL-013:** No `data_table_*` meta on the model. Presentation — which columns filter, how age
  bands — is configured per consumer in `tupaia-data-product`.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `(metric_id, subject_id)` is unique | BL-003 | `dbt_utils.unique_combination_of_columns`, severity error |
| AC-002 | `period_end >= period_start` where `period_end` is not null | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-003 | `period_end` is null exactly when `episode_end_source` is null | BL-006 | `dbt_utils.expression_is_true` |
| AC-004 | `metric_id` is not null and is `program_registry_enrolment` | BL-001 | `not_null`, `accepted_values` |
| AC-005 | `metric_id` appears in `metric_definitions` | BL-001 | `relationships`, severity error |
| AC-006 | `subject_id` is not null | BL-003 | `not_null` |
| AC-007 | `period_start` is not null | BL-002 | `not_null` |
| AC-008 | `period_granularity` is not null and is `minute` | BL-002 | `not_null`, `accepted_values` |
| AC-009 | `value_numeric` is not null and always 1 | BL-003 | `not_null`, `accepted_values` |
| AC-010 | `registry_code` is not null | BL-004 | `not_null` |
| AC-011 | `registration_status` is not null and is `active` or `inactive` | BL-006 | `not_null`, `accepted_values` |
| AC-012 | `episode_end_source` is `deactivation` or `status change` | BL-006 | `accepted_values` |
| AC-013 | `currently_at_type` is `facility` or `village` | BL-007 | `accepted_values` |

BL-005, BL-008 and BL-009 carry no acceptance criterion: each states that a column is nullable
and unbanded, which is the absence of a constraint rather than one to assert. BL-010 to BL-013 are
sourcing, classification and configuration rules enforced by review.

## Dependencies

`clinical__episode` (and through it `int__program_enrolments` and
`int__registration_status_history`), `clinical__person`, `metric_definitions`.

## Consumers

Tupaia dashboards, through the data table named above. A deployment reporting a programme
indicator to a national HMIS or DHIS2 reads the same metric.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether the enrolment should be emitted per spell rather than per registration, so a patient who left a programme and returned contributes two rows. Depends on how `clinical__episode` resolves the end of a re-closed registration. | Data Lead | with `clinical__episode` |

## Related

- `specs/dbt-model/clinical__episode.md` — the enrolment and its boundaries
- `documentations/metrics/program_registry.yml` — the registered definition
- `tupaia-data-product`, `tamanu/data_tables/program_registry_enrolment__standard.yml`

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-24 | Maui team | Initial spec. Registry-agnostic enrolment metric over `clinical__episode`, with the cascade as a disaggregation and retention derived from the enrolment boundaries. |
