# dbt Model Spec: `clinical__episode` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__episode` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics*`) |
| **Status** | `draft` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-08-22 |
| **Last updated** | 2026-08-22 |

The OMOP-lite `EPISODE` domain — one row per patient enrolment in a program registry. Program
registries are how Tamanu tracks a patient over a long-running care programme (HIV, TB, NCD), and
they give the clinical layer its first **longitudinal** subject: every other `clinical__` table
hangs off an encounter. See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

Three companions land in the same change: `int__registration_status_history`, a registry-condition
branch on `clinical__condition_occurrence`, and `ds__patient_program_registrations` rebased onto
this model.

## Purpose

**What this artefact measures.** One row per patient per program registry, in OMOP `EPISODE` shape:
the enrolment as the episode, its start and end, the clinical status the patient currently holds in
that registry, and where they are currently being managed.

**Clinical context.** A Tamanu program registry records that a patient is enrolled in a programme
and carries their position within it — a configurable clinical status list (for HIV: diagnosed not
on ART, on ART, ART interrupted, lost to follow up, transferred out, died), the facility or village
they currently attend, and the conditions tracked alongside the enrolment. Enrolment is not an
encounter: it spans one, and a patient can be enrolled for years.

**Who reads it.** `derived__cohort_*` (a registry is the most direct cohort definition Tamanu
offers), `metric__` programme indicators needing an enrolled denominator — retention, treatment
coverage, loss to follow-up — and `ds__patient_program_registrations`.

## Grain

**One row per:** patient per program registry.

`patient_program_registrations.id` is a deterministic composite of the patient and registry ids
(`<patient_id>;<program_registry_id>`, assigned before insert), so the source table holds current
state and is updated in place rather than appended to. `id` carries a `unique` test at source. The
joins here (→ `program_registries`, → `program_registry_clinical_statuses`, → `facilities`, →
`reference_data`, → `int__registration_status_history`) are all many-to-one, so grain is preserved.

## Inputs

| Reference | Why we need it |
|---|---|
| `{{ ref('patient_program_registrations') }}` | The enrolment: patient, registry, status, dates, currently-at |
| `{{ ref('program_registries') }}` | Registry name and code; `currently_at_type` decides which currently-at column is meaningful |
| `{{ ref('program_registry_clinical_statuses') }}` | Clinical status name and code |
| `{{ ref('programs') }}` | The program the registry belongs to |
| `{{ ref('facilities') }}` | Registering facility, and currently-at facility |
| `{{ ref('reference_data') }}` | Currently-at village |
| `{{ ref('int__registration_status_history') }}` | When the registration became `inactive`, for the episode end (BL-004) |

`bases/patient_program_registrations` already excludes soft-deleted rows and the test patient.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `episode_id` | text | `patient_program_registrations.id`. Native composite key — no remap to OMOP integer ids (D1) |
| `person_id` | uuid | `patient_id`. FK to `clinical__person.person_id` |
| `episode_concept_id` | int | NULL — deferred to the future `vocab__` layer (D2) |
| `episode_start_date` | date | Date component of the enrolment datetime |
| `episode_start_datetime` | timestamp | `patient_program_registrations.datetime`. Non-null |
| `episode_end_date` | date | Date component of `episode_end_datetime` |
| `episode_end_datetime` | timestamp | Deactivation, or the logged transition to `inactive` (BL-004). NULL while open |
| `episode_end_source` | text | `deactivation`, `status change` or NULL — which rule closed the episode |
| `episode_object_concept_id` | int | NULL — deferred to `vocab__` |
| `episode_type_source_value` | text | Constant `'program registry'` — provenance and union discriminator |
| `episode_source_value` | text | `program_registries.code` — the registry the patient is enrolled in |
| `episode_source_name` | text | `program_registries.name` |
| `program_id` | text | `programs.id` — the program the registry belongs to |
| `episode_number` | int | NULL — a patient holds at most one episode per registry |
| `registration_status` | text | `active` or `inactive` |
| `clinical_status_source_value` | text | `program_registry_clinical_statuses.code`; NULL when no status is set |
| `clinical_status_source_name` | text | `program_registry_clinical_statuses.name` |
| `currently_at_type` | text | `facility` or `village`, from the registry's configuration |
| `currently_at_id` | text | The facility or village id, whichever `currently_at_type` names |
| `currently_at_name` | text | Resolved name of that facility or village |
| `care_site_id` | uuid | `registering_facility_id`. FK to `ref__care_site.care_site_id` |
| `provider_id` | uuid | `registered_by_id`. FK to `ref__provider.provider_id` |
| `deactivated_by_provider_id` | uuid | `deactivated_by_id`; NULL while the episode is open |

## Business logic

- **BL-001:** One row per patient per program registry, taken from
  `bases/patient_program_registrations` without deduplication — the source id is a composite of
  patient and registry and is unique.
- **BL-002:** Rows with `registration_status = 'recordedInError'` are excluded; that enrolment is a
  data-entry mistake rather than a clinical fact.
- **BL-003:** `episode_start_datetime` is the registration `datetime`, and is never NULL.
- **BL-004:** `episode_end_datetime` is `deactivated_datetime` when set, otherwise the `logged_at`
  of the earliest `int__registration_status_history` entry in which the registration became
  `inactive`. `episode_end_source` records which of the two applied.
- **BL-005:** An episode is open — both end columns NULL — when the registration is `active`.
- **BL-006:** A registration that is `inactive` with no `deactivated_datetime` and no qualifying
  history entry has a NULL end and reads as open, which happens when the transition predates the
  change log's coverage floor (BL-015).
- **BL-007:** `currently_at_id` and `currently_at_name` resolve from `facility_id` when the
  registry's `currently_at_type` is `facility`, and from `village_id` when it is `village`. The
  other column is ignored even when populated, since only the configured one is maintained.
- **BL-008:** `clinical_status_source_value` is the status currently held; a status a patient passed
  through is visible only in `int__registration_status_history`.
- **BL-009:** `*_concept_id` columns are emitted as NULL, pending the `vocab__` layer (D2).
- **BL-010:** `episode_number` is NULL: the composite source key admits at most one episode per
  patient per registry, so there is no sequence to number.
- **BL-011:** Registry, clinical status, facility, village and history joins are `left join` — an
  enrolment with no clinical status set, or no registering facility, is still a valid enrolment.

### `int__registration_status_history`

**Grain.** One row per recorded change to a registration.

**Why it exists.** `patient_program_registrations` is updated in place, so a patient's passage
through the clinical status list — and the moment a registration became `inactive` — is recoverable
only from `bases/patient_program_registrations_change_logs`. Retention and loss-to-follow-up are
questions about transitions rather than current state.

- **BL-012:** One row per change-log entry, ordered by `logged_at` within a registration.
- **BL-013:** `registration_status` and `clinical_status_id` are the values as at that entry, read
  from the logged record snapshot.
- **BL-014:** The current state also appears as the final row, so a status held now is visible in
  the history without joining back to `clinical__episode`.
- **BL-015:** Change-log coverage begins at Tamanu 2.33.0, the base model's floor. A registration
  changed before that release has no history for the change, so its first history row is not
  necessarily its enrolment.
- **BL-016:** Sourced only from `bases/` (D10) — the change-log base already excludes the test
  patient.

### Registry conditions in `clinical__condition_occurrence`

Registry conditions become a second branch of `clinical__condition_occurrence`, resolving OQ-1 in
that model's spec. Its clauses live there; the shape differs from encounter diagnoses in five ways.

- **BL-017:** `visit_occurrence_id` is NULL — a registry condition is recorded against the
  enrolment, not an encounter.
- **BL-018:** `person_id` comes from `patient_program_registrations.patient_id` via
  `patient_program_registration_conditions.patient_program_registration_id`.
- **BL-019:** `condition_status_source_value` is the condition category code (`confirmed`,
  `suspected`, `resolved`, …), the registry's equivalent of encounter-diagnosis certainty.
- **BL-020:** `condition_type_source_value` is the constant `'program registry condition'`,
  distinguishing the branch from `'encounter diagnosis'`.
- **BL-021:** Conditions with a `deletion_date` are excluded.

### `ds__patient_program_registrations` rebased

The dataset currently reads `bases/` directly and resolves currently-at itself, duplicating
BL-007. It is rebased so the enrolment facts have one definition.

- **BL-022:** Enrolment facts — registration status and datetime, clinical status, currently-at,
  registering facility, registered-by, deactivation — are read from `clinical__episode`.
- **BL-023:** Patient demographics, `patient_additional_data` contact and administrative columns,
  and the related-condition aggregation stay in the dataset: they are Tupaia presentation concerns
  and not part of the OMOP episode.
- **BL-024:** The dataset's output columns and their names are unchanged, so consumers see no
  difference.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `episode_id` is unique and not null | BL-001 | dbt `unique`, `not_null` |
| AC-002 | `registration_status` is `active` or `inactive` only | BL-002 | `accepted_values` |
| AC-003 | `episode_start_datetime` is not null | BL-003 | dbt `not_null` |
| AC-004 | `episode_end_datetime >= episode_start_datetime` where the end is not null | BL-004 | `dbt_utils.expression_is_true` |
| AC-005 | `episode_end_source` is `deactivation` exactly when `deactivated_datetime` is set, and `status change` exactly when the end came from history | BL-004 | singular test |
| AC-006 | `episode_end_date` is null exactly when `episode_end_datetime` is null | BL-004, BL-005 | singular test |
| AC-007 | Every `active` registration has both end columns null | BL-005 | singular test |
| AC-008 | `currently_at_id` is null whenever the registry's `currently_at_type` is null | BL-007 | singular test |
| AC-009 | `currently_at_type` is `facility`, `village`, or null | BL-007 | `accepted_values` |
| AC-010 | Every `person_id` appears in `clinical__person` | BL-001 | dbt `relationships` |
| AC-011 | Every non-null `care_site_id` appears in `ref__care_site` | BL-011 | `relationships` |
| AC-012 | Row count equals the source count of non-`recordedInError`, non-deleted registrations | BL-001, BL-002 | singular test |
| AC-013 | `(episode_id, logged_at)` is unique in the history | BL-012 | `dbt_utils.unique_combination_of_columns` |
| AC-014 | Every history `episode_id` appears in `clinical__episode` | BL-012 | `relationships` |
| AC-015 | Each registration's latest history row matches `clinical__episode`'s current status | BL-014 | singular test |
| AC-016 | An `inactive` registration with no `deactivated_datetime` has an end iff a qualifying history entry exists | BL-004, BL-006 | singular test |
| AC-017 | `ds__patient_program_registrations` emits the same column set as before the rebase | BL-024 | singular test asserting the column list |
| AC-018 | `episode_concept_id`, `episode_object_concept_id` and `episode_number` are always null | BL-009, BL-010 | singular test |
| AC-019 | Registry-condition rows have a null `visit_occurrence_id`, and encounter-diagnosis rows do not | BL-017 | singular test on `clinical__condition_occurrence` |
| AC-020 | `condition_type_source_value` is `encounter diagnosis` or `program registry condition` | BL-020 | `accepted_values` |
| AC-021 | No registry-condition row corresponds to a source row with a `deletion_date` | BL-021 | singular test |
| AC-022 | Every registry-condition `person_id` appears in `clinical__person` | BL-018 | `relationships` |
| AC-023 | `ds__patient_program_registrations` row count equals `clinical__episode` row count | BL-022 | singular test |
| AC-024 | Registry-condition `condition_status_source_value` values all appear in `program_registry_condition_categories.code` | BL-019 | `relationships` |
| AC-025 | `ds__patient_program_registrations` still emits the patient, contact and related-condition columns | BL-023 | covered by AC-017's column-list assertion |

BL-013, BL-015 and BL-016 carry no acceptance criterion: the first two describe what the change log
can and cannot show, and the third is a sourcing rule enforced by review rather than by a test.
BL-008 is asserted indirectly by AC-015, which pins the history's final row to the current status.

## Lineage

```
bases/patient_program_registrations ──┬──►  clinical__episode  ──┬──►  derived__cohort_*
bases/program_registries            ──┤          ▲               ├──►  metric__ programme indicators
bases/program_registry_clinical_...  ─┘          │               └──►  ds__patient_program_registrations
                                                 │
bases/patient_program_registrations_change_logs ─┴──►  int__registration_status_history

bases/patient_program_registration_conditions   ──►  clinical__condition_occurrence
                                                       (second branch, resolves its OQ-1)
```

## Open questions

| ID | Question | Owner | Due |
|---|---|---|---|
| OQ-001 | Whether the episode hierarchy below should be emitted, and whether eras belong in `derived__` rather than here. See below. | Data Lead | deferred |

### OQ-001 — episode hierarchy and treatment eras

OMOP's `EPISODE` carries an `episode_parent_id`, so episodes nest: a disease episode holds
treatment episodes beneath it, sequenced by `episode_number`. OHDSI uses this in oncology — a
cancer episode, treatment-regimen episodes under it, cycles under those. This model emits neither
column (BL-010), so every episode is flat and standalone.

The shape it would model for HIV is an **ART regimen era**: the enrolment as the parent, and one
child episode per regimen line, `episode_number` counting first-line, second-line, third-line. That
is a real analytic object rather than a hypothetical one — the DAK's Annex C indicators ART.8, ART.9
and VER.3 are all keyed on regimen, and Annex A carries the inputs (`HIV.D.DE444` regimen
prescribed, `HIV.D.DE418` reason for substitution, `HIV.D.DE466` treatment-limiting toxicity).

Three things block it, and they are worth stating because they decide *when* rather than *whether*:

1. **The regimen answers are not yet coded.** The DAK leaves the regimen list country-configured
   (Table 13), so `HIV.D.DE75` and `HIV.D.DE444` are emitted as free text in the WHO-DAK HIV forms.
   An era boundary computed by comparing free-text regimen strings across visits would be wrong in a
   way that is invisible downstream. A deployment supplying a local coded list removes this.
2. **An era is a derived element, not a clinical fact.** OMOP puts `drug_era` and `condition_era` in
   its Standardized Derived Elements category, which maps to this repo's `derived__` layer (D2).
   A regimen era assembled by collapsing consecutive same-regimen observations belongs there,
   alongside the cohorts, rather than in `clinical__` beside the enrolment it hangs off.
3. **One episode source.** `episode_parent_id` with a single source is a column that is always
   NULL. It earns its place when the second source exists.

Until then, regimen history is answerable from `clinical__observation` (the regimen answers) joined
to `clinical__episode` (the enrolment) — the same question, without a hierarchy to maintain.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-22 | Maui team | Initial draft. Episode end resolves through the change log rather than `deactivated_datetime` alone; `ds__patient_program_registrations` rebased onto this model so currently-at has one definition. |
