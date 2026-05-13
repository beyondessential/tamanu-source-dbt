{% macro user_audit_dataset(is_sensitive=false) %}

with non_system_notes as (
    select distinct on (n.record_id)
        n.record_id,
        first_value(n.datetime) over w as first_note_datetime,
        last_value(n.datetime) over w as last_note_datetime,
        last_value(concat_ws(' on behalf of ', author.display_name, on_behalf.display_name)) over w as last_clinician
    from {{ ref('notes') }} n
    left join {{ ref('users') }} author on author.id = n.authored_by_id
    left join {{ ref('users') }} on_behalf on on_behalf.id = n.on_behalf_of_id
    where n.note_type_id != 'notetype-system'
    window w as (
        partition by n.record_id
        order by n.datetime
        rows between unbounded preceding and unbounded following
    )
)

select
    u.id as user_id,
    u.display_name as user_name,
    r.name as user_role,
    p.id as patient_id,
    p.display_id,
    bt.name as patient_category,
    t.score as triage_category,
    f.id as facility_id,
    f.name as facility,
    d.id as department_id,
    d.name as department,
    lg.id as location_group_id,
    lg.name as location_group,
    l.id as location_id,
    l.name as location,
    e.start_datetime as encounter_start_datetime,
    e.end_datetime as encounter_end_datetime,
    n.first_note_datetime,
    n.last_note_datetime,
    case when e.end_datetime isnull then 'Patient not discharged'
        else 'Patient discharged'
    end as is_discharged,
    case when ds.note like 'Automatically discharged%' then n.last_clinician
    end as non_discharge_by_clinicians
from {{ ref('encounters') }} e
left join {{ ref('users') }} u on u.id = e.clinician_id
left join {{ ref('roles') }} r on r.id = u.role
left join {{ ref('patients') }} p on p.id = e.patient_id
left join {{ ref('patient_additional_data') }} pad on pad.patient_id = e.patient_id
left join {{ ref('reference_data') }} bt
    on bt.id = coalesce(e.patient_billing_type_id, pad.patient_billing_type_id)
left join {{ ref('triages') }} t on t.encounter_id = e.id
join {{ ref('locations') }} l on l.id = e.location_id
left join {{ ref('location_groups') }} lg on lg.id = l.location_group_id
join {{ ref('facilities') }} f
    on f.id = l.facility_id
    and f.is_sensitive = {{ is_sensitive }}
left join {{ ref('departments') }} d on d.id = e.department_id
left join {{ ref('discharges') }} ds on ds.encounter_id = e.id
left join non_system_notes n on n.record_id = e.id

{% endmacro %}
