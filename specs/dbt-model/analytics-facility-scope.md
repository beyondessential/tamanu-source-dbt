# dbt Spec: analytics facility scope (shared rule)

## Purpose

The analytics layer (OMOP `clinical__` models, `metric__` models, the OMOP intermediates and the
care-site lookups) covers standard facilities only. Data recorded at a sensitive facility, one that
belongs to a sensitive network, does not reach it or the Tupaia data tables and dashboards built on
it. This matches the standard datasets and reports, which already read the standard-only
`facilities` base.

**Who consumes it?** Every `clinical__` and `metric__` model, and the Tupaia data tables and
dashboards built on them. Each model's own spec keeps its other clauses. This spec owns the rule
for which facility decides whether a row is in scope.

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

A row's **deciding facility** is the facility named below for its family. A facility is
**standard** when it is in the `facilities` base, which holds the facilities that belong to no
sensitive network (`models/bases/facilities.sql`).

| Family | Models | Deciding facility |
|---|---|---|
| Encounter events | `clinical__visit_occurrence`, the encounter branch of `clinical__condition_occurrence`, `clinical__drug_exposure`, `clinical__measurement`, `clinical__observation`, `clinical__cost`, and the metrics built on them | the encounter's location's facility |
| Visit segments | `clinical__visit_detail`, `int__emergency_visits`, `int__inpatient_admission`, and the metrics that attribute a row to a segment | the encounter's facility and the segment's location's facility |
| Own location | `clinical__procedure_occurrence`, `metric__ed_procedure`, `int__vaccine_administration_attributes` | the encounter's facility and the row's own location's facility |
| Registry | `int__program_enrolments`, `int__registration_status_history`, `clinical__episode`, the registry branch of `clinical__condition_occurrence`, `metric__program_registry_enrolment` | the registering facility |
| Births | the birth branch of `clinical__measurement`, `metric__birth` | the birth facility |
| Deaths | `metric__death` | the death record's facility, else the facility of the encounter the patient died in (its BL-004) |
| Appointments | `metric__appointment` | the appointment's location group's facility |
| User logins | `metric__user_login` (`active_user`, `user_login`) | the allowed facility on the row |
| WHO DAK forms | `int__who_dak_anc_submissions`, `int__who_dak_anc_contacts`, `int__who_dak_hiv_form_answers` and their indicators | the form's encounter's location's facility, and a contact location group's facility |
| Care sites | `ref__care_site`, `ref__care_site_location` | the care site's own facility |

## Business logic

- **BL-001:** A row whose deciding facility is set but is not a standard facility is excluded.
- **BL-002:** A row with no deciding facility set is kept.
- **BL-003:** Where a family names two deciding facilities, a row is excluded when either is set and not standard.
- **BL-004:** A metric that attributes a row to an encounter or segment covers only the encounters and segments the `clinical__` models keep.
- **BL-005:** A registry row's currently-at facility reads as null when it is set and not standard.
- **BL-006:** `ref__care_site` and `ref__care_site_location` hold location, department and facility care sites at standard facilities only.
- **BL-007:** `clinical__observation_period` spans only the events the other `clinical__` models keep.
- **BL-008:** `clinical__person`, `ref__location` and `ref__provider` carry no facility and are unchanged.
- **BL-009:** The analytics layer has no sensitive variant and never reads `sensitive_facilities`, whatever `has_sensitive_facility` is set to.
- **BL-010:** The `is_sensitive` flags on surveys and lab test types play no part in this scope.

## Acceptance criteria

Each is a dbt unit test on the named model, with a fixture holding one row at a standard facility,
one at a facility absent from the `facilities` stub, and, where the family allows it, one with no
facility.

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `clinical__visit_occurrence` and each encounter-event `clinical__` model drop the event whose encounter is at a non-standard facility | BL-001 | unit test per model |
| AC-002 | `clinical__visit_detail` drops a segment at a non-standard location, and every segment of an encounter at a non-standard facility | BL-001, BL-003 | unit test |
| AC-003 | `clinical__procedure_occurrence` drops a procedure whose own location, or whose encounter, is at a non-standard facility | BL-001, BL-003 | unit test |
| AC-004 | `int__program_enrolments` drops an enrolment registered at a non-standard facility, keeps one with no registering facility, and nulls a non-standard currently-at facility | BL-001, BL-002, BL-005 | unit test |
| AC-005 | `metric__birth` and `metric__death` drop a birth or death at a non-standard facility and keep one with no facility | BL-001, BL-002 | unit test per model |
| AC-006 | `metric__appointment` and `metric__user_login` drop the rows at a non-standard facility | BL-001 | unit test per model |
| AC-007 | `int__who_dak_anc_contacts` and `int__who_dak_hiv_form_answers` drop a form at a non-standard facility and keep one with no facility | BL-001, BL-002 | unit test per model |
| AC-008 | `ref__care_site` holds no care site at a non-standard facility | BL-006 | unit test |
| AC-009 | A metric built on a segment carries no row for a segment `clinical__visit_detail` dropped | BL-004 | unit test on `metric__outpatient_visit` |
| AC-010 | No analytics model depends on `sensitive_facilities` | BL-009 | CI's standard-only parse, where the model is disabled |

## Superseded clauses

The implementation PR revises these alongside the code, so each spec keeps describing the code it
ships with until then.

| Spec | Clause | Change |
|---|---|---|
| `metric__emergency_visit.md` | BL-010 | Drop "with no facility sensitivity filter, so standard and sensitive facilities alike are covered", and point at this spec. |
| `metric__inpatient_admission.md` | BL-010 | The same. |
| `metric__inpatient_transfer.md` | BL-010 | The same. |
| `ref__care_site.md` | BL-003, BL-007 | Care sites at standard facilities only (BL-006), replacing the left join that keeps a care site with no facility name. |
| `clinical__episode.md` | facility clauses | The registering facility decides scope (Registry). |
| `metric__death.md` | BL-004 | Deaths at a non-standard facility excluded, matching `ds__deaths` BL-015. |

Every other model in the Scope table gains a line pointing at this spec in its own facility
clause, in the same PR.

## Lineage

```
facilities (standard only) ──┬──► ref__care_site_location ──► ref__care_site
                             ├──► clinical__visit_occurrence / visit_detail / events ──► metric__*
                             ├──► int__program_enrolments ──► clinical__episode ──► metric__program_registry_enrolment
                             └──► int__who_dak_* ──► metric__who_dak_*_indicators
                                                                     └──► Tupaia data tables
```

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Is one shared helper, such as an ephemeral `int__standard_locations` (locations at standard facilities), the right way to apply BL-001 across about 45 models, rather than a join to `facilities` in each? | Maui team | Before the implementation PR |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-11-22 | Maui team | Initial draft: the analytics layer covers standard facilities only, superseding the "no facility sensitivity filter" clauses. |
