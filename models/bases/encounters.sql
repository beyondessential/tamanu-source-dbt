select
    id,
    start_date::timestamp as start_datetime,
    case
        when end_date < start_date then start_date::timestamp
        else end_date::timestamp
    end as end_datetime,
    -- The two date columns as Tamanu stores them, uncast. Both are character(19) holding
    -- ISO-9075 ('YYYY-MM-DD HH24:MI:SS'), so they sort lexically in chronological order,
    -- and they carry the only indexes Tamanu puts on encounter dates
    -- (encounters_start_date, encounters_end_date). The ::timestamp casts above put those
    -- indexes beyond the reach of a range predicate, so a caller that needs its scan
    -- pruned compares against these instead -- see BL-008 of
    -- specs/reports/encounter-summary.md. Left bare deliberately: a cast here, of any
    -- kind, hands back the problem they exist to solve.
    start_date as start_date_iso,
    end_date as end_date_iso,
    encounter_type,
    reason_for_encounter,
    device_id,
    patient_id,
    department_id,
    location_id,
    examiner_id as clinician_id,
    patient_billing_type_id,
    referral_source_id,
    planned_location_id,
    planned_location_start_time::timestamp as planned_location_start_datetime
from {{ source('tamanu', 'encounters') }}
where deleted_at is null
    and patient_id != '{{ var("test_patient") }}'
