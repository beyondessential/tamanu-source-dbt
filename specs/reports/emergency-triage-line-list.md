# Report Spec: `emergency-triage-line-list`

## Identity

| Field | Value |
|---|---|
| **Name** | `emergency-triage-line-list` (+ `sensitive-emergency-triage-line-list`) + `ds__emergency_triage` (+ `ds__sensitive_emergency_triage`) |
| **Type** | Tamanu in-product report + supporting dataset |
| **Layer** | `ds` + `report` |
| **Materialisation** | `view` |
| **Status** | `review` |
| **Owner** | `bes-maui` (Maui team) |
| **Linear issue** | [MAUI-6778](https://linear.app/bes/issue/MAUI-6778/tamanu-report-new-ttm-emergency-triage-report) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-08-11 |
| **Last updated** | 2026-08-11 |

## Purpose

**Why does this model exist?** Emergency departments need a register of their presentations
showing triage category, waiting time to active care, and whether the category's target
waiting time was met. Raised for Samoa's TTM Hospital, built as a standard report because
nothing about the register is deployment-specific beyond the target waiting times.

**Who consumes it?** Emergency department and ministry staff, via the Tamanu reports UI.

**Business context:** Column set follows the Emergency Triage Register template supplied with
MAUI-6778. `encounter-summary-by-start-date` already exposes triage category, arrival mode and
waiting time per encounter; this report adds the presenting complaints, the triage and
active-care timestamps, target-time compliance, and an ED-shaped grain.

## Grain

**One row per emergency department presentation**, which is one triage record. Tamanu records
at most one triage per encounter.

## Inputs

| Reference | Why we need it |
|---|---|
| `ds__encounters_emergency` / `ds__sensitive_encounters_emergency` | Triage record with patient demographics, complaints, facility |
| `clinical__visit_occurrence` | OMOP visit concept, to identify presentations that became inpatient admissions |
| `encounters` | Encounter type, department and end date |
| `encounter_history` | Department the patient was triaged in |
| `encounter_diagnoses` | Diagnoses recorded during the encounter |
| `encounter_prescriptions`, `prescriptions` | Medications prescribed during the encounter |
| `discharges` | Discharge disposition |
| `reference_data` | Diagnosis, medication and disposition names |

## Configuration

| Var | Default | Purpose |
|---|---|---|
| `triage_target_minutes` | ATS: `1`→0, `2`→10, `3`→30, `4`→60, `5`→120 | Target waiting time per triage category |

## Output schema

`ds__emergency_triage` — demographics, triage detail, clinical detail, care timing, disposition.
Full column list and descriptions in `models/datasets/standard/ds__emergency_triage.yml`.
Durations are stored as `bigint` seconds and rendered as `hh:mm:ss` by the report.

## Business logic

- **BL-001:** One row per triage record, which is one emergency department presentation.
- **BL-002:** Age is calculated in whole years as at the time of triage, not the current date.
- **BL-003:** The triage score is presented as `Category N`, matching Tamanu's triage category wording.
- **BL-004:** Active care begins when the triage record is closed.
- **BL-005:** Waiting time is the interval from triage to the start of active care, and is empty while the patient is still waiting.
- **BL-006:** Diagnoses are every diagnosis recorded against the presentation's encounter, comma separated and deduplicated; `bases/encounter_diagnoses` supplies the exclusion of disproven and recorded-in-error certainties.
- **BL-007:** Medications are every medication prescribed during the presentation's encounter, comma separated and deduplicated.
- **BL-008:** Every triage category Tamanu can record (1 to 5) has a target waiting time, supplied by `var('triage_target_minutes')`. A triage score the map does not cover, and a map entry that is not a whole non-negative number of minutes, yield no target and therefore no compliance verdict rather than an error; a triage score is mandatory in the triage form but nullable in the model, so the report degrades instead of failing.
- **BL-009:** A presentation is `Admitted` where the encounter's OMOP visit concept is 262 (Emergency Room and Inpatient Visit), otherwise `Discharged` where the encounter has ended, and otherwise empty, which means the encounter is still open. A death is not a separate outcome -- the discharge disposition column carries it.
- **BL-010:** Total length of stay is the interval from triage to the end of the encounter, so an admitted patient's stay spans their whole inpatient episode.
- **BL-011:** A presentation is attributed to the facility and to the department its encounter began in, falling back to the encounter's current department when no history exists; both are report parameters only, with Tamanu scoping the department list to the selected facility.
- **BL-012:** The date range filters on the date of triage in the viewer's timezone and is inclusive of both bounds, defaulting to the past 30 days.
- **BL-013:** An active care or encounter end time recorded before the time of triage is unusable, so the duration it would produce is left empty rather than shown as zero.
- **BL-014:** The report exposes the triage category as a parameter.
- **BL-015:** The sensitive variant is identical except that it reads the sensitive emergency dataset, so it covers presentations at sensitive facilities.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `triage_id` is unique and not null, and `encounter_id` and `triage_datetime` are not null | BL-001 | dbt schema tests (`ac_001_ds__emergency_triage_*`) |
| AC-002 | Waiting time is never negative and is never present without a recorded active care time | BL-005, BL-013 | dbt singular test (`data_test__ds__emergency_triage`) |
| AC-003 | `target_wait_minutes` is populated for every triage category 1 to 5 | BL-008 | dbt singular test |
| AC-004 | `target_time_met` is `Yes` only when waiting time is within the category target | BL-008 | dbt singular test |
| AC-005 | Total length of stay is never negative and is never present without a recorded encounter end | BL-010, BL-013 | dbt singular test |
| AC-006 | An `Admitted` outcome always agrees with the encounter's OMOP visit concept, and a presentation with neither an admission nor an encounter end has no outcome | BL-009 | dbt singular test |
| AC-007 | A zero-minute category target is met by a same-second start of active care and missed by any measurable wait | BL-008 | dbt unit test (`test_ds__emergency_triage_target_time_met`) |
| AC-008 | Every presentation resolves an OMOP visit concept, so a blank outcome only ever means an open encounter | BL-009 | dbt singular test |

AC-002 to AC-006 and AC-008 run against the standard dataset only. The sensitive variant is
generated from the same macro, so its logic is identical by construction; it carries the
AC-001 schema tests in its own right. No `ds__sensitive_*` model in this repo has a singular
test.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | A zero-minute Category 1 target reports every Category 1 presentation with any measurable wait as a miss: 43 of 43 at Samoa's TTM Hospital in 2026 to date, none met, the fastest being 69 seconds from triage to active care. The compliance column is therefore uninformative for the most urgent category. The register template raises the same point and suggests a short buffer (e.g. 2 minutes) before counting a miss. Confirm which the deployment wants. | timcleasby | Before implemented |

## Lineage

```
ds__encounters_emergency   ──┐
clinical__visit_occurrence ──┤
encounters                 ──┤
encounter_history          ──┼──►  ds__emergency_triage  ──►  emergency-triage-line-list
encounter_diagnoses        ──┤
encounter_prescriptions    ──┤
discharges                 ──┘
```

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-11 | Maui team | Initial spec + implementation (MAUI-6778) |
