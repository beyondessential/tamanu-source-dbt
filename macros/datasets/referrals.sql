{% macro referrals_dataset(network=none) %}

with diagnoses as (
    select
        ed.encounter_id,
        string_agg(concat(d.name), '; ') as diagnoses
    from {{ partition_ref('encounter_diagnoses', network) }} ed
    left join {{ ref('reference_data') }} d on d.id = ed.diagnosis_id
    group by ed.encounter_id
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.village_id,
    ed.diagnoses,
    s.name as referral_type,
    u.id as referring_doctor_id,
    u.display_name as referring_doctor_name,
    sr.end_datetime as referral_datetime,
    rf.status,
    d.name as department,
    f.id as facility_id
from {{ partition_ref('referrals', network) }} rf
join {{ partition_ref('encounters', network) }} e on e.id = rf.initiating_encounter_id
join {{ partition_ref('locations', network) }} l on l.id = e.location_id
join {{ partition_ref('facilities', network) }} f
    on f.id = l.facility_id
join {{ partition_ref('survey_responses', network) }} sr on sr.id = rf.survey_response_id
join {{ ref('surveys') }} s on s.id = sr.survey_id
join {{ ref('patients') }} p on p.id = e.patient_id
join {{ ref('users') }} u on u.id = e.clinician_id
join {{ partition_ref('departments', network) }} d on d.id = e.department_id
left join diagnoses ed on ed.encounter_id = rf.initiating_encounter_id

{% endmacro %}
