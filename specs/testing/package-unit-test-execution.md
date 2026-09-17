# Testing Spec: package unit test execution

## Identity

| Field | Value |
|---|---|
| **Name** | `package-unit-test-execution` |
| **Type** | testing architecture (no model of its own) |
| **Layer** | cross-repo — `tamanu-source-dbt` CI and every `tamanu-dbt-*` deployment |
| **Materialisation** | n/a |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-09-17 |
| **Last updated** | 2026-09-17 |

The package's dbt unit tests run in the package's own CI against package-standard
translations, and do not run in deployment repos.

## Purpose

A report model aliases each output column with `translate_label()`, so the translated
label *is* the column identifier — it is what Tamanu presents to users and what a unit
test fixture must name in its `expect` block. Deployments localise those labels. A
fixture written against the package's standard labels therefore fails in every
deployment that localises the columns it asserts, reporting a defect in the deployment
that does not exist.

These tests assert package logic against package fixtures. They are meaningful only
where the package's own translations apply, which is the package repo.

## Scope

Applies to every unit test shipped in `tamanu-source-dbt` under `data_tests/unit_tests/`
and `models/unit_tests/`. Does not apply to data tests, which remain deployment-relevant
and continue to run everywhere.

## Constraints

These are properties of dbt and of the report layer, not choices this spec makes. They
bound the available solutions.

- A dbt unit test targets a model. It cannot target a macro.
- A unit test fixture renders without the macro namespace: `translate_label()` and
  `get_translations()` raise `is undefined` inside a `given` or `expect` block.
  `var()` renders.
- A unit test `expect` block must supply every column the model outputs. dbt projects the
  model's full output column list onto both sides of its comparison, so a fixture naming a
  subset fails with `column "<name>" does not exist`.
- `parameter()` emits a `:name` bind placeholder under `dbt compile`, and the compiled
  report bundle depends on those placeholders reaching the final report query. A view
  cannot carry a bind placeholder, so a parameterised predicate cannot move out of the
  report model into a separately materialised one.

The last constraint is why extracting an untranslated intermediate does not make report
logic testable without translation. `encounter_summary_core` already separates the
untranslated body from the presentation layer, and the `encounter-summary-*` unit tests
still assert translated columns, because the core is a macro inlined into one compiled
query rather than a model of its own.

## Current localisation

Effective labels under `language: en`, against the package standard:

| Label | Deployment | Standard | Deployment value |
|---|---|---|---|
| `patientDisplayId` | samoa | Patient ID | NHN |
| `patientDisplayId` | nauru | Patient ID | MRID |
| `patientBillingType` | fsm | Billing type | Patient type |
| `patientDivision` | fsm | Division | State |
| `patientSubDivision` | fsm | Sub-division | Municipality |
| `patientPrimaryContactNumber` | fsm | Primary contact number | Cell phone number |
| `patientSubDivision` | msf-kule | Sub-division | Location |
| `patientVillage` | msf-kule | Village | Woreda |
| `prescriptionRoute` | msf-kule | Route | Route of administration |
| `encounterPrescriptionMedication` | msf-kule | Medication | Dispensing medication |
| `patientBirthCertificate` | msf-kule | Birth certificate | Other patient ID |
| `encounterPrescriptionMedication` | msf-syria | Medication | Drug |

Deployment CSVs carry a `stringId,default,en` schema; the standard CSV carries
`stringId,default`. Every deployment above sets `language: en`, so the `en` column is the
live value and `default` is the fallback.

## Business logic

- **BL-001:** The package's unit tests execute in `tamanu-source-dbt` CI on every pull request.
- **BL-002:** That CI job resolves translations from `csv/report_translations_standard.csv` alone.
- **BL-003:** That CI job runs against an ephemeral Postgres created for the job.
- **BL-004:** A deployment repo excludes the `tamanu_source_dbt` package from its unit test selection, via `--exclude package:tamanu_source_dbt`.
- **BL-005:** A deployment repo's `dbt test` run continues to select that deployment's own unit tests and every data test.
- **BL-006:** No unit test fixture names a translated column through a dbt variable.
- **BL-007:** A deployment that localises a label changes only its own translation CSV.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `dbt test --select "unit_test:*"` reports zero failures in package CI | BL-001, BL-002, BL-003 | CI job |
| AC-002 | `dbt test --select "unit_test:*"` in `tamanu-dbt-samoa`, `tamanu-dbt-fsm` and `tamanu-dbt-msf-kule` selects no `tamanu_source_dbt` unit test | BL-004 | manual verification per repo |
| AC-003 | A deployment holding its own unit tests still selects them under that same command | BL-005 | manual verification |
| AC-004 | `patient_display_id_label` appears nowhere in `tamanu-source-dbt` or any deployment repo | BL-006 | grep |
| AC-005 | A deliberately broken fixture fails the package CI job | BL-001 | negative control, run once |

## Rollout

Ordered — each step depends on the one before.

1. Add the package CI job (BL-001 to BL-003). Until this lands the tests have no home.
2. Exclude package unit tests in each deployment repo (BL-004, BL-005), by adding
   `--exclude package:tamanu_source_dbt` to the repo's documented pre-commit `dbt test`
   command in its `AGENT.md`.
3. Revert the `patient_display_id_label` parameterisation and replace the `AGENT.md`
   guidance that prescribes it (BL-006, BL-007). Both live on all seven version branches,
   so this step is itself a forward-port.

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Does anything need to replace the incidental coverage a deployment loses, beyond the `dbt compile` it already runs? | Maui team | before step 2 |
| OQ-002 | Does step 2 land as a fleet fan-out across the 15 deployment repos, or per-repo as each is next touched? | Maui team | before step 2 |

## Divergence from current code

| ID | Divergence | Resolution |
|---|---|---|
| DV-001 | `data_tests/unit_tests/` fixtures name the patient identifier column through `var('patient_display_id_label', 'Patient ID')`, on `2.54`, `2.57`, `2.60`, `2.61`, `2.62`, `2.63` and `main` | Restore the literal standard label on all seven branches |
| DV-002 | `AGENT.md` § Translation system prescribes that parameterisation as the pattern for any fixture asserting a translated column, on the same seven branches, and names Nauru's `MRID` as a `default` override when it is an `en` column value | Replace with the constraint alone, pointing at this spec, on all seven branches |
| DV-003 | `.github/workflows/checks.yml` runs pytest and the generated-macro drift guard only, so no dbt unit test runs in CI | Add the job in step 1 |
| DV-004 | Deployment repos select the package's unit tests, which fail wherever the deployment localises an asserted column | Add the exclusion in step 2 |
| DV-005 | `report_translations_msf_ethiopia.csv` leaves `default` blank for `patientSubDivision`, `patientVillage` and `prescriptionRoute`, so a fallback to `default` renders `as ""`, which Postgres rejects as a zero-length delimited identifier | Out of scope — raise separately |

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-17 | Maui team | Initial draft |
