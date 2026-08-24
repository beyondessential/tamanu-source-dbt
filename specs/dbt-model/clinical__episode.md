# dbt Model Spec: `clinical__episode` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `clinical__episode` |
| **Type** | dbt model (canonical definition) |
| **Layer** | `clinical` |
| **Materialisation** | env-aware — `view` in the production bundle (`reporting_*`), `table` on the replica (`analytics*`) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |
| **Created** | 2026-08-22 |
| **Last updated** | 2026-08-24 |

The OMOP-lite `EPISODE` domain — one row per patient enrolment in a program registry. Program
registries are how Tamanu tracks a patient over a long-running care programme (HIV, TB, NCD), and
they give the clinical layer its first **longitudinal** subject: every other `clinical__` table
hangs off an encounter. See
[D1](../../.maui/knowledge/architecture/data-architecture/decisions.md) (OMOP-lite),
[D2](../../.maui/knowledge/architecture/data-architecture/decisions.md) (layer mapping),
[D10](../../.maui/knowledge/architecture/data-architecture/decisions.md) (sources from `bases/`).

**Layer.** OMOP categorises `EPISODE` under Standardized Derived Elements, which D2 maps to
`derived__`. This model sits in `clinical__` for usage simplicity, as
`clinical__observation_period` does for the same reason: its rows are asserted, one per source
record, with nothing computed, where `derived__` is for computed analytic constructs. The
`derived__episode_<name>` slot stays reserved for what
[`derived-elements-conventions.md`](../../.maui/knowledge/standards/derived-elements-conventions.md)
describes — clinically meaningful multi-domain sequences — which an enrolment is not.

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
`reference_data`, → `patients`, → `int__registration_status_history`) are all many-to-one, so grain is preserved;
the history is aggregated to one row per registration before it is joined.

## Inputs

| Reference | Why we need it |
|---|---|
| `{{ ref('patient_program_registrations') }}` | The enrolment: patient, registry, status, dates, currently-at |
| `{{ ref('program_registries') }}` | Registry name, code and program; `currently_at_type` decides which currently-at column is meaningful |
| `{{ ref('program_registry_clinical_statuses') }}` | Clinical status name and code |
| `{{ ref('facilities') }}` | Registering facility, and currently-at facility |
| `{{ ref('patients') }}` | Scopes the model to the people `clinical__person` carries (BL-001) |
| `{{ ref('reference_data') }}` | Currently-at village |
| `{{ ref('int__program_enrolments') }}` | The enrolment facts, resolved once and shared with the dataset (BL-026) |
| `{{ ref('int__registration_status_history') }}` | When the registration became `inactive`, for the episode end (BL-004) |

`bases/patient_program_registrations` already excludes soft-deleted rows and the test patient.

## Output schema

| Column | Type | Notes |
|---|---|---|
| `episode_id` | text | `patient_program_registrations.id`. Native composite key — no remap to OMOP integer ids (D1) |
| `person_id` | text | `patient_id`. FK to `clinical__person.person_id` |
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
| `program_registry_id` | text | `program_registry_id` — the registry key itself, for a consumer joining back to its configuration |
| `program_id` | text | `program_registries.program_id` — the program the registry belongs to |
| `episode_parent_id` | text | NULL — no parent; children arrive as `derived__episode_*` (OQ-001) |
| `episode_number` | int | NULL — a patient holds at most one episode per registry |
| `registration_status` | text | `active` or `inactive` |
| `clinical_status_id` | text | `clinical_status_id`; NULL when no status is set |
| `clinical_status_source_value` | text | `program_registry_clinical_statuses.code`; NULL when no status is set |
| `clinical_status_source_name` | text | `program_registry_clinical_statuses.name` |
| `currently_at_type` | text | `facility` or `village`, from the registry's configuration |
| `currently_at_id` | text | The facility or village id, whichever `currently_at_type` names |
| `currently_at_name` | text | Resolved name of that facility or village |
| `care_site_id` | text | `registering_facility_id`. FK to `ref__care_site.care_site_id`, resolving to a `care_site_type = 'facility'` row (BL-011) |
| `provider_id` | text | `registered_by_id`. FK to `ref__provider.provider_id` |
| `deactivated_datetime` | timestamp | `deactivated_datetime` as recorded — the source fact, not the boundary; `episode_end_datetime` can differ (BL-004, BL-005) |
| `deactivated_by_provider_id` | text | `deactivated_by_id` as recorded — like `deactivated_datetime` a source fact, so a reactivated enrolment keeps it (BL-005) |

## Business logic

- **BL-001:** One row per patient per program registry, taken from
  `bases/patient_program_registrations` without deduplication — the source id is a composite of
  patient and registry and is unique. The population is the enrolments belonging to a patient
  `bases/patients` carries, which excludes the soft-deleted, the test patient and any record
  merged away (`visibility_status = 'merged'`).
- **BL-002:** Rows with `registration_status = 'recordedInError'` are excluded; that enrolment is a
  data-entry mistake rather than a clinical fact.
- **BL-003:** `episode_start_datetime` is the registration `datetime`, and is never NULL.
- **BL-004:** Only an `inactive` registration ends: `episode_end_datetime` is
  `deactivated_datetime` when set, otherwise the `logged_at` of the earliest
  `int__registration_status_history` entry sourced from the change log in which the registration
  became `inactive`, with `episode_end_source` recording which of the two applied. The synthetic
  current-state row (BL-014) never qualifies, being stamped at the enrolment datetime where
  nothing was logged.
- **BL-005:** An episode is open — both end columns and `episode_end_source` NULL — whenever the
  registration is `active`. BL-005 takes precedence over BL-004: an active registration is open
  even where a `deactivated_datetime` survives on the record, which a reactivation leaves behind.
  `deactivated_datetime` is emitted unchanged so the stamp is still visible.
- **BL-006:** A registration that is `inactive` with no `deactivated_datetime` and no qualifying
  logged history entry has a NULL end and reads as open, which happens when the transition
  predates the change log's coverage floor (BL-015).
- **BL-007:** `currently_at_id` and `currently_at_name` resolve from `facility_id` when the
  registry's `currently_at_type` is `facility`, and from `village_id` when it is `village`. The
  other column is ignored even when populated, since only the configured one is maintained.
- **BL-008:** `clinical_status_source_value` is the status currently held; a status a patient passed
  through is visible only in `int__registration_status_history`.
- **BL-009:** `*_concept_id` columns are emitted as NULL, pending the `vocab__` layer (D2).
- **BL-010:** `episode_parent_id` and `episode_number` are emitted as NULL: the composite source
  key admits at most one episode per patient per registry, so there is neither a parent nor a
  sequence to number. Both columns are present for schema conformance (OQ-001).
- **BL-011:** Clinical status, facility, village and history joins are `left join` — an enrolment
  with no clinical status set, or no registering facility, is still a valid enrolment, though
  every non-null `provider_id` and `deactivated_by_provider_id` is a `ref__provider` (AC-027).
  Two joins are not lookups and so are inner: `patients`, the population filter of BL-001, and
  `program_registries`, since an enrolment is an enrolment *in a registry* and one whose registry
  has been deleted is modelled by neither consumer (AC-012).

  `care_site_id` is the registering facility, which is a coarser care site than the location a
  visit carries — an enrolment is registered at a facility and never at a room. `ref__care_site`
  gained a `care_site_type = 'facility'` grain (its BL-007) so this FK resolves inside the
  reference layer: D2 has `clinical__` models join `ref__` wrappers rather than bases, which is
  what keeps the layer contract intact and the models portable across OMOP tooling.

### `int__registration_status_history`

**Grain.** One row per recorded change to a registration.

**Why it exists.** `patient_program_registrations` is updated in place, so a patient's passage
through the clinical status list — and the moment a registration became `inactive` — is recoverable
only from `bases/patient_program_registrations_change_logs`. Retention and loss-to-follow-up are
questions about transitions rather than current state.

- **BL-012:** One row per change-log entry per registration, ordered by `logged_at` and collapsed
  to one where two entries share an instant. Entries are scoped to the registrations
  `clinical__episode` models, so a recorded-in-error enrolment (BL-002) contributes no history and
  every history row belongs to an episode (AC-014).
- **BL-013:** `registration_status` and `clinical_status_id` are the values as at that entry, read
  from the logged record snapshot.
- **BL-014:** The current state also appears as the final row, so a status held now is visible in
  the history without joining back to `clinical__episode`. Where the latest logged entry already
  says what the registration says now, that entry is the final row and names the user who acted;
  where the two disagree — a log missing an entry — both are kept at that instant and current
  state sorts last, so the divergence shows in the history without discarding a logged change
  BL-004 may need.
- **BL-015:** Change-log coverage begins at Tamanu 2.33.0, the base model's floor. A registration
  changed before that release has no history for the change, so its first history row is not
  necessarily its enrolment.
- **BL-016:** Sourced only from `bases/` (D10) — the change-log base already excludes the test
  patient and floors coverage at Tamanu 2.33.0. `history_source` distinguishes a logged change
  from the synthetic current-state row, which BL-004 depends on.

### Registry conditions in `clinical__condition_occurrence`

Registry conditions become a second branch of `clinical__condition_occurrence`, resolving OQ-1
in that model's spec, which owns the branch: its BL-007 to BL-011 state the union, the null
`visit_occurrence_id`, the person route through the enrolment, the condition-category status
and the deletion exclusion, and its AC-008 to AC-013 assert them. What this spec owes that
branch is the episode every registry-condition row hangs off, which its AC-013 checks.

### `int__program_enrolments`

**Grain.** One row per patient enrolment in a program registry — the same grain as this model,
one status wider.

**Why it exists.** `clinical__episode` and `ds__patient_program_registrations` need the same
enrolment facts resolved the same way, but not the same rows: the episode is a clinical fact and
excludes enrolments recorded in error, while the dataset lists them for the removed-patients
report (BL-025). Resolving currently-at in both is the duplication BL-022 exists to prevent, so
the resolution lives here once and each consumer filters it.

- **BL-026:** One row per enrolment held by a patient `bases/patients` carries, whatever its
  registration status, with registry, clinical status and currently-at resolved (BL-007) and the
  other lookups left-joined (BL-011). Recorded-in-error rows are kept for `clinical__episode` to
  drop and merged-away patients are excluded here, so both consumers and
  `int__registration_status_history` inherit BL-001's population rule from one place; the model is
  ephemeral and materialises nothing.

### `ds__patient_program_registrations` rebased

The dataset currently reads `bases/` directly and resolves currently-at itself, duplicating
BL-007. It is rebased so the enrolment facts have one definition.

- **BL-022:** Enrolment facts — registration status and datetime, program registry, clinical
  status, currently-at, registering facility, registered-by, deactivation — are read from
  `int__program_enrolments` (BL-026), the same model `clinical__episode` reads, so the two
  cannot drift. The dataset joins no base registration table at all.
- **BL-023:** Patient demographics, `patient_additional_data` contact and administrative columns,
  and the related-condition aggregation stay in the dataset: they are Tupaia presentation concerns
  and not part of the OMOP episode.
- **BL-024:** The dataset's output columns, their names and their order are unchanged, so no
  consumer's column contract moves.
- **BL-025:** The dataset keeps enrolments recorded in error, which have no episode (BL-002) but
  are listed by `program-registry-removed-patients-line-list` — its filter is
  `registration_status != 'active'`, which catches `recordedInError` alongside `inactive`. This is
  why the dataset reads `int__program_enrolments` rather than `clinical__episode`: the two
  populations differ by exactly this one status.

  `program-registry-line-list`, the other consumer, filters `registration_status = 'active'`
  and is unaffected — the two reports partition the dataset between them.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | `episode_id` is unique and not null | BL-001 | dbt `unique`, `not_null` |
| AC-002 | `registration_status` is `active` or `inactive` only | BL-002 | `accepted_values` |
| AC-003 | `episode_start_datetime` is not null | BL-003 | dbt `not_null` |
| AC-004 | `episode_end_datetime >= episode_start_datetime` where the end is not null | BL-004 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-005 | On an `inactive` registration `episode_end_source` is `deactivation` exactly when `deactivated_datetime` is set and `status change` exactly when the end came from a logged transition; on an `active` one it is null | BL-004, BL-005 | singular test |
| AC-006 | `episode_end_date` is null exactly when `episode_end_datetime` is null | BL-004, BL-005 | singular test |
| AC-007 | Every `active` registration has both end columns and `episode_end_source` null, whatever `deactivated_datetime` holds | BL-005 | singular test |
| AC-008 | `currently_at_id` is null whenever the registry's `currently_at_type` is null | BL-007 | singular test |
| AC-009 | `currently_at_type` is `facility`, `village`, or null | BL-007 | `accepted_values` |
| AC-010 | Every `person_id` appears in `clinical__person` | BL-001 | dbt `relationships` |
| AC-011 | Every non-null `care_site_id` appears in `ref__care_site` | BL-011 | `relationships` |
| AC-012 | Row count equals the source count of non-`recordedInError`, non-deleted registrations held by a patient in `bases/patients` and belonging to a registry in `bases/program_registries` | BL-001, BL-002, BL-011 | singular test |
| AC-013 | `(episode_id, logged_at, history_source)` is unique in the history | BL-012, BL-014 | singular test |
| AC-014 | Every history `episode_id` appears in `clinical__episode`, without exception | BL-012 | singular test |
| AC-015 | Each registration's latest history row matches `clinical__episode`'s current status | BL-014 | singular test |
| AC-016 | An `inactive` registration with no `deactivated_datetime` has an end iff a logged history entry putting it `inactive` exists — the synthetic current-state row does not qualify | BL-004, BL-006 | singular test |
| AC-017 | `ds__patient_program_registrations` emits the same column set as before the rebase | BL-024 | singular test asserting the column list |
| AC-018 | `episode_concept_id`, `episode_object_concept_id`, `episode_parent_id` and `episode_number` are always null | BL-009, BL-010 | singular test |
| AC-023 | `ds__patient_program_registrations` row count equals `clinical__episode` row count plus the recorded-in-error enrolments | BL-022, BL-025, BL-026 | singular test |
| AC-025 | `ds__patient_program_registrations` still emits the patient, contact and related-condition columns | BL-023 | covered by AC-017's column-list assertion, which names them |
| AC-026 | `program_registry_id` is not null | BL-001, BL-026 | dbt `not_null` |
| AC-027 | Every non-null `provider_id` and `deactivated_by_provider_id` appears in `ref__provider` | BL-011 | `relationships` |

BL-026 is asserted by AC-023 (the two populations differ by exactly the recorded-in-error
rows) together with AC-008 and AC-009, which pin the currently-at resolution it now owns.

BL-013, BL-015 and BL-016 carry no acceptance criterion: the first two describe what the change log
can and cannot show, and the third is a sourcing rule enforced by review rather than by a test.
BL-008 is asserted indirectly by AC-015, which pins the history's final row to the current status.

## Lineage

```
bases/patient_program_registrations ──┬──►  int__program_enrolments  ─┬─►  clinical__episode  ─┬─►  derived__cohort_*
bases/program_registries            ──┤    (all statuses)          │         ▲           └─►  metric__ programme indicators
bases/program_registry_clinical_...  ─┤                            │         │
bases/facilities / reference_data   ──┘                            └─►  ds__patient_program_registrations
                                                                       │
bases/patient_program_registrations_change_logs ──►  int__registration_status_history ─┘

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

**Recommendation.** Emit `episode_parent_id` and `episode_number` now, always NULL, so the table is
schema-conformant and gaining children later changes no consumer's contract. Build the children as
`derived__episode_art_regimen` rather than here: a regimen line collapsed from consecutive
same-regimen answers *is* the computed multi-domain sequence that layer is for, and its
`episode_parent_id` points at this model's row. That split satisfies both OMOP's categorisation and
the repo's convention, and it puts the computed thing in the computed layer while the asserted
enrolment stays here.

The link from a regimen episode back to the records evidencing it is OMOP's `EPISODE_EVENT`, which
maps an episode to the `clinical__observation` rows carrying the regimen answers. Nothing in this
repo emits it yet; it is the natural companion to the first `derived__episode_*` model rather than
to this one.

Three things decide *when*, not *whether*:

1. **The regimen answers are not coded.** The DAK leaves the regimen list country-configured
   (Table 13), so `HIV.D.DE75` and `HIV.D.DE444` arrive as free text from the WHO-DAK HIV forms. An
   era boundary computed by comparing free-text regimen strings across visits would be wrong in a
   way that is invisible downstream. A deployment supplying a local coded list removes this.
2. **No `vocab__` layer.** Without it (D2, OQ-005) a child episode cannot say *which* regimen it
   represents except as a source string, so the hierarchy would carry sequence without identity.
3. **One episode source.** `episode_parent_id` with a single source is a permanently NULL column;
   it earns its keep when the second source exists.

Until then, regimen history is answerable by joining `clinical__observation` (the regimen answers)
to `clinical__episode` (the enrolment) — the same question, without a hierarchy to maintain.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-08-23 | Maui team | Initial spec. `clinical__episode` over program registries, with the episode end resolved through the change log rather than `deactivated_datetime` alone, and `int__program_enrolments` holding the enrolment resolution that `clinical__episode` and `ds__patient_program_registrations` share across their two populations — the dataset keeps enrolments recorded in error, which `program-registry-removed-patients-line-list` lists. Merged-away patients are excluded because a registration id embeds its patient id, so a merge cannot repoint it the way it repoints an encounter and the enrolment would otherwise get a `person_id` no `clinical__person` row answers to. `ref__care_site` gained a facility grain (its BL-007) so AC-011 can relate a registering facility without repointing the FK at `bases/facilities`, which D2 forbids. |
