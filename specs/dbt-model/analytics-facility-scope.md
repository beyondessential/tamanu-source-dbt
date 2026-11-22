# dbt Spec: analytics facility scope (shared rule)

## Purpose

The OMOP layer (`clinical__` models, the OMOP intermediates and the care-site lookups) covers
every facility, standard and sensitive, so a program model a deployment builds on it sees all of
its data. A `metric__` model classified `internal` covers standard facilities only, so a general
Tupaia data table never counts activity at a sensitive facility, one that belongs to a sensitive
network. So does `metric__death`, which matches the standard deceased patients report. Every other
`metric__` model classified `restricted` covers every facility, and its data table names its
permission group explicitly.

**Who consumes it?** Every `clinical__` and package `metric__` model, the deployment models built
on them, and the Tupaia data tables built on those. Each model's own spec keeps its other clauses.
This spec owns the rule for which facilities a model covers.

## Identity

| Field | Value |
|---|---|
| **Name** | analytics facility scope |
| **Type** | shared rule across dbt models (no model of its own) |
| **Layer** | `clinical__`, `metric__`, `models/intermediate/omop/`, `ref__care_site`, `ref__care_site_location` |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-11-22 |
| **Last updated** | 2026-11-22 |

## Scope

A facility is **standard** when it is in the `facilities` base, and **sensitive** when it is in
the `sensitive_facilities` base, which is enabled only where `has_sensitive_facility` is true.

| Group | Models | Facilities covered |
|---|---|---|
| OMOP layer | every `clinical__` model, `models/intermediate/omop/`, `ref__care_site`, `ref__care_site_location` | every facility |
| Standard-only metrics | each package `metric__` model whose `classification` is `internal`: `appointment`, `billing`, `ed_imaging_request`, `ed_lab_order`, `ed_pharmacy_order`, `ed_procedure`, `emergency_stay`, `emergency_visit`, `encounter`, `encounter_diagnosis`, `imaging_request`, `inpatient_admission`, `inpatient_transfer`, `ipd_diagnosis`, `lab_order`, `medication_administration`, `medication_dispense`, `opd_diagnosis`, `opd_visit_department`, `outpatient_visit`, `pharmacy_order`, `prescription`, `prescription_discontinuation`, `procedure`, `user_login`; and `death` | standard facilities only |
| Restricted metrics | each other package `metric__` model whose `classification` is `restricted`: `birth`, `immunisation_dose`, `immunisation_refusal`, `patient_condition`, `program_registry_enrolment`, `who_dak_anc_indicators`, `who_dak_hiv_indicators` | every facility |

A metric implemented in a deployment repo follows its own canonical spec, as `metric__hiv_testing`
BL-007 and `metric__sti_screening` BL-006 do.

## Business logic

- **BL-001:** A standard-only metric excludes a row whose `facility_id` is set and is not a standard facility.
- **BL-002:** A standard-only metric keeps a row whose `facility_id` is null.
- **BL-003:** The facility BL-001 tests is the `facility_id` the metric emits, as its own spec attributes it.
- **BL-004:** A standard-only metric tests standard facilities against the `facilities` base only and never reads `sensitive_facilities`.
- **BL-005:** A restricted metric other than `metric__death` covers every facility.
- **BL-006:** The `clinical__` models and the OMOP intermediates cover every facility.
- **BL-007:** Where `has_sensitive_facility` is true, `ref__care_site`, `ref__care_site_location` and `int__program_enrolments` read facility names and types from `facilities` and `sensitive_facilities` together, and from `facilities` alone otherwise.
- **BL-008:** Where `has_sensitive_facility` is true, `ref__care_site` holds a facility care site for every standard and sensitive facility.
- **BL-009:** A new package `metric__` model takes its facility scope from its `classification`, by BL-001 or BL-005.
- **BL-010:** The `is_sensitive` flags on surveys and lab test types play no part in this scope.
- **BL-011:** `metric__death` is a standard-only metric, so it covers the same deaths as `ds__deaths` (`deceased-patients-line-list.md` BL-015).

## Acceptance criteria

Unit-test fixtures hold one row at a standard facility, one at a facility in the
`sensitive_facilities` stub and absent from the `facilities` stub, and, where the model allows it,
one with no facility. CI runs unit tests with `has_sensitive_facility` true.

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `metric__encounter`, `metric__emergency_visit`, `metric__user_login` and `metric__death` drop the sensitive-facility row and keep the standard and null-facility rows | BL-001, BL-002, BL-003, BL-011 | unit test per model |
| AC-002 | No standard-only metric emits a `facility_id` that is in `sensitive_facilities` | BL-001 | singular data test `model_invariants/data_test__analytics_facility_scope.sql`, gated on `has_sensitive_facility` |
| AC-003 | `metric__who_dak_hiv_indicators` and `metric__birth` keep the sensitive-facility row | BL-005 | unit test per model |
| AC-004 | `clinical__visit_occurrence` keeps an encounter at a sensitive facility | BL-006 | unit test |
| AC-005 | `ref__care_site_location` names a location's sensitive facility, and `ref__care_site` holds that facility's care site | BL-007, BL-008 | unit test |
| AC-006 | With `has_sensitive_facility` false the project parses, and no standard-only metric depends on `sensitive_facilities` | BL-004, BL-007 | CI's standard-only parse |

## Superseded clauses

The implementation PR revises these alongside the code, so each spec keeps describing the code it
ships with until then.

| Spec | Clause | Change |
|---|---|---|
| `metric__emergency_visit.md` | BL-010 | Replace "with no facility sensitivity filter, so standard and sensitive facilities alike are covered" with standard facilities only, pointing at this spec. |
| `metric__inpatient_admission.md` | BL-010 | The same. |
| `metric__inpatient_transfer.md` | BL-010 | The same. |
| `metric__death.md` | BL-004 | A death at a sensitive facility is excluded, as in `ds__deaths` (BL-011). |
| `ref__care_site.md` | BL-003, BL-007 | Facility names and facility care sites come from both bases where `has_sensitive_facility` is true (BL-007, BL-008). |

Every other standard-only metric's spec gains a line pointing at this spec in the same PR.

## Lineage

```
facilities ─────────────┬──────────────────────────────► standard-only metric__* ──► general data tables
sensitive_facilities ───┴─(has_sensitive_facility)─► ref__care_site_location / ref__care_site / int__program_enrolments
                                                         │
                                         clinical__* ────┴──► restricted metric__* ──► permissioned data tables
                                                         └──► deployment program metrics
```

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Should BL-001 be one shared macro applied to each standard-only metric's final select, and BL-007 one ephemeral model holding both bases, rather than the same SQL repeated in each model? | Maui team | Before the implementation PR |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-22 | Maui team | Initial draft: the OMOP layer and restricted metrics cover every facility, and internal metrics and `metric__death` cover standard facilities only, superseding the "no facility sensitivity filter" clauses. |
