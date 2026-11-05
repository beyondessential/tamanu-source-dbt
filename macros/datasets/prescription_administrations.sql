-- See specs/dbt-model/ds__prescription_administrations.md for BL-003..BL-008, BL-011.
{% macro prescription_administrations_dataset(is_sensitive=false) %}

-- BL-006: each encounter history entry's department and location hold from its
-- own time until the next entry's. Built in one pass rather than a per-row
-- lookup, because encounter_history has no index on encounter_id. Ties on
-- datetime are broken by id so the windows never overlap
with encounter_history_windows as (
    select
        eh.encounter_id,
        eh.department_id,
        eh.location_id,
        eh.datetime as valid_from,
        lead(eh.datetime) over (
            partition by eh.encounter_id
            order by eh.datetime, eh.id
        ) as valid_to
    from {{ ref('encounter_history') }} eh
)

select
    ep.encounter_id,
    ep.prescription_id,
    mar.id as administration_id,
    dose.id as administration_dose_id,
    pr.datetime,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    e.encounter_type,
    -- BL-006: department and location in effect at the administration
    coalesce(eh_at.department_id, e.department_id) as department_id,
    d.name as department,
    coalesce(eh_at.location_id, e.location_id) as location_id,
    l_at.name as location,
    l.facility_id,
    f.name as facility,
    pr.medication_id,
    m.code as medication_code,
    m.name as medication,
    pr.prescriber_id,
    prescriber.display_name as prescriber,
    pr.is_variable_dose,
    pr.dose_amount,
    pr.dosing_unit,
    pr.route,
    pr.notes as prescription_notes,
    mar.status as administration_status,
    mar.due_datetime as administration_due_datetime,
    mar.recorded_datetime as administration_recorded_datetime,
    dose.dose_index as administration_dose_index,
    dose.dose_amount as administered_dose_amount,
    -- BL-005: when the dose was given; null when no dose was given
    dose.given_datetime as administered_datetime,
    -- BL-011: who gave the dose
    dose.given_by_user_id as administered_by_id,
    administrator.display_name as administered_by,
    mar.changing_status_reason as administration_notes
from {{ ref('encounter_prescriptions') }} ep
join {{ ref('encounters') }} e on e.id = ep.encounter_id
join {{ ref('patients') }} p on p.id = e.patient_id
join {{ ref('prescriptions') }} pr on pr.id = ep.prescription_id
join {{ ref('reference_data') }} m on m.id = pr.medication_id
join {{ ref('locations') }} l on l.id = e.location_id
-- BL-007: standard vs sensitive split on the location's facility
join {{ ref('facilities') }} f
    on f.id = l.facility_id
    and (f.sensitive_network_id is not null) = {{ is_sensitive }}
-- BL-008: prescriber_id is nullable, so this must stay a left join or prescriptions
-- recorded without a prescriber would drop out of the dataset entirely
left join {{ ref('users') }} prescriber on prescriber.id = pr.prescriber_id
-- BL-003: left join so a prescription with no administration record keeps its
-- row, with every administration column null
-- BL-004: records marked as an error were entered in error and never
-- happened, so they are not joined
left join {{ ref('medication_administration_records') }} mar
    on mar.prescription_id = pr.id
    and mar.is_error is not true
-- BL-005: one row per dose given; a MAR record with no dose (not given, or
-- not yet recorded) keeps one row with the dose columns null
left join {{ ref('medication_administration_record_doses') }} dose on dose.mar_id = mar.id
left join {{ ref('users') }} administrator on administrator.id = dose.given_by_user_id
-- BL-006: the encounter history window in effect when the dose was given, or
-- when it was due, or when prescribed. Falls back to the encounter's current
-- department and location when no entry precedes that time
left join encounter_history_windows eh_at
    on eh_at.encounter_id = ep.encounter_id
    and eh_at.valid_from <= coalesce(dose.given_datetime, mar.due_datetime, pr.datetime)
    and (
        eh_at.valid_to is null
        or eh_at.valid_to > coalesce(dose.given_datetime, mar.due_datetime, pr.datetime)
    )
left join {{ ref('departments') }} d on d.id = coalesce(eh_at.department_id, e.department_id)
left join {{ ref('locations') }} l_at on l_at.id = coalesce(eh_at.location_id, e.location_id)

{% endmacro %}
