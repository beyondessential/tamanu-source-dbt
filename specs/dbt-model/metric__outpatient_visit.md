# dbt Model Spec: `metric__outpatient_visit` (canonical definition)

## Identity

| Field | Value |
|---|---|
| **Name** | `metric__outpatient_visit` (1 registered indicator) |
| **Type** | dbt model (canonical definition) |
| **Layer** | `metrics` (D5 wide format, per-subject grain) |
| **Materialisation** | env-aware -- `table` on `analytics*`, `view` everywhere else (BL-005) |
| **Status** | `implemented` |
| **Owner** | Maui team |
| **Repo** | `tamanu-source-dbt` |

Canonical definition for `opd_visit`: one row per outpatient visit, at day resolution.
Replaces the earlier `ds__outpatient_visit` dataset, converting it onto the same
registry-backed metric pattern as `metric__emergency_visit`.

## Purpose

Outpatient department activity at a Tamanu facility, one row per visit.

| `metric_id` | Unit | Measures |
|---|---|---|
| `opd_visit` | count | Outpatient visits (always 1 per row) |

**Clinical context.** An outpatient visit is usually a self-contained event, and one
metric covers it -- there is no equivalent to `metric__emergency_visit`/`metric__emergency_stay`'s
split, because the outpatient episode and the encounter are the same span for all but a
fraction of visits. A small minority do end in admission (0.09% of FSM's 430k clinic
encounters), so the episode is bounded explicitly rather than assumed to run to the
encounter end (BL-011), and the outcome is carried as a disaggregation rather than as a
second metric (BL-009).

**Who reads it.** The Tupaia "Hospital Administration" dashboard for Queen of Sheba
Hospital, via a data table over this view.

## Definition sources

| Element | Source | Code | Concept |
|---|---|---|---|
| `metric_id` | AIHW | [400604](https://meteor.aihw.gov.au/content/400604) | Non-admitted patient service event -- concept anchor, not an implemented indicator (BL-001) |

AIHW registers no plain OPD attendance-count indicator: its non-admitted reporting is built
around the Tier 2 Non-Admitted Services Classification and per-clinic activity counts, not a
single cross-clinic count. "Occasion of service" (METeOR 270511) was considered and
rejected as the anchor -- it is scoped to a narrower residual clinic category, not the
general OPD population this metric covers.

## Grain

**One row per `(metric_id, subject_id)`.** Asserted by AC-001 at `error` severity -- a
duplicate would double-count a visit in any consumer that sums `value_numeric`.

`subject_id` is the OMOP visit occurrence id, matching the registry's `subject_grain:
visit`, and is unique because only the intake segment is counted (BL-003) -- so
`count(distinct subject_id)` and `sum(value_numeric)` agree.

## Output schema

D5 wide format, plus seven disaggregation columns and three measure attributes.

| Column | Type | Notes |
|---|---|---|
| `metric_id` | text | Always `opd_visit`. FK -> `metric_definitions.metric_id` (AC-003) |
| `variant_id` | text | NULL -- this is the standard definition |
| `subject_id` | varchar(255) | Encounter id. `not_null` (AC-008) |
| `period_start` | date | Visit date (BL-002) |
| `period_end` | date | Encounter end date. NULL while the encounter is open (BL-002) |
| `period_granularity` | text | Constant `'day'` |
| `value_numeric` | numeric | Always `1` (AC-006). Additive, so a data table sums it |
| `value_boolean` | boolean | NULL -- this metric's value is the count in `value_numeric` |
| `facility_id` | varchar(255) | Intake segment's facility (BL-006) |
| `location_id` | varchar(255) | Intake segment's location, one level finer than facility (BL-006). `not_null` (AC-010) |
| `sex` | varchar(255) | `clinical__person.gender_source_value` |
| `age_years` | integer | Age in whole years at the visit, unbanded (BL-004). A measure, not a dimension |
| `clinician_id` | varchar(255) | Intake segment's clinician, as the Tamanu user id (BL-008). Nullable |
| `is_admitted` | boolean | Whether the encounter went on to an inpatient admission (BL-009). `not_null` (AC-011) |
| `admission_clinician_id` | varchar(255) | Admission segment's clinician, as the Tamanu user id (BL-010). NULL where not admitted |
| `is_auto_discharge` | boolean | Discharge was system-generated, not clinician-recorded (BL-012). `not_null` (AC-012) |
| `opd_time__seconds` | bigint | Time in the outpatient department, whole seconds (BL-011). NULL while open |
| `opd_time__minutes` | numeric | The same duration in minutes, 2 dp (BL-011). A measure, not a dimension |

## Data tables

The Tupaia data tables over this view are configured in `tupaia-data-product`, at
`tamanu/data_tables/`, one file per data table -- the filter types, the aggregation and any
bands are the consumer's vocabulary, not dbt's, so they live with the rest of a data table's
configuration (permission groups included) in that repo. `validate_data_tables.py` there
checks each file against this project's dbt manifest, so a column renamed here fails there
at generate time rather than emptying a dashboard.

Area/clinic disaggregation (`location_group`) and the Tamanu-to-Tupaia facility crosswalk
are both left to that layer too -- joined at the data table against a seed, rather than
resolved here. This model emits the raw `location_id` so that join is possible; it does not
resolve `location_group` itself (see BL-006).

This model therefore carries no `data_table_*` meta.

## Business logic

- **BL-001 (registration):** every emitted `metric_id` is registered in
  `documentations/metrics/*.yml`, asserted by AC-003 at `error` severity.
- **BL-002 (reporting period):** `period_start` is the visit date
  (`clinical__visit_detail.visit_detail_start_date` for the intake segment); `period_end` is
  the encounter end date (`clinical__visit_occurrence.visit_end_date`), at `'day'`
  granularity.

  `period_end` is nullable -- NULL means the encounter is still open -- so AC-004 covers
  `period_start` only and AC-009 asserts ordering where `period_end` is present. Both are
  dates, so `period_end - period_start` gives whole days, not a precise duration the way
  ED's minute-resolution pair does. The underlying encounter *does* carry timestamps --
  `opd_time__minutes` is taken from them (BL-011) -- so the day grain here is a choice about
  what the reporting period is, not a limit of the source.

  Every visit is emitted as it happens; the model reads no clock, and a consumer needing
  whole periods applies its own date filter. A period with no visit emits no row.
- **BL-003 (inclusion + intake attribution):** a visit is the **first** segment of an
  encounter (`preceding_visit_detail_id is null`) whose `visit_detail_concept_id = 9202`,
  which covers `clinic`, `vaccination` and `imaging` via `map__omop_visit_type`.

  Anchoring on the first segment counts one row per visit and ties inclusion to the
  OMOP-standard mapping rather than the raw `visit_detail_source_value`.
- **BL-004 (age is the consumer's to band):** `age_years` is age in whole years at the visit
  date, emitted raw and unbanded. An age classification -- WHO primary bands, five-year
  bands, a national HMIS grouping -- is a presentation choice a deployment may set
  differently, so banding it here would either freeze one choice or need a column per
  variant. `age_years` is therefore a **measure, not a dimension**: absent from the
  registry's disaggregations, banded (if at all) by the data table declaring it, in
  `tupaia-data-product` (same convention as `metric__emergency_visit` BL-019).

  `sex` is `clinical__person.gender_source_value`. The join to `clinical__person` is
  **inner**, so a visit whose patient `bases/patients` excludes as soft-deleted or merged
  away is excluded rather than counted with blank demographics.
- **BL-005 (materialisation is env-aware):** `table` when `target.name` starts with
  `analytics`, `view` otherwise, set on the `metrics:` block in `dbt_project.yml` (shared
  with every model under `models/metrics/`).
- **BL-006 (facility and location attribution):** `facility_id` and `location_id` are both
  resolved through the same `bases/locations` join on `care_site_id` -- `facility_id` is
  `locations.facility_id`, `location_id` is the location's own primary key (`locations.id`).
  The join is **inner**, so an encounter whose location does not resolve is excluded rather
  than attributed to a NULL facility.

  `location_id` is one level finer than facility and carries no area/clinic resolution of
  its own -- `metric__emergency_visit` has no equivalent column at all. It exists so a
  consumer can join to `bases/location_groups` (or a similar area lookup) at the data table
  layer if it wants clinic-level detail, without this model resolving that join itself (see
  § Data tables). First `metric__` disaggregation finer than facility.
- **BL-007 (facility, location and clinician identity stay Tamanu's):** the model emits
  `facility_id`, `location_id`, `clinician_id` and `admission_clinician_id` as Tamanu ids,
  untranslated. Consumer-specific identifiers -- a Tupaia entity code, an area/clinic
  grouping, a clinician's display name -- are resolved in the consumer layer, not here.

  For a clinician the consumer joins `maps/map__clinician`, which projects
  `(clinician_id, clinician_name)` from `bases/users` and nothing else. The narrower relation
  exists because a consumer reads its maps from the same schema as the metric: routing
  `bases/users` to `public_tupaia` would expose staff email and phone number to every
  consumer that can read a metric, which resolving a name does not require.
- **BL-008 (attending clinician):** `clinician_id` is the intake segment's `provider_id` --
  the clinician recorded against the patient in the outpatient department.

  Nullable, with no `not_null` test: an intake segment recorded with no clinician keeps the
  visit rather than dropping it from the metric, the same treatment `sex` gets. A consumer
  exposing it as an array filter has to label the NULL, since Tupaia's array filter drops
  NULL rows.
- **BL-009 (admission outcome):** `is_admitted` is true where the encounter carries any
  segment at `visit_detail_concept_id = 9201` (Inpatient Visit) -- the patient was seen in
  clinic and the encounter's type was later changed to admission.

  Read off the segment timeline rather than off `encounters.encounter_type`, which Tamanu
  updates in place and which therefore says only what the encounter is *now*; and rather
  than off `clinical__visit_occurrence.visit_concept_id`, whose 262 only marks an
  ED-then-admitted episode and so would miss every clinic-then-admitted one.

  A disaggregation, not a metric: the model emits no rate, because a proportion is not
  additive and summing one across facility, sex or age band is meaningless. The admitted
  share is `sum(value_numeric) filter (where is_admitted) / sum(value_numeric)`, formed at
  whatever grain the consumer groups to -- the same division `metric__emergency_visit`
  BL-006 makes.

  `false`, never NULL (AC-011).
- **BL-010 (admitting clinician):** `admission_clinician_id` is the `provider_id` of the
  **earliest** segment at concept 9201, taken with `distinct on` so the join cannot fan out
  an encounter with several inpatient segments.

  Deliberately separate from `clinician_id`: the clinician who saw the patient in clinic and
  the one recorded at the point of admission are different people in general, so both are
  emitted and the consumer picks the attribution its question calls for. "Admissions by
  clinician" over this column counts who admitted; the same card over `clinician_id`
  filtered to `is_admitted` counts whose clinic patients ended up admitted.

  NULL for a visit that was never admitted, and for an admission segment recorded with no
  clinician.
- **BL-011 (time in the outpatient department):** `opd_time__seconds` is the intake segment's
  `visit_detail_start_datetime` to the end of the outpatient episode;
  `opd_time__minutes` is that value in minutes to two decimal places, on the same basis as
  `metric__emergency_visit`'s durations -- 0.6-second resolution, finer than any reporting
  need, and a fixed scale so the value is stable to compare.

  The episode ends at the **first segment after intake carrying a concept other than 9202**,
  falling back to `clinical__visit_occurrence.visit_end_datetime` for a visit that never
  left outpatient care. A later 9202 segment is a clinician handover or a move between
  clinic rooms -- `clinical__visit_detail` opens a new segment for either -- and does not
  end the episode, so only a change of concept counts. This is the opposite resolution to
  `int__emergency_visits` BL-018, which takes a change of *care site* and explicitly not a
  change of type: there, a type change to admission while the patient is physically still
  in the ED is the boarding case a four-hour measure exists to expose. Outpatient care has
  no boarding equivalent -- once the encounter becomes an admission the outpatient episode
  is over -- so the two measures resolve departure differently, on purpose.

  NULL while the encounter is open and nothing has ended the episode. That is not a duration
  of zero, so a consumer forming a mean drops those visits from the denominator as well as
  the numerator.

  Not banded and not averaged here. A mean, a median or a band set are all presentation
  choices a deployment may set differently, so the metric emits the number per visit and the
  consumer forms what it needs -- the same division BL-004 makes for `age_years`. Averaging
  in the data table would return a mean per group, and a report combining groups would be
  averaging averages: a quiet facility would weigh the same as a busy one.
- **BL-012 (system-generated discharges are flagged, not filtered):** `is_auto_discharge` is
  true where the encounter's discharge note begins `Automatically discharged`.

  It matters to BL-011: Tamanu's outpatient discharger closes encounters left open at the end
  of the day, so such an encounter's end datetime is the sweep's clock rather than when the
  patient left, and its duration is an artefact. On FSM, 3,590 discharges carry
  `Automatically discharged by outpatient discharger` and 3,534 of those end between 23:50
  and 23:59; their mean duration is 777 minutes against a median of 16 for the rest.

  Flagged rather than filtered out, so a consumer forming a mean excludes them while a
  consumer counting visits keeps them -- the same treatment, and the same predicate, as
  `macros/datasets/discharge_audit.sql` BL-004, so the repo holds one definition of a system
  discharge.

  **Known gap.** The predicate does not catch a discharge a deployment's own data migration
  fabricated under a different note. FSM's carries
  `Auto-closed at 48h, historical import with no recorded discharge` on 76 encounters, whose
  48-hour duration is equally artificial and is not flagged. Left narrow on purpose: widening
  it would fork the definition away from BL-004 for 0.018% of the population. Revisit if a
  deployment's migration artefacts become material.

  `false`, never NULL (AC-012), covering both a clinician-recorded discharge and an encounter
  with no discharge record at all.

## Acceptance criteria

| ID | Criterion | Implements | Test type |
|---|---|---|---|
| AC-001 | One row per `(metric_id, subject_id)` | grain | `dbt_utils.unique_combination_of_columns` (`error`) |
| AC-002 | `metric_id` is `not_null` and always `opd_visit` | BL-001 | `not_null` + `accepted_values` |
| AC-003 | Every `metric_id` exists in `metric_definitions.metric_id` | BL-001 | `relationships` (`error`) |
| AC-004 | `period_start` is `not_null` | BL-002 | `not_null` |
| AC-005 | `period_granularity` is `not_null` and always `'day'` | BL-002 | `not_null` + `accepted_values` |
| AC-006 | `value_numeric` is `not_null` and always `1` | BL-003 | `not_null` + `accepted_values` |
| AC-007 | `facility_id` is `not_null` | BL-006 | `not_null` |
| AC-008 | `subject_id` is `not_null` | grain | `not_null` |
| AC-009 | `period_end`, where present, is at or after `period_start` | BL-002 | `dbt_expectations.expect_column_pair_values_A_to_be_greater_than_B` |
| AC-010 | `location_id` is `not_null` | BL-006 | `not_null` |
| AC-011 | `is_admitted` is `not_null` | BL-009 | `not_null` |
| AC-012 | `is_auto_discharge` is `not_null` | BL-012 | `not_null` |
| AC-013 | `opd_time__seconds`, where present, is `>= 0` | BL-011 | `dbt_expectations.expect_column_values_to_be_between` |
| AC-014 | The MAUI-6908 derivations behave as specified: intake-only inclusion, the attending and admitting clinicians, the admission outcome, a handover that does not end the episode, the open-encounter NULL duration, and the system-discharge predicate | BL-003, BL-008..BL-012 | `unit_test` (`data_tests/unit_tests/test_metric__outpatient_visit_derivations.yml`) |

## Registry entry

One active row -- `opd_visit`, `kind: metric`, `subject_grain: visit`, `status: approved`,
`spec_path` pointing here, with `disaggregations:
facility_id,location_id,sex,clinician_id,is_admitted,admission_clinician_id,is_auto_discharge`.

`age_years`, `opd_time__seconds` and `opd_time__minutes` are absent: they are measures, not
dimensions (BL-004, BL-011).

Every disaggregation is in the allowlist in `assert__metric_definitions__disaggregations`,
which keeps the registry and the model from drifting.

## Dependencies

| Ref | Layer | Role |
|---|---|---|
| `clinical__visit_detail` | `clinical/` | Intake segment: inclusion, visit date, location, encounter id (BL-003, BL-006) |
| `clinical__visit_occurrence` | `clinical/` | Encounter end date (BL-002) |
| `clinical__person` | `clinical/` | Sex and birth date (BL-004) |
| `locations` | `bases/` | Facility and location id of the intake segment's location (BL-006) |
| `discharges` | `bases/` | Discharge note, for the system-discharge flag (BL-012) |
| `metric_definitions` | root | Registry; `metric_id` FK target (AC-003) |

## Consumers

| Consumer | Use |
|---|---|
| `tupaia-data-product` `tamanu` source | Data table over this view, backing OPD visuals for Queen of Sheba |

**What a consumer must do:**

1. **Aggregate.** Sum `value_numeric`; `count(distinct subject_id)` is equally valid.
2. **Bucket the time grain and exclude the incomplete current period.** The model emits
   day-resolution dates, so a monthly card applies its own month bucketing and filters the
   current month itself.
3. **Band `age_years` itself.** No band set is emitted here -- a consumer wanting age groups
   declares its own classification in its data table.
4. **Translate `facility_id`, and join `location_id` for area if needed.** `facility_id` is
   the Tamanu id, not a consumer-specific one -- for Tupaia, the crosswalk to a Tupaia
   entity code is joined at the data table. Clinic/area (`location_group`) resolution is
   not done by this model either -- a consumer wanting it joins `location_id` to its own
   area reference at the data table.
5. **Handle a NULL `period_end`.** A duration visual filters those rows out; a count visual
   keeps them.
6. **Form its own rate.** `is_admitted` is a flag per visit, not a percentage -- the admitted
   share is the summed-numerator-over-summed-denominator quotient, taken once at the grain
   the card groups to.
7. **Form its own mean, and exclude what should not be in it.** `opd_time__minutes` is a
   duration per visit. A weighted mean is `sum(opd_time__minutes)` over the count of the
   visits that have one; a visit still open has no duration, and an auto-discharged visit's
   duration is the discharge sweep's clock, so both leave the denominator as well as the
   numerator (BL-011, BL-012).
8. **Label a clinician itself.** `clinician_id` and `admission_clinician_id` are Tamanu user
   ids -- a consumer joins `map__clinician` for the display name, and labels the NULL, since
   a visit may carry no clinician.

## Related

| Artefact | Relationship |
|---|---|
| `metric__emergency_visit` | Same registry pattern, same conventions (including BL-019's "banding is the consumer's") -- the reference this model was built from |
| `int__emergency_visits` | BL-018 resolves departure from the ED by care site and explicitly not by encounter type; BL-011 here resolves it the opposite way, for the reason given there |
| `metric__inpatient_admission` | Counts the admission itself, anchored on the 9201 segment BL-009/BL-010 read here. An OPD visit ending in admission appears in both, as a visit there and an admission here |
| `macros/datasets/discharge_audit.sql` | BL-004 defines the system-discharge predicate BL-012 reuses verbatim |
| `map__clinician` | Resolves the clinician ids this model emits, in the consumer layer (BL-007) |
| `metric_definitions` | The canonical registry every `metric__` view is registered against |
