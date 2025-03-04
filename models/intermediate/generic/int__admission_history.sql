with admission_location_log as (
    select
        da.id,
        da.encounter_id,
        da.start_datetime,
        da.department_id,
        da.location_id,
        da.clinician_id,
        'admission' as type
    from {{ ref('ds__admissions') }} da
    union all
    select
        ddh.id,
        ddh.encounter_id,
        ddh.start_datetime,
        ddh.department_id,
        null as location_id,
        null as clinician_id,
        'department' as type
    from {{ ref('ds__department_history') }} ddh
    join {{ ref('ds__admissions') }} da
        on da.encounter_id = ddh.encounter_id
        and da.start_datetime < ddh.start_datetime
        and (da.end_datetime > ddh.start_datetime or da.end_datetime is null)
    union all
    select
        dlh.id,
        dlh.encounter_id,
        dlh.start_datetime,
        null as department_id,
        dlh.location_id,
        null as clinician_id,
        'location' as type
    from {{ ref('ds__location_history') }} dlh
    join {{ ref('ds__admissions') }} da
        on da.encounter_id = dlh.encounter_id
        and da.start_datetime < dlh.start_datetime
        and (da.end_datetime > dlh.start_datetime or da.end_datetime is null)
    union all
    select
        dch.id,
        dch.encounter_id,
        dch.start_datetime,
        null as department_id,
        null as location_id,
        dch.clinician_id,
        'clinician' as type
    from {{ ref('ds__clinician_history') }} dch
    join {{ ref('ds__admissions') }} da
        on da.encounter_id = dch.encounter_id
        and da.start_datetime < dch.start_datetime
        and (da.end_datetime > dch.start_datetime or da.end_datetime is null)
)

select *
from admission_location_log
