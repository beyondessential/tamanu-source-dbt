# Dataset Spec: `ds__medication_dispenses`

## Identity

| Field | Value |
|---|---|
| **Name** | `ds__medication_dispenses` (and `ds__sensitive_medication_dispenses`) |
| **Type** | Consumer-shaped dataset (`ds__`) |
| **Layer** | `ds__` |
| **Materialisation** | env-aware (view in the production bundle) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Linear issue** | [MAUI-6945](https://linear.app/bes/issue/MAUI-6945) |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-09-28 |
| **Last updated** | 2026-09-28 |
| **Consumed by** | `medication-dispensed-summary`, `sensitive-medication-dispensed-summary` |

## Purpose

One row per pharmacy dispense, with the patient, the dispensing facility, and the drug actually handed over, so the dispensed-summary reports read a single definition of "what was dispensed". Both variants are built by the shared `medication_dispenses_dataset(is_sensitive)` macro (`macros/datasets/medication_dispenses.sql`).

This spec was written retrospectively for MAUI-6945, which fixed the drug resolution. Only the medication clauses are numbered; the rest of the dataset is described as built.

## Grain

One row per non-deleted `medication_dispenses` row that the `medication_dispenses` base keeps: its pharmacy order prescription, pharmacy order and encounter are not deleted, and the encounter is not the test patient's. The standard variant keeps dispenses at non-sensitive facilities, and the sensitive variant keeps those at sensitive facilities. The facility is the pharmacy order's facility.

## Inputs

`ref('medication_dispenses')`, `ref('pharmacy_order_prescriptions')`, `ref('pharmacy_orders')`, `ref('encounters')`, `ref('prescriptions')`, `ref('reference_data')`, `ref('facilities')`.

## Output schema

| Column | Type | Description |
|---|---|---|
| `id` | uuid | `medication_dispenses.id`. Primary key |
| `quantity` | integer | Quantity dispensed |
| `dispensed_at` | timestamp | When the dispense was recorded |
| `patient_id` | text | The encounter's patient |
| `facility_id` | text | The pharmacy order's facility |
| `facility` | text | That facility's name |
| `medication_id` | text | The drug dispensed (BL-001) |
| `medication_code` | text | `reference_data.code` of that drug (BL-002) |
| `medication` | text | `reference_data.name` of that drug (BL-002) |

## Business logic

- **BL-001:** `medication_id` is `coalesce(medication_dispenses.medication_id, prescriptions.medication_id)`. From Tamanu v2.61 a dispense records its own drug: it is copied from the prescription, or it is the substituted drug when pharmacy uses "Modify prescription" while dispensing. The prescription itself is never changed, so reading the prescription's drug reports the pre-modification drug. The prescription's drug is only a fallback for legacy dispenses recorded before the column existed. The `medication_dispenses` base passes the column through for this.
- **BL-002:** The `reference_data` join that supplies `medication_code` and `medication` uses the same coalesced id as BL-001, so the name and code always describe the drug in `medication_id`.
- **BL-003:** The `medication_id` column doc describes the dispensed (possibly modified) drug, via `medication_dispenses__medication_id`, not the prescribed one.
- **BL-004:** The logic lives once in `medication_dispenses_dataset()`. The `is_sensitive` parameter covers both variants. Per-deployment repos pick the change up on their next `tamanu-source-dbt` version bump.

## Acceptance criteria

| ID | Criterion | Implements |
|---|---|---|
| AC-001 | For a dispense with a pharmacy modification, `medication_id`, `medication` and `medication_code` match `medication_dispenses.medication_id`, not the linked prescription's drug. | BL-001, BL-002 |
| AC-002 | For an unmodified dispense, the output is unchanged. | BL-001 |
| AC-003 | For a legacy dispense with `medication_dispenses.medication_id` null, the output falls back to the prescription's drug. | BL-001 |
| AC-004 | The same holds for `ds__sensitive_medication_dispenses`, which keeps only sensitive-facility dispenses. | BL-001, BL-002, BL-004 |

AC-001 to AC-003 are covered by `test_ds__medication_dispenses_dispensed_drug`, and AC-004 by `test_ds__sensitive_medication_dispenses_dispensed_drug` (both in `data_tests/unit_tests/test_ds__medication_dispenses_dispensed_drug.yml`). Both tests fail against the pre-fix macro.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-28 | Maui team | Initial spec, written for MAUI-6945. Drug resolution now prefers the dispense's own `medication_id` over the prescription's, so a prescription modified at dispensing reports the substituted drug (BL-001 to BL-004). |
