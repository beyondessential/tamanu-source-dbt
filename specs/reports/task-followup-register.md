# Report Spec: `task-followup-register`

## Identity

| Field | Value |
|---|---|
| **Name** | `task-followup-register` |
| **Type** | Standard Tamanu report, plus one supporting dataset and two base models, each with a sensitive-facility variant |
| **Layer** | `base`, `ds`, `report` |
| **Materialisation** | base `view`, dataset `view`, report `view` |
| **Status** | `review` |
| **Owner** | Maui team (`bes-maui`) |
| **Linear issue** | [MAUI-6852](https://linear.app/bes/issue/MAUI-6852/new-report-physiotherapy-inpatient-follow-up-register) |
| **Repo** | `tamanu-source-dbt` (branch `2.54`) |
| **Created** | 2026-09-06 |

## Purpose

Physiotherapists have no way to see, after the fact, which of the tasks handed to them were
actually done. The need was raised by Samoa, but nothing about it is deployment-specific.
Tamanu's ward dashboard is a live worklist: it shows what is outstanding now, not what was
left undone last week, and it carries none of the discharge and follow-up context needed to
chase a patient once they have left the ward. A task a
physiotherapist never actioned drops out of view when the patient is discharged.

The register is a retrospective view of the same work: one row per task handed to a
designation, showing whether it was completed, missed or actively declined, alongside where
the patient is now, where they went on discharge, and whether a follow-up appointment exists.

The register is scoped by designation rather than fixed to physiotherapy, so any designation
whose staff are assigned tasks — nursing, occupational therapy, dietetics — gets the same
view by setting one parameter. It is scoped by encounter type the same way: Tamanu places no
encounter-type restriction on tasks, so the inpatient view is one selection rather than a
constraint baked into the report.

**Consumer:** Tamanu reporting UI, any deployment. Ships in the standard report set, with a
`sensitive-task-followup-register` variant covering sensitive facilities.

## Grain

**One row per designation-assigned task.** An encounter carrying several tasks produces
several rows; the patient, encounter, discharge and follow-up columns repeat across them. A
task assigned to more than one designation stays one row, with the designations listed
together. An encounter with no designation-assigned task produces no row, and neither does a
task assigned to no designation.

## Inputs

### Parameters

| Name | Type | Default | Purpose |
|---|---|---|---|
| `fromDate` | date | UI default | Lower bound on the task's due date and time |
| `toDate` | date | UI default | Upper bound on the task's due date and time |
| `designationId` | text | null | Optional restriction to one designation |
| `encounterType` | text[] | null | Optional restriction to one or more encounter types |
| `facilityId` | text | null | Optional restriction to one facility |
| `locationGroupId` | text | null | Optional restriction to one area |
| `patientId` | uuid | null | Optional restriction to a single patient |
| `taskStatus` | text[] | null | Optional restriction to one or more register outcomes |

### Upstream models

| Reference | Why we need it |
|---|---|
| `ref('tasks')` | New local base — the task, its status, timings and notes |
| `ref('task_designations')` | New local base — which designations a task is assigned to |
| `ref('encounters')` | Encounter type, start and end, patient, current location |
| `ref('locations')`, `ref('location_groups')`, `ref('facilities')` | Area and facility the patient occupies, and the sensitive-facility exclusion |
| `ref('patients')` | Patient demographics |
| `ref('reference_data')` | Designation, village, not-completed reason and discharge disposition names |
| `ref('users')` | Display name of the user who raised the task |
| `ref('user_designations')` | Which designations a note's author holds |
| `ref('notes')` | Whether the designation recorded a note on the encounter |
| `ref('encounter_diagnoses')` | Primary and secondary diagnoses for the encounter |
| `ref('discharges')` | Discharge disposition |
| `ref('outpatient_appointments')` | Whether a follow-up appointment exists, and where |

### Required input columns

| Upstream | Columns used |
|---|---|
| `tasks` | `id`, `encounter_id`, `name`, `task_type`, `status`, `high_priority`, `note`, `request_datetime`, `requested_by_user_id`, `due_datetime`, `completed_datetime`, `completed_note`, `not_completed_reason_id`, `todo_note` |
| `task_designations` | `task_id`, `designation_id` |
| `encounters` | `id`, `patient_id`, `start_datetime`, `end_datetime`, `location_id`, `encounter_type` |
| `locations` | `id`, `location_group_id`, `facility_id` |
| `location_groups` | `id`, `name` |
| `facilities` | `id`, `name`, `is_sensitive` |
| `patients` | `id`, `display_id`, `first_name`, `last_name`, `sex`, `date_of_birth`, `village_id` |
| `reference_data` | `id`, `name` |
| `users` | `id`, `display_name` |
| `user_designations` | `user_id`, `designation_id` |
| `notes` | `record_id`, `record_type`, `authored_by_id`, `on_behalf_of_id` |
| `encounter_diagnoses` | `encounter_id`, `diagnosis_id`, `is_primary`, `datetime` |
| `discharges` | `encounter_id`, `disposition_id` |
| `outpatient_appointments` | `patient_id`, `start_datetime`, `location_group_id`, `status` |

## Output schema

| Column (translation key) | Type | Description |
|---|---|---|
| `patientDisplayId` | text | Patient's NHN |
| `patientFirstName` | text | Patient's first name |
| `patientLastName` | text | Patient's last name |
| `patientSex` | text | Patient's sex |
| `patientDateOfBirth` | text | Patient's date of birth |
| `patientAge` | numeric | Patient's age in whole years at the start of the encounter |
| `patientVillage` | text | Patient's village |
| `facility` | text | Facility the patient was admitted to |
| `locationGroup` | text | Area (ward) the patient currently occupies |
| `encounterType` | text | Type of encounter the task was raised during |
| `encounterStartDateTime` | text | When the encounter started |
| `encounterEndDateTime` | text | When the encounter ended, blank while still open |
| `encounterLengthOfStay` | numeric | Days between the encounter starting and ending |
| `diagnosesPrimary` | text | Primary diagnoses recorded against the encounter |
| `diagnosesSecondary` | text | Secondary diagnoses recorded against the encounter |
| `taskDesignations` | text | Designations the task is assigned to |
| `taskName` | text | The task as written when raised |
| `taskStatus` | text | Register outcome: `Completed`, `Outstanding`, `Missed` or `Not completed` |
| `taskNotCompletedReason` | text | Reason the task was recorded as not completed |
| `taskHighPriority` | text | Whether the task was flagged high priority |
| `taskRequestedBy` | text | Display name of the user who raised the task |
| `taskRequestedDateTime` | text | When the task was raised |
| `taskDueDateTime` | text | When the task fell due |
| `taskCompletedDateTime` | text | When the task was marked complete |
| `taskHoursToCompletion` | numeric | Hours between the task being raised and marked complete |
| `taskNote` | text | Note left against the task |
| `taskDesignationNotesRecorded` | text | Whether the designation recorded a note on this encounter |
| `dischargeDisposition` | text | Where the patient went on discharge |
| `appointmentFollowUpBooked` | text | Whether a follow-up appointment exists |
| `appointmentFollowUpDateTime` | text | When that appointment is scheduled |
| `appointmentFollowUpLocationGroup` | text | Area the follow-up appointment is booked into |

## Business logic

- **BL-001:** Tasks on an encounter of any type at a non-sensitive facility are in scope, the
  encounter's type is carried through to the output, and length of stay is the interval in days
  between the encounter's start and end, blank while it is still open.
- **BL-002:** Tasks with `task_type = 'medication_due_task'` are excluded.
- **BL-003:** A task is in scope only if it is assigned to at least one designation, its
  designations are collapsed to one row carrying both the reference data IDs and their names,
  and a designation with no resolvable reference data row is named by its raw ID.
- **BL-004:** The date range filters on the task's due date and time, inclusive at both
  bounds.
- **BL-005:** The register's outcome is `Completed` when `status = 'completed'`, `Outstanding`
  when `status = 'todo'`, `Missed` when `status = 'non_completed'` and
  `not_completed_reason_id = 'tasknotcompletedreason-taskoverdue'`, and `Not completed`
  otherwise.
- **BL-006:** Time to completion is the interval in hours between `request_datetime` and
  `completed_datetime`, blank unless the task was completed.
- **BL-007:** Leaving `designationId` unset returns every designation's tasks.
- **BL-008:** A note counts towards the designation when its author, or the clinician it was
  recorded on behalf of, currently holds one of the task's designations.
- **BL-009:** The follow-up appointment is the earliest non-cancelled outpatient appointment
  for the patient, other than the one this encounter was created from, starting on or after the
  encounter's end, or after its start while the encounter is still open.
- **BL-010:** The area shown is the location group of the encounter's current location, not
  the location group the patient occupied when the task fell due.
- **BL-011:** The task note shown is the completion note where one exists, otherwise the
  to-do note, otherwise the note the task was raised with.
- **BL-012:** Every parameter is applied in the report's outer `where`, the sole point in the
  build where `parameter()` emits a live bind variable.
- **BL-013:** The dataset and report each ship as a standard model and a sensitive variant,
  built from one body macro parametrised by `is_sensitive`, which selects the facilities the
  dataset covers and the dataset the report reads.
- **BL-014:** `tasks` and `task_designations` are base models, the only layer reading
  `public.tasks` and `public.task_designations`.
- **BL-015:** Leaving `encounterType` unset returns tasks on every encounter type.
- **BL-016:** A diagnosis with no `is_primary` value is reported as secondary.

## Acceptance criteria

| ID | Criterion | Implements | Test |
|---|---|---|---|
| AC-001 | `task_id` is unique — the dataset holds one row per task | BL-003 | dbt schema test |
| AC-002 | `task_status` is one of `todo`, `completed`, `non_completed` | BL-005 | dbt schema test |
| AC-003 | `task_outcome` is one of `Completed`, `Outstanding`, `Missed`, `Not completed` | BL-005 | dbt schema test |
| AC-004 | `encounter_type` is one of Tamanu's eight encounter types | BL-001 | dbt schema test |
| AC-005 | No row's task is a medication due task | BL-002 | dbt singular test |
| AC-006 | Every row carries at least one designation ID and a non-blank designation name | BL-003 | dbt singular test |
| AC-007 | The register outcome follows from the task's stored status and not-completed reason | BL-005 | dbt singular test |
| AC-008 | Time to completion is present exactly when the task was completed, and never negative | BL-006 | dbt singular test |
| AC-009 | A follow-up appointment never precedes the encounter's end, and the booked flag agrees with the presence of an appointment date | BL-009 | dbt singular test |
| AC-010 | Length of stay is present exactly when the encounter ended, and never negative | BL-001 | dbt singular test |
| AC-011 | The report's config notes state the outcome mapping, the encounter-type default, and the designation, medication-due and deleted-task exclusions | BL-002, BL-003, BL-005, BL-015 | Manual review of `models/reports/config/standard/task-followup-register.json` |
| AC-012 | A run over a one-month range with no designation and no encounter type selected returns in workable time on a production/replica snapshot | BL-007, BL-015 | Manual run against a snapshot before merge |

## Risks

- **The `Missed` outcome only ever applies to repeating tasks.** Tamanu's
  `GenerateRepeatingTasks` job sets the overdue reason on tasks that carry a frequency and are
  more than two days past due; a one-off task nobody actions stays `todo` indefinitely and
  reads as `Outstanding`, however long ago it fell due. A reader reviewing a closed period
  should treat `Outstanding` on a discharged patient as missed work, since nobody can action
  it any more. On a deployment that raises its tasks as one-offs rather than repeating ones,
  `Missed` will be empty and the whole signal will sit in `Outstanding` — worth confirming
  against real data before the register is relied on.
- **Deleted tasks are absent entirely.** The `tasks` base excludes soft-deleted rows. Tamanu's
  own discharge cleanup (`Task.onEncounterDischarged`) only deletes repeating-task occurrences
  that were still `todo` and fell due *after* the discharge, so a task that came due during the
  encounter and was never actioned is retained and does reach the register. A task a user
  deletes by hand, however, leaves no trace here — including one deleted to tidy away work that
  was never done.
- **The query shape is unmeasured against real data.** `scoped_encounters` is marked `not
  materialized` so the report's own predicates can push into it rather than the whole
  non-sensitive encounter set being built first, and the designation-note flag is an `exists`
  evaluated per returned row rather than an aggregate over every note in the database. Both
  choices are reasoned rather than profiled: no snapshot was reachable when they were made. AC-012 is the gate — confirm the plan before the register is relied on for routine
  unfiltered runs.
- **Encounter type is a filter, not a guarantee of clinical shape.** With `encounterType`
  unset the register mixes an inpatient admission's tasks with tasks raised during a triage,
  clinic or imaging encounter, whose start and end span minutes rather than days. Length of
  stay, discharge disposition and follow-up appointment stay meaningful for an admission and
  read as near-empty for the short encounter types. Selecting `admission` alone restores the
  inpatient register.
- **`designation_notes_recorded` reflects designations as they stand now.** `user_designations`
  carries no history, so a clinician who has since changed or lost a designation is counted
  under their current one, not the one they held when the note was written. It is a coarse
  "did this discipline document anything on this encounter" flag, not an audit of who wrote
  what.
- **The area shown is where the patient is now** (BL-010), which is what a clinician needs in
  order to go and find them, but means a patient transferred between wards mid-encounter shows
  their latest ward against a task raised on an earlier one. Full ward history is available in
  the standard admissions line list.
- **A follow-up appointment is matched on the patient, not on the encounter** (BL-009).
  `appointments.encounter_id` links an appointment to the encounter it was created from, which
  is not populated for an appointment booked independently after discharge — the common case
  for a follow-up. Matching on patient and date catches those, at the cost of also catching an
  unrelated appointment that happens to fall after this encounter.

## Open questions

None outstanding. MAUI-6852 asked whether "task never completed" should mean any status other
than `completed`, or only a task left at `todo`; BL-005 renders both, as `Not completed` and
`Outstanding` respectively, and the `taskStatus` parameter lets the reader select either.

## Change log

| Date | Author | Change |
|---|---|---|
| 2026-09-06 | Maui team | Implemented (MAUI-6852) as a standard report on the `2.54` branch, so deployments pinned to 2.54 pick it up on a package bump rather than carrying their own copy. Dataset and report bodies are single macros parametrised by `is_sensitive`, giving the standard and sensitive-facility variants from one definition. Follow-up appointment matching excludes the appointment the encounter was created from, which otherwise reported an open clinic encounter's own booking as its follow-up. The designation join is a left join so a task whose only designation has no resolvable reference data row stays in the register under its raw ID instead of disappearing. Scoped by designation rather than fixed to physiotherapy, per the requester's comment on the issue, which makes the register reusable by every discipline that receives tasks. Encounter type is a parameter rather than a hardcoded `admission` filter: Tamanu gates the tasking pane on a setting and a permission but not on encounter type, so a task raised during an emergency or clinic encounter is as real as one raised on the ward, and hardcoding the filter would have silently hidden exactly the missed tasks the register exists to surface. Grain is one row per task rather than the one representative task per admission the supplied template assumed, for the same reason: collapsing an encounter's tasks to one would hide the missed ones. The template's second inclusion path — an encounter with a note from the discipline but no task — is not implemented, since a task-monitoring register has nothing to report on such an encounter. "Physio notes written?" is derived from note authorship against `user_designations`, which the template treated as underivable. `Missed` is bound to Tamanu's own overdue reason ID rather than to elapsed time, so the register never disagrees with what Tamanu recorded. |
