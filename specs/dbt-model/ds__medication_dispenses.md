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
| **Last updated** | 2026-09-29 |
| **Consumed by** | `medication-dispensed-summary`, `sensitive-medication-dispensed-summary` |

## Purpose

One row per pharmacy dispense, with the patient, the dispensing facility, and the drug actually handed over, so the dispensed-summary reports read a single definition of "what was dispensed". Both variants are built by the shared `medication_dispenses_dataset(is_sensitive)` macro (`macros/datasets/medication_dispenses.sql`).

This spec was written retrospectively for MAUI-6945, which fixed the drug resolution. Only the medication clauses are numbered; the rest of the dataset is described as built.

## Grain

One row per non-deleted `medication_dispenses` row that the `medication_dispenses` base keeps: its pharmacy order prescription, pharmacy order and encounter are not deleted, and the encounter is not the test patient's. The dispense's prescription must also be kept by the `prescriptions` base (BL-005). The standard variant keeps dispenses at non-sensitive facilities, and the sensitive variant keeps those at sensitive facilities. The facility is the pharmacy order's facility.

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

- **BL-001:** `medication_id` is `medication_dispenses.medication_id`. From Tamanu v2.61 every dispense records its own drug: it is copied from the prescription, or it is the substituted drug when pharmacy uses "Modify prescription" while dispensing. Tamanu v2.61 backfills the column on historical dispenses from their prescription. The prescription itself is never changed, so its drug is the pre-modification drug and is not read.
- **BL-002:** The `reference_data` join that supplies `medication_code` and `medication` uses `medication_dispenses.medication_id`, so the name and code always describe the drug in `medication_id`.
- **BL-003:** The `medication_id` column doc describes the dispensed (possibly modified) drug, via `medication_dispenses__medication_id`, not the prescribed one.
- **BL-004:** The logic lives once in `medication_dispenses_dataset()`. The `is_sensitive` parameter covers both variants. Per-deployment repos pick the change up on their next `tamanu-source-dbt` version bump.
- **BL-005:** The dataset inner-joins `prescriptions`, so a dispense whose prescription the `prescriptions` base excludes (deleted, or the test patient's) is dropped.

## Acceptance criteria

| ID | Criterion | Implements |
|---|---|---|
| AC-001 | For a dispense with a pharmacy modification, `medication_id`, `medication` and `medication_code` match `medication_dispenses.medication_id`, not the linked prescription's drug. | BL-001, BL-002 |
| AC-002 | For an unmodified dispense, the output is unchanged. | BL-001 |
| AC-003 | `medication_dispenses.medication_id` is not null on every row of the `medication_dispenses` base, at `warn` severity. A failure means a dispense has no drug of its own and is dropped from the dataset by the `reference_data` join. | BL-001 |
| AC-004 | The same holds for `ds__sensitive_medication_dispenses`, which keeps only sensitive-facility dispenses. | BL-001, BL-002, BL-004 |
| AC-005 | A dispense whose prescription is absent from the `prescriptions` base does not appear. | BL-005 |

AC-001, AC-002 and AC-005 are covered by `test_ds__medication_dispenses_dispensed_drug`, and AC-004 by `test_ds__sensitive_medication_dispenses_dispensed_drug` (both in `data_tests/unit_tests/test_ds__medication_dispenses_dispensed_drug.yml`). AC-003 is the `ac_003_ds__medication_dispenses_medication_id_not_null` data test on the `medication_dispenses` base.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-28 | Maui team | Initial spec, written for MAUI-6945. Drug resolution now prefers the dispense's own `medication_id` over the prescription's, so a prescription modified at dispensing reports the substituted drug (BL-001 to BL-004). |
| 2026-09-29 | Maui team | `medication_id` reads the dispense's own drug with no prescription fallback, since Tamanu v2.61 backfills it on every dispense (BL-001, BL-002, AC-003). The retained `prescriptions` join is documented as a row filter (BL-005, AC-005). |
