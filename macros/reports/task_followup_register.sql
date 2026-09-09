{% macro task_followup_register_report(is_sensitive=false) %}

{% set dataset = 'ds__sensitive_task_followup' if is_sensitive else 'ds__task_followup' %}

-- Task follow-up register
-- One row per designation-assigned task, with the outcome of the task and the patient's
-- encounter, discharge and follow-up detail -- see specs/reports/task-followup-register.md.

select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    sex as "{{ translate_label('patientSex') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    village as "{{ translate_label('patientVillage') }}",
    facility as "{{ translate_label('facility') }}",
    location_group as "{{ translate_label('locationGroup') }}",
    {{ translate_column_value('ENCOUNTER_TYPE_LABELS', 'encounter_type') }} as "{{ translate_label('encounterType') }}",
    to_char({{ to_user_selected_timezone('encounter_start_datetime') }}, '{{ var("datetime_without_seconds_format") }}') as "{{ translate_label('encounterStartDateTime') }}",
    to_char({{ to_user_selected_timezone('encounter_end_datetime') }}, '{{ var("datetime_without_seconds_format") }}') as "{{ translate_label('encounterEndDateTime') }}",
    length_of_stay_days as "{{ translate_label('encounterLengthOfStay') }}",
    primary_diagnoses as "{{ translate_label('diagnosesPrimary') }}",
    secondary_diagnoses as "{{ translate_label('diagnosesSecondary') }}",
    designations as "{{ translate_label('taskDesignations') }}",
    task_name as "{{ translate_label('taskName') }}",
    task_outcome as "{{ translate_label('taskStatus') }}",
    not_completed_reason as "{{ translate_label('taskNotCompletedReason') }}",
    high_priority as "{{ translate_label('taskHighPriority') }}",
    requested_by as "{{ translate_label('taskRequestedBy') }}",
    to_char({{ to_user_selected_timezone('task_requested_datetime') }}, '{{ var("datetime_without_seconds_format") }}') as "{{ translate_label('taskRequestedDateTime') }}",
    to_char({{ to_user_selected_timezone('task_due_datetime') }}, '{{ var("datetime_without_seconds_format") }}') as "{{ translate_label('taskDueDateTime') }}",
    to_char({{ to_user_selected_timezone('task_completed_datetime') }}, '{{ var("datetime_without_seconds_format") }}') as "{{ translate_label('taskCompletedDateTime') }}",
    hours_to_completion as "{{ translate_label('taskHoursToCompletion') }}",
    task_note as "{{ translate_label('taskNote') }}",
    designation_notes_recorded as "{{ translate_label('taskDesignationNotesRecorded') }}",
    discharge_disposition as "{{ translate_label('dischargeDisposition') }}",
    followup_appointment_booked as "{{ translate_label('appointmentFollowUpBooked') }}",
    to_char({{ to_user_selected_timezone('followup_appointment_datetime') }}, '{{ var("datetime_without_seconds_format") }}') as "{{ translate_label('appointmentFollowUpDateTime') }}",
    followup_appointment_location_group as "{{ translate_label('appointmentFollowUpLocationGroup') }}"
from {{ ref(dataset) }}
where
    -- BL-004: the register is scoped by when the task fell due, so a task that came due in
    -- the period is reviewable whether or not the encounter started in it
    {{ to_user_selected_timezone('task_due_datetime') }} >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and {{ to_user_selected_timezone('task_due_datetime') }} <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    -- BL-007: leaving the designation unset returns every designation's tasks
    and case
        when {{ parameter('designationId') }} is null then true
        else {{ parameter('designationId') }} = any(designation_ids::text [])
    end
    and case
        when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
    and case
        when {{ parameter('locationGroupId') }} is null then true
        else location_group_id = {{ parameter('locationGroupId') }}
    end
    and case
        when {{ parameter('patientId') }} is null then true
        else patient_id = {{ parameter('patientId') }}
    end
    and case
        when coalesce({{ parameter('taskStatus') }}) is null then true
        else task_outcome in ({{ parameter('taskStatus') }})
    end
    -- BL-015: Tamanu allows a task on any encounter type, so leaving this unset returns them
    -- all rather than silently hiding a missed task raised outside an admission
    and case
        when coalesce({{ parameter('encounterType') }}) is null then true
        else encounter_type in ({{ parameter('encounterType') }})
    end
order by task_due_datetime desc, display_id asc

{% endmacro %}
