drop schema if exists reporting cascade;
create schema reporting;
grant usage on schema reporting to reporting;
alter default privileges in schema reporting grant select on tables to reporting;
create or replace view "reporting"."contributing_death_causes" as (
select
    cdc.id,
    cdc.time_after_onset,
    cdc.patient_death_data_id,
    cdc.condition_id
from "public"."contributing_death_causes" cdc
join "public"."patient_death_data" pdd on pdd.id = cdc.patient_death_data_id
where cdc.deleted_at is null
    and pdd.deleted_at is null
    and pdd.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."departments" as (
select
    id,
    code,
    name,
    facility_id,
    visibility_status
from "public"."departments"
where deleted_at is null
);
create or replace view "reporting"."discharges" as (
select distinct on (d.encounter_id)
    d.id,
    d.note,
    d.encounter_id,
    d.discharger_id as discharged_by_id,
    d.disposition_id
from "public"."discharges" d
join "public"."encounters" e on e.id = d.encounter_id
where d.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
order by d.encounter_id asc, d.created_at asc
);
create or replace view "reporting"."document_metadata" as (
select
    id,
    name,
    type,
    created_at::timestamp as created_datetime,
    patient_id,
    encounter_id
from "public"."document_metadata"
where deleted_at is null
);
create or replace view "reporting"."encounters" as (
select
    id,
    start_date::timestamp as start_datetime,
    case
        when end_date < start_date then start_date::timestamp
        else end_date::timestamp
    end as end_datetime,
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
    planned_location_start_time::timestamp as planned_location_start_datetime,
    discharge_draft
from "public"."encounters"
where deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."encounters_metadata" as (
with change_logs as (
    select 
        record_id,
        logged_at,
        least(record_created_at, logged_at) as created_datetime
    from "logs"."changes"
    where table_name = 'encounters'
    
)
select 
    record_id as id,
    min(created_datetime) as created_datetime,
    max(logged_at) as updated_datetime
from change_logs
group by record_id
);
create or replace view "reporting"."encounter_diagnoses" as (
select
    ed.id,
    ed.date::timestamp as datetime,
    ed.is_primary,
    ed.certainty,
    ed.encounter_id,
    ed.diagnosis_id,
    ed.clinician_id as diagnosed_by_id
from "public"."encounter_diagnoses" ed
join "public"."encounters" e on e.id = ed.encounter_id
where ed.deleted_at is null
    and ed.certainty not in ('disproven', 'error')
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."encounter_diagnoses_metadata" as (
with change_logs as (
    select 
        record_id,
        logged_at,
        least(record_created_at, logged_at) as created_datetime
    from "logs"."changes"
    where table_name = 'encounter_diagnoses'
    
)
select 
    record_id as id,
    min(created_datetime) as created_datetime,
    max(logged_at) as updated_datetime
from change_logs
group by record_id
);
create or replace view "reporting"."encounter_diets" as (
select
    ed.id,
    ed.encounter_id,
    ed.diet_id
from "public"."encounter_diets" ed
join "public"."encounters" e on e.id = ed.encounter_id
where ed.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."encounter_history" as (
select
    eh.id,
    eh.date::timestamp as datetime,
    eh.encounter_id,
    eh.department_id,
    eh.location_id,
    eh.encounter_type,
    eh.examiner_id as clinician_id,
    eh.actor_id as updated_by_id,
    eh.change_type
from "public"."encounter_history" eh
join "public"."encounters" e on e.id = eh.encounter_id
where eh.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."encounter_prescriptions" as (
select
    ep.id,
    ep.encounter_id,
    ep.prescription_id,
    ep.is_selected_for_discharge
from "public"."encounter_prescriptions" ep
join "public"."encounters" e on e.id = ep.encounter_id
where ep.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."facilities" as (
select
    id,
    code,
    name,
    division,
    type,
    email,
    contact_number,
    city_town,
    street_address,
    catchment_id,
    visibility_status,
    is_sensitive
from "public"."facilities"
where deleted_at is null
);
create or replace view "reporting"."imaging_area_external_codes" as (
select
    id,
    area_id,
    code,
    description,
    visibility_status
from "public"."imaging_area_external_codes"
where deleted_at is null
);
create or replace view "reporting"."imaging_requests" as (
select
    ir.id,
    ir.display_id,
    ir.requested_date::timestamp as datetime,
    ir.status,
    ir.priority,
    ir.imaging_type,
    ir.encounter_id,
    ir.requested_by_id,
    ir.completed_by_id,
    ir.location_id,
    ir.location_group_id,
    ir.reason_for_cancellation
from "public"."imaging_requests" ir
join "public"."encounters" e on e.id = ir.encounter_id
where ir.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."imaging_request_areas" as (
select
    ira.id,
    ira.imaging_request_id,
    ira.area_id
from "public"."imaging_request_areas" ira
join "public"."imaging_requests" ir on ir.id = ira.imaging_request_id
join "public"."encounters" e on e.id = ir.encounter_id
where ira.deleted_at is null
    and ir.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."imaging_results" as (
select
    ires.id,
    ires.completed_at::timestamp as datetime,
    ires.description,
    ires.imaging_request_id,
    ires.external_code,
    ires.completed_by_id,
    ires.visibility_status
from "public"."imaging_results" ires
join "public"."imaging_requests" ireq on ireq.id = ires.imaging_request_id
join "public"."encounters" e on e.id = ireq.encounter_id
where ires.deleted_at is null
    and ireq.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."lab_requests" as (
select
    lr.id,
    lr.created_at as created_datetime,
    lr.updated_at as updated_datetime,
    lr.display_id,
    lr.urgent as is_urgent,
    lr.status,
    lr.requested_date::timestamp as requested_datetime,
    lr.lab_test_priority_id,
    lr.lab_test_category_id,
    lr.lab_test_panel_request_id,
    lr.lab_test_laboratory_id,
    lr.requested_by_id,
    lr.specimen_attached as is_specimen_collected,
    lr.specimen_type_id,
    lr.lab_sample_site_id,
    lr.sample_time::timestamp as collected_datetime,
    lr.collected_by_id,
    lr.reason_for_cancellation,
    lr.published_date::timestamp as published_datetime,
    lr.encounter_id,
    lr.department_id
from "public"."lab_requests" lr
join "public"."encounters" e on e.id = lr.encounter_id
where lr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."lab_requests_metadata" as (
with change_logs as (
    select 
        record_id,
        logged_at,
        least(record_created_at, logged_at) as created_datetime
    from "logs"."changes"
    where table_name = 'lab_requests'
    
)
select 
    record_id as id,
    min(created_datetime) as created_datetime,
    max(logged_at) as updated_datetime
from change_logs
group by record_id
);
create or replace view "reporting"."lab_request_logs" as (
select
    lrl.id,
    lrl.created_at as created_datetime,
    lrl.updated_at as updated_datetime,
    lrl.lab_request_id,
    lrl.status,
    lrl.updated_by_id
from "public"."lab_request_logs" lrl
join "public"."lab_requests" lr on lr.id = lrl.lab_request_id
join "public"."encounters" e on e.id = lr.encounter_id
where lrl.deleted_at is null
    and lr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."lab_request_logs_metadata" as (
with change_logs as (
    select 
        record_id,
        logged_at,
        least(record_created_at, logged_at) as created_datetime
    from "logs"."changes"
    where table_name = 'lab_request_logs'
    
)
select 
    record_id as id,
    min(created_datetime) as created_datetime,
    max(logged_at) as updated_datetime
from change_logs
group by record_id
);
create or replace view "reporting"."lab_tests" as (
select
    lt.id,
    lt.date::date as date,
    lt.result,
    lt.lab_request_id,
    lt.lab_test_type_id,
    lt.lab_test_method_id,
    lt.laboratory_officer,
    lt.completed_date::timestamp as completed_datetime,
    lt.verification
from "public"."lab_tests" lt
join "public"."lab_requests" lr on lr.id = lt.lab_request_id
join "public"."encounters" e on e.id = lr.encounter_id
where lt.deleted_at is null
    and lr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."lab_test_panels" as (
select
    id,
    code,
    external_code,
    name,
    category_id,
    visibility_status
from "public"."lab_test_panels"
where deleted_at is null
);
create or replace view "reporting"."lab_test_panel_lab_test_types" as (
select
    id,
    lab_test_panel_id,
    lab_test_type_id
from "public"."lab_test_panel_lab_test_types"
where deleted_at is null
);
create or replace view "reporting"."lab_test_panel_requests" as (
select
    ltpr.id,
    ltpr.lab_test_panel_id,
    ltpr.encounter_id
from "public"."lab_test_panel_requests" ltpr
join "public"."encounters" e on e.id = ltpr.encounter_id
where ltpr.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."lab_test_types" as (
select
    id,
    code,
    external_code,
    name,
    unit,
    male_min,
    male_max,
    female_min,
    female_max,
    range_text
    as result_type,
    options,
    lab_test_category_id,
    visibility_status,
    is_sensitive
from "public"."lab_test_types"
where deleted_at is null
);
create or replace view "reporting"."locations" as (
select
    id,
    code,
    name,
    max_occupancy,
    location_group_id,
    facility_id,
    visibility_status
from "public"."locations"
where deleted_at is null
);
create or replace view "reporting"."location_bookings" as (
select
    id,
    start_time::timestamp as start_datetime,
    end_time::timestamp as end_datetime,
    patient_id,
    clinician_id,
    encounter_id,
    location_id,
    booking_type_id,
    is_high_priority,
    status
from "public"."appointments"
where booking_type_id notnull
    and deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."location_groups" as (
select
    id,
    code,
    name,
    facility_id,
    visibility_status
from "public"."location_groups"
where deleted_at is null
);
create or replace view "reporting"."notes" as (
-- May include notes for the test patient.
select
    id,
    date::timestamp as datetime,
    content,
    note_type,
    record_type,
    record_id,
    author_id as authored_by_id,
    on_behalf_of_id,
    revised_by_id as updated_note_id,
    visibility_status
from "public"."notes"
where deleted_at is null
);
create or replace view "reporting"."outpatient_appointments" as (
select
    a.id,
    a.start_time::timestamp as start_datetime,
    a.end_time::timestamp as end_datetime,
    a.patient_id,
    a.clinician_id,
    a.encounter_id,
    a.schedule_id,
    a.location_group_id,
    a.appointment_type_id,
    case
        when a.is_high_priority then 'Yes' else 'No'
    end as priority,
    a.status,
    s.until_date::date as until_date,
    s.interval,
    s.days_of_week,
    s.frequency,
    s.nth_weekday,
    s.occurrence_count,
    s.is_fully_generated,
    s.generated_until_date,
    s.cancelled_at_date
from "public"."appointments" a
left join "public"."appointment_schedules" s on s.id = a.schedule_id
where a.deleted_at is null
    and a.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
    and a.appointment_type_id notnull
);
create or replace view "reporting"."outpatient_appointments_change_logs" as (
-- Base model for outpatient appointment change logs
-- Extracts appointment modifications from logs.changes table
-- Each row represents a change event to an appointment

with appointment_changes as (
    select
        c.id as change_id,
        c.record_id as appointment_id,
        c.logged_at as modified_datetime,
        c.updated_by_user_id as modified_by_user_id,
        -- Extract current values from the change log record_data
        (c.record_data ->> 'start_time')::timestamp as start_datetime,
        (c.record_data ->> 'end_time')::timestamp as end_datetime,
        c.record_data ->> 'patient_id' as patient_id,
        c.record_data ->> 'clinician_id' as clinician_id,
        c.record_data ->> 'location_group_id' as location_group_id,
        c.record_data ->> 'appointment_type_id' as appointment_type_id,
        (c.record_data ->> 'is_high_priority')::boolean as is_high_priority,
        c.record_data ->> 'status' as status,
        (c.record_data ->> 'schedule_id')::uuid as schedule_id,
        -- Get creator from the first change_sequence (initial creation)
        first_value(c.updated_by_user_id) over (
            partition by c.record_id
            order by c.logged_at
        ) as created_by_user_id,
        -- Use LAG to get the previous record state
        lag(c.record_data) over (
            partition by c.record_id
            order by c.logged_at
        ) as previous_record_data,
        -- Track change sequence
        row_number() over (
            partition by c.record_id
            order by c.logged_at
        ) as change_sequence
    from "logs"."changes" c
    where c.table_name = 'appointments'
        and c.record_deleted_at is null
        and (c.record_data ->> 'appointment_type_id') is not null
)

select
    change_id,
    appointment_id,
    modified_datetime,
    modified_by_user_id,
    created_by_user_id,
    patient_id,
    -- Current appointment details
    start_datetime,
    end_datetime,
    clinician_id,
    location_group_id,
    appointment_type_id,
    is_high_priority,
    status,
    schedule_id,
    -- Previous appointment details
    (previous_record_data ->> 'start_time')::timestamp as prev_start_datetime,
    (previous_record_data ->> 'end_time')::timestamp as prev_end_datetime,
    (previous_record_data ->> 'clinician_id') as prev_clinician_id,
    (previous_record_data ->> 'location_group_id') as prev_location_group_id,
    (previous_record_data ->> 'appointment_type_id') as prev_appointment_type_id,
    (previous_record_data ->> 'is_high_priority')::boolean as prev_is_high_priority,
    (previous_record_data ->> 'status') as prev_status,
    change_sequence
from appointment_changes
);
create or replace view "reporting"."patients" as (
select
    id,
    created_at as created_datetime,
    updated_at as updated_datetime,
            display_id as display_id,
            first_name as first_name,
            middle_name as middle_name,
            last_name as last_name,
            cultural_name as cultural_name,
            email as email,
            initcap(sex::text) as sex,
            date_of_birth::date as date_of_birth,
            date_of_death::timestamp as date_of_death,
            village_id as village_id
from "public"."patients"
where deleted_at is null
    and id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
    and visibility_status != 'merged'
);
create or replace view "reporting"."patients_access_logs" as (
select
    id,
    user_id,
    record_id as patient_id,
    facility_id,
    logged_at at time zone 'Australia/Sydney' as logged_at,
    session_id,
    device_id,
    is_mobile,
    version,
    front_end_context,
    back_end_context
from "logs"."accesses"
where deleted_at is null
    and record_type = 'Patient'
);
create or replace view "reporting"."patients_change_logs" as (
with filtered_changes as (
    select 
        id as changelog_id,
        logged_at,
        updated_by_user_id,
        record_created_at,
        record_updated_at,
        record_id,
        record_data
    from "logs"."changes"
    where table_name = 'patients'
        and record_id not in (
            select id::text
            from "public"."patients" t 
            where t.deleted_at notnull
        )
        and record_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'

)

select
    fc.changelog_id,
    fc.logged_at at time zone 'Australia/Sydney' as logged_at,
    fc.updated_by_user_id,
    fc.record_id as id,
            fc.record_data ->> 'display_id' as display_id,
            fc.record_data ->> 'first_name' as first_name,
            fc.record_data ->> 'middle_name' as middle_name,
            fc.record_data ->> 'last_name' as last_name,
            fc.record_data ->> 'cultural_name' as cultural_name,
            fc.record_data ->> 'email' as email,
            initcap(fc.record_data ->> 'sex') as sex,
            (fc.record_data ->> 'date_of_birth')::date as date_of_birth,
            (fc.record_data ->> 'date_of_death')::timestamp as date_of_death,
            fc.record_data ->> 'village_id' as village_id,
            (fc.record_data ->> 'created_at')::date as registration_date
from filtered_changes fc
);
create or replace view "reporting"."patients_merged" as (
select
    id,
            display_id as display_id,
            first_name as first_name,
            middle_name as middle_name,
            last_name as last_name,
            cultural_name as cultural_name,
            email as email,
            initcap(sex::text) as sex,
            date_of_birth::date as date_of_birth,
            date_of_death::timestamp as date_of_death,
            village_id as village_id,
            created_at::date as registration_date
from "public"."patients"
where deleted_at is null
    and id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
    and visibility_status = 'merged'
);
create or replace view "reporting"."patients_metadata" as (
with change_logs as (
    select 
        record_id,
        logged_at,
        least(record_created_at, logged_at) as created_datetime
    from "logs"."changes"
    where table_name = 'patients'
    
)
select 
    record_id as id,
    min(created_datetime) as created_datetime,
    max(logged_at) as updated_datetime
from change_logs
group by record_id
);
create or replace view "reporting"."patient_additional_data" as (
select
    patient_id,
            title as title,
            marital_status as marital_status,
            primary_contact_number as primary_contact_number,
            secondary_contact_number as secondary_contact_number,
            emergency_contact_name as emergency_contact_name,
            emergency_contact_number as emergency_contact_number,
            social_media as social_media,
            ethnicity_id as ethnicity_id,
            religion_id as religion_id,
            nationality_id as nationality_id,
            secondary_village_id as secondary_village_id,
            country_id as country_id,
            division_id as division_id,
            subdivision_id as subdivision_id,
            medical_area_id as medical_area_id,
            nursing_zone_id as nursing_zone_id,
            settlement_id as settlement_id,
            city_town as city_town,
            street_village as street_village,
            country_of_birth_id as country_of_birth_id,
            place_of_birth as place_of_birth,
            birth_certificate as birth_certificate,
            driving_license as driving_license,
            passport as passport,
            educational_level as educational_level,
            occupation_id as occupation_id,
            blood_type as blood_type,
            patient_billing_type_id as patient_billing_type_id,
            health_center_id as health_center_id,
            insurer_id as insurer_id,
            insurer_policy_number as insurer_policy_number,
            mother_id as mother_id,
            father_id as father_id,
            registered_by_id as registered_by_id,
            updated_at_by_field as updated_by_field,
            created_at::date as registration_date
from "public"."patient_additional_data"
where deleted_at is null
    and id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."patient_additional_data_change_logs" as (
with filtered_changes as (
    select 
        id as changelog_id,
        logged_at,
        updated_by_user_id,
        record_created_at,
        record_updated_at,
        record_id,
        record_data
    from "logs"."changes"
    where table_name = 'patient_additional_data'
        and record_id not in (
            select id::text
            from "public"."patient_additional_data" t 
            where t.deleted_at notnull
        )
        and record_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3' -- noqa: ST10

)

select
    fc.changelog_id,
    fc.logged_at at time zone 'Australia/Sydney' as logged_at,
    fc.updated_by_user_id,
    fc.record_id as patient_id,
            fc.record_data ->> 'title' as title,
            fc.record_data ->> 'marital_status' as marital_status,
            fc.record_data ->> 'primary_contact_number' as primary_contact_number,
            fc.record_data ->> 'secondary_contact_number' as secondary_contact_number,
            fc.record_data ->> 'emergency_contact_name' as emergency_contact_name,
            fc.record_data ->> 'emergency_contact_number' as emergency_contact_number,
            fc.record_data ->> 'social_media' as social_media,
            fc.record_data ->> 'ethnicity_id' as ethnicity_id,
            fc.record_data ->> 'religion_id' as religion_id,
            fc.record_data ->> 'nationality_id' as nationality_id,
            fc.record_data ->> 'secondary_village_id' as secondary_village_id,
            fc.record_data ->> 'country_id' as country_id,
            fc.record_data ->> 'division_id' as division_id,
            fc.record_data ->> 'subdivision_id' as subdivision_id,
            fc.record_data ->> 'medical_area_id' as medical_area_id,
            fc.record_data ->> 'nursing_zone_id' as nursing_zone_id,
            fc.record_data ->> 'settlement_id' as settlement_id,
            fc.record_data ->> 'city_town' as city_town,
            fc.record_data ->> 'street_village' as street_village,
            fc.record_data ->> 'country_of_birth_id' as country_of_birth_id,
            fc.record_data ->> 'place_of_birth' as place_of_birth,
            fc.record_data ->> 'birth_certificate' as birth_certificate,
            fc.record_data ->> 'driving_license' as driving_license,
            fc.record_data ->> 'passport' as passport,
            fc.record_data ->> 'educational_level' as educational_level,
            fc.record_data ->> 'occupation_id' as occupation_id,
            fc.record_data ->> 'blood_type' as blood_type,
            fc.record_data ->> 'patient_billing_type_id' as patient_billing_type_id,
            fc.record_data ->> 'health_center_id' as health_center_id,
            fc.record_data ->> 'insurer_id' as insurer_id,
            fc.record_data ->> 'insurer_policy_number' as insurer_policy_number,
            fc.record_data ->> 'mother_id' as mother_id,
            fc.record_data ->> 'father_id' as father_id,
            fc.record_data ->> 'registered_by_id' as registered_by_id,
            fc.record_data -> 'updated_at_by_field' as updated_by_field,
            (fc.record_data ->> 'created_at')::date as registration_date
from filtered_changes fc
);
create or replace view "reporting"."patient_allergies" as (
select
    id,
    patient_id,
    allergy_id,
    recorded_date::date as recorded_date,
    practitioner_id as recorded_by
from "public"."patient_allergies"
where deleted_at is null
);
create or replace view "reporting"."patient_birth_data" as (
select
    patient_id,
    time_of_birth::time as birth_time,
    gestational_age_estimate,
    attendant_at_birth,
    name_of_attendant_at_birth,
    birth_type,
    birth_delivery_type,
    birth_weight,
    birth_length,
    apgar_score_one_minute,
    apgar_score_five_minutes,
    apgar_score_ten_minutes,
    registered_birth_place,
    birth_facility_id,
    created_at::date as registration_date
from "public"."patient_birth_data"
where deleted_at is null
    and id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."patient_care_plans" as (
select
    id,
    date::timestamp as care_plan_datetime,
    patient_id,
    examiner_id as clinician_id,
    care_plan_id
from "public"."patient_care_plans"
where deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."patient_conditions" as (
select
    id,
    recorded_date::timestamp as recorded_datetime,
    note,
    condition_id,
    patient_id,
    examiner_id as recorded_by_id,
    resolved as is_resolved,
    resolution_date::timestamp as resolved_datetime,
    resolution_practitioner_id as resolved_by_id,
    resolution_note
from "public"."patient_conditions"
where deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."patient_death_contributing_causes" as (
select
    cdc.id,
    cdc.time_after_onset as mins_after_onset,
    cdc.patient_death_data_id,
    cdc.condition_id
from "public"."contributing_death_causes" cdc
join "public"."patient_death_data" pdd on pdd.id = cdc.patient_death_data_id
where cdc.deleted_at is null
    and pdd.deleted_at is null
    and pdd.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."patient_death_data" as (
select
    id,
    manner,
    recent_surgery as had_recent_surgery,
    last_surgery_date::date as last_surgery_date,
    last_surgery_reason_id,
    external_cause_date::date as external_cause_date,
    external_cause_location,
    external_cause_notes,
    was_pregnant,
    pregnancy_contributed,
    fetal_or_infant as was_fetal_or_infant,
    stillborn as was_stillborn,
    birth_weight,
    within_day_of_birth as was_within_day_of_birth,
    hours_survived_since_birth,
    carrier_age,
    carrier_pregnancy_weeks,
    carrier_existing_condition_id,
    outside_health_facility as was_outside_health_facility,
    primary_cause_time_after_onset as primary_cause_mins_after_onset,
    primary_cause_condition_id,
    antecedent_cause1_time_after_onset as antecedent_cause1_mins_after_onset,
    antecedent_cause1_condition_id,
    antecedent_cause2_time_after_onset as antecedent_cause2_mins_after_onset,
    antecedent_cause2_condition_id,
    antecedent_cause3_time_after_onset as antecedent_cause3_mins_after_onset,
    antecedent_cause3_condition_id,
    patient_id,
    clinician_id as recorded_by_id,
    facility_id,
    is_final,
    visibility_status
from "public"."patient_death_data"
where deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."patient_family_histories" as (
select
    id,
    recorded_date::timestamp as recorded_datetime,
    patient_id,
    practitioner_id as clinician_id,
    diagnosis_id,
    relationship,
    note
from "public"."patient_family_histories"
where deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."patient_field_values" as (
select
    patient_id,
    definition_id,
    value
from "public"."patient_field_values"
where deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."patient_program_registrations" as (
select
    id,
    date::timestamp as datetime,
    registration_status,
    patient_id,
    program_registry_id,
    clinical_status_id,
    clinician_id as registered_by_id,
    registering_facility_id,
    facility_id,
    village_id,
    deactivated_clinician_id as deactivated_by_id,
    deactivated_date::timestamp as deactivated_datetime
from "public"."patient_program_registrations"
where deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."patient_program_registrations_change_logs" as (
with filtered_changes as (
    select 
        id as changelog_id,
        logged_at,
        updated_by_user_id,
        record_created_at,
        record_updated_at,
        record_id,
        record_data
    from "logs"."changes"
    where table_name = 'patient_program_registrations'
        and record_id not in (
            select id::text
            from "public"."patient_program_registrations" t 
            where t.deleted_at notnull
        )
        and (
            version = 'unknown'
            or string_to_array(version, '.')::int [] >= string_to_array('2.33.0', '.')::int []
        )
        and record_data ->> 'patient_id' != 'h1627394-3778-4c31-a510-9fcb88efdbf3'

)

select
    fc.changelog_id,
    fc.logged_at,
    fc.updated_by_user_id,
    fc.record_id as id,
    (fc.record_data ->> 'date')::timestamp as datetime,
    fc.record_data ->> 'registration_status' as registration_status,
    fc.record_data ->> 'patient_id' as patient_id,
    fc.record_data ->> 'program_registry_id' as program_registry_id,
    fc.record_data ->> 'clinical_status_id' as clinical_status_id,
    fc.record_data ->> 'clinician_id' as registered_by_id,
    fc.record_data ->> 'registering_facility_id' as registering_facility_id,
    fc.record_data ->> 'facility_id' as facility_id,
    fc.record_data ->> 'village_id' as village_id,
    fc.record_data ->> 'deactivated_clinician_id' as deactivated_by_id,
    (fc.record_data ->> 'deactivated_date')::timestamp as deactivated_datetime
from filtered_changes fc
);
create or replace view "reporting"."patient_program_registration_conditions" as (
select
    pprc.id,
    pprc.date::timestamp as datetime,
    pprc.program_registry_condition_id,
    pprc.patient_program_registration_id,
    pprc.program_registry_condition_category_id,
    pprc.reason_for_change,
    pprc.clinician_id as recorded_by_id,
    pprc.deletion_date::timestamp as deleted_datetime,
    pprc.deletion_clinician_id as deleted_by_id
from "public"."patient_program_registration_conditions" pprc
join "public"."patient_program_registrations" ppr
    on ppr.id = pprc.patient_program_registration_id
where pprc.deleted_at is null
    and ppr.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."patient_program_registration_conditions_change_logs" as (
with filtered_changes as (
    select 
        id as changelog_id,
        logged_at,
        updated_by_user_id,
        record_created_at,
        record_updated_at,
        record_id,
        record_data
    from "logs"."changes"
    where table_name = 'patient_program_registration_conditions'
        and record_id not in (
            select id::text
            from "public"."patient_program_registration_conditions" t 
            where t.deleted_at notnull
        )
        and (
            version = 'unknown'
            or string_to_array(version, '.')::int [] >= string_to_array('2.33.0', '.')::int []
        )

)

select
    fc.changelog_id,
    fc.logged_at,
    fc.updated_by_user_id,
    fc.record_id as id,
    (fc.record_data ->> 'date')::timestamp as datetime,
    fc.record_data ->> 'program_registry_condition_id' as program_registry_condition_id,
    fc.record_data ->> 'patient_program_registration_id' as patient_program_registration_id,
    fc.record_data ->> 'program_registry_condition_category_id' as program_registry_condition_category_id,
    fc.record_data ->> 'reason_for_change' as reason_for_change,
    fc.record_data ->> 'clinician_id' as recorded_by_id,
    (fc.record_data ->> 'deletion_date')::timestamp as deleted_datetime,
    fc.record_data ->> 'deletion_clinician_id' as deleted_by_id
from filtered_changes fc
);
create or replace view "reporting"."patient_vaccinations_upcoming" as (
select
    patient_id,
    scheduled_vaccine_id as vaccine_schedules_id,
    vaccine_category,
    vaccine_id,
    due_date::date,
    days_till_due,
    status
from "public"."upcoming_vaccinations"
where patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."prescriptions" as (
select
    p.id,
    p.date::timestamp as datetime,
    p.start_date::timestamp as start_datetime,
    p.end_date::timestamp as end_datetime,
    p.medication_id,
    p.prescriber_id,
    p.indication,
    p.route,
    p.quantity,
    p.repeats,
    p.is_ongoing,
    p.is_prn,
    p.is_variable_dose,
    p.dose_amount,
    p.units,
    p.frequency,
    p.duration_value,
    p.duration_unit,
    p.is_phone_order,
    p.ideal_times,
    p.discontinued as is_discontinued,
    p.discontinuing_clinician_id as discontinued_by_id,
    p.discontinuing_reason,
    p.discontinued_date::timestamp as discontinued_datetime
from "public"."prescriptions" p
join "public"."encounter_prescriptions" ep
    on ep.prescription_id = p.id
join "public"."encounters" e
    on e.id = ep.encounter_id
where p.deleted_at is null
    and ep.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."procedures" as (
select
    p.id,
    p.date::date as date,
    p.start_time::timestamp::time as start_time,
    p.end_time::timestamp::time as end_time,
    p.completed as is_completed,
    p.note,
    p.completed_note,
    p.encounter_id,
    p.location_id,
    p.procedure_type_id,
    p.anaesthetic_id,
    p.physician_id as clinician_id,
    p.anaesthetist_id,
    p.assistant_anaesthetist_id,
    p.time_in::time as time_in,
    p.time_out::time as time_out
from "public"."procedures" p
join "public"."encounters" e on e.id = p.encounter_id
where p.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."procedures_metadata" as (
with change_logs as (
    select 
        record_id,
        logged_at,
        least(record_created_at, logged_at) as created_datetime
    from "logs"."changes"
    where table_name = 'procedures'
    
)
select 
    record_id as id,
    min(created_datetime) as created_datetime,
    max(logged_at) as updated_datetime
from change_logs
group by record_id
);
create or replace view "reporting"."programs" as (
select
    id,
    code,
    name
from "public"."programs"
where deleted_at is null
);
create or replace view "reporting"."program_data_elements" as (
select
    id,
    code,
    name,
    type,
    indicator,
    default_text,
    default_options,
    visualisation_config
from "public"."program_data_elements"
where deleted_at is null
);
create or replace view "reporting"."program_registries" as (
select
    id,
    code,
    name,
    currently_at_type,
    visibility_status,
    program_id
from "public"."program_registries"
where deleted_at is null
);
create or replace view "reporting"."program_registry_clinical_statuses" as (
select
    id,
    code,
    name,
    color,
    visibility_status,
    program_registry_id
from "public"."program_registry_clinical_statuses"
where deleted_at is null
);
create or replace view "reporting"."program_registry_conditions" as (
select
    id,
    code,
    name,
    visibility_status,
    program_registry_id
from "public"."program_registry_conditions"
where deleted_at is null
);
create or replace view "reporting"."program_registry_condition_categories" as (
select
    id,
    code,
    name,
    visibility_status,
    program_registry_id
from "public"."program_registry_condition_categories"
where deleted_at is null
);
create or replace view "reporting"."reference_data" as (
select
    id,
    code,
    name,
    type,
    visibility_status
from "public"."reference_data"
where deleted_at is null
);
create or replace view "reporting"."referrals" as (
select
    id,
    status,
    referred_facility,
    initiating_encounter_id,
    survey_response_id
from "public"."referrals"
where deleted_at is null
);
create or replace view "reporting"."refresh_tokens" as (
select
    id,
    device_id,
    user_id,
    expires_at,
    created_at,
    updated_at
from
    "public"."refresh_tokens"
where deleted_at is null
);
create or replace view "reporting"."roles" as (
select
    id,
    name
from "public"."roles"
where deleted_at is null
);
create or replace view "reporting"."surveys" as (
select
    id,
    code,
    name,
    survey_type,
    is_sensitive,
    notifiable as is_notifiable,
    notify_email_addresses,
    program_id,
    visibility_status
from "public"."surveys"
where deleted_at is null
);
create or replace view "reporting"."survey_responses" as (
select
    id,
    start_time::timestamp as start_datetime,
    end_time::timestamp as end_datetime,
    result_text,
    notified as is_notified,
    survey_id,
    encounter_id,
    user_id as submitted_by_id
from "public"."survey_responses"
where deleted_at is null
);
create or replace view "reporting"."survey_response_answers" as (
select
    id,
    name,
    body,
    response_id,
    data_element_id
from "public"."survey_response_answers"
where deleted_at is null
);
create or replace view "reporting"."survey_screen_components" as (
select
    id,
    screen_index,
    component_index,
    text,
    visibility_criteria,
    validation_criteria,
    detail,
    config,
    options,
    calculation,
    survey_id,
    data_element_id,
    visibility_status
from "public"."survey_screen_components"
where deleted_at is null
);
create or replace view "reporting"."triages" as (
select
    t.id,
    t.arrival_time::timestamp as arrival_datetime,
    t.triage_time::timestamp as triage_datetime,
    t.closed_time::timestamp as closed_datetime,
    t.arrival_mode_id,
    t.score,
    t.encounter_id,
    t.practitioner_id as clinician_id,
    t.chief_complaint_id,
    t.secondary_complaint_id
from "public"."triages" t
join "public"."encounters" e on e.id = t.encounter_id
where t.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."users" as (
select
    id,
    display_id,
    display_name,
    email,
    phone_number,
    role,
    visibility_status
from "public"."users"
where deleted_at is null
);
create or replace view "reporting"."users_metadata" as (
with change_logs as (
    select 
        record_id,
        logged_at,
        least(record_created_at, logged_at) as created_datetime
    from "logs"."changes"
    where table_name = 'users'
    
)
select 
    record_id as id,
    min(created_datetime) as created_datetime,
    max(logged_at) as updated_datetime
from change_logs
group by record_id
);
create or replace view "reporting"."vaccine_administrations" as (
select
    av.id,
    av.date::timestamp as datetime,
    av.encounter_id,
    av.location_id,
    av.department_id,
    av.scheduled_vaccine_id,
    av.status,
    av.reason,
    av.not_given_reason_id,
    av.batch,
    av.vaccine_name,
    av.vaccine_brand,
    av.disease,
    av.consent as is_consented,
    av.consent_given_by,
    av.injection_site,
    av.given_by,
    av.given_elsewhere as is_given_elsewhere,
    av.circumstance_ids,
    av.recorder_id as recorded_by_id
from "public"."administered_vaccines" av
join "public"."encounters" e on e.id = av.encounter_id
where av.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."vaccine_schedules" as (
select
    id,
    category,
    vaccine_id,
    label,
    dose_label,
    index,
    weeks_from_birth_due,
    weeks_from_last_vaccination_due,
    sort_index,
    visibility_status
from "public"."scheduled_vaccines"
where deleted_at is null
);
create or replace view "reporting"."vaccine_administrations_change_logs" as (
with filtered_changes as (
    select
        av.changelog_id,
        av.logged_at,
        av.updated_by_user_id,
        av.record_created_at,
        av.record_updated_at,
        av.record_id,
        av.record_data
    from (select 
        id as changelog_id,
        logged_at,
        updated_by_user_id,
        record_created_at,
        record_updated_at,
        record_id,
        record_data
    from "logs"."changes"
    where table_name = 'administered_vaccines'
        and record_id not in (
            select id::text
            from "public"."administered_vaccines" t 
            where t.deleted_at notnull
        )) av
    join "reporting"."encounters" e on e.id = av.record_data ->> 'encounter_id'

)

select
    fc.changelog_id,
    fc.logged_at at time zone 'Australia/Sydney' as logged_at,
    fc.record_created_at at time zone 'Australia/Sydney' as created_at,
    fc.record_updated_at at time zone 'Australia/Sydney' as updated_at,
    fc.updated_by_user_id,
    fc.record_id as id,
    (fc.record_data ->> 'date')::timestamp as datetime,
    fc.record_data ->> 'batch' as batch,
    (fc.record_data ->> 'consent')::boolean as is_consented,
    fc.record_data ->> 'disease' as disease,
    fc.record_data ->> 'given_by' as given_by,
    (fc.record_data ->> 'given_elsewhere')::boolean as is_given_elsewhere,
    fc.record_data ->> 'circumstance_ids' as circumstance_ids,
    fc.record_data ->> 'recorder_id' as recorded_by_id,
    fc.record_data ->> 'encounter_id' as encounter_id,
    fc.record_data ->> 'location_id' as location_id,
    fc.record_data ->> 'department_id' as department_id,
    fc.record_data ->> 'vaccine_name' as vaccine_name,
    fc.record_data ->> 'vaccine_brand' as vaccine_brand,
    fc.record_data ->> 'injection_site' as injection_site,
    fc.record_data ->> 'consent_given_by' as consent_given_by,
    fc.record_data ->> 'scheduled_vaccine_id' as scheduled_vaccine_id,
    fc.record_data ->> 'status' as status,
    fc.record_data ->> 'reason' as reason,
    fc.record_data ->> 'not_given_reason_id' as not_given_reason_id
from filtered_changes fc
);
create or replace view "reporting"."ds__admissions" as (
with admission_encounters as (
    select
        e.id,
        e.patient_id,
        e.start_datetime,
        e.end_datetime,
        e.location_id,
        e.patient_billing_type_id,
        f.id as facility_id,
        f.name as facility_name
    from "reporting"."encounters" e
    join "reporting"."locations" l on l.id = e.location_id
    join "reporting"."facilities" f on f.id = l.facility_id
    where e.encounter_type = 'admission'
        and not f.is_sensitive
),

encounter_history_consolidated as (
    select
        eh.encounter_id,
        eh.datetime,
        eh.change_type,
        eh.clinician_id,
        eh.department_id,
        eh.location_id,
        u.display_name as clinician_name,
        d.name as department_name,
        l.name as location_name,
        lg.id as location_group_id,
        lg.name as location_group_name,
        -- Window functions for ordering and lag operations
        row_number() over (
            partition by eh.encounter_id, eh.change_type
            order by eh.datetime
        ) as change_sequence,
        lag(lg.id) over (
            partition by eh.encounter_id
            order by eh.datetime
        ) as prev_location_group_id
    from admission_encounters ae
    left join "reporting"."encounter_history" eh
        on eh.encounter_id = ae.id
        and eh.encounter_type = 'admission'
        and (eh.change_type is null or eh.change_type in ('encounter_type', 'examiner', 'department', 'location'))
    left join "reporting"."users" u
        on u.id = eh.clinician_id
    left join "reporting"."departments" d
        on d.id = eh.department_id
    left join "reporting"."locations" l
        on l.id = eh.location_id
    left join "reporting"."location_groups" lg
        on lg.id = l.location_group_id
),

-- Clinician changes and admitting clinician logic
clinician_data as (
    select
        encounter_id,
        bool_or(change_type = 'encounter_type' and change_sequence = 1) as is_transfer,
        min(datetime) filter (where change_type is null or change_type in ('encounter_type', 'examiner')) as admission_datetime,
        array_agg(
            datetime
            order by datetime
        ) filter (where change_type is null or change_type in ('encounter_type', 'examiner')
        ) as clinician_datetimes,
        array_agg(
            clinician_id
            order by datetime
        ) filter (where change_type is null or change_type in ('encounter_type', 'examiner')
        ) as clinician_ids,
        array_agg(
            clinician_name
            order by datetime
        ) filter (where change_type is null or change_type in ('encounter_type', 'examiner')
        ) as clinician_names
    from encounter_history_consolidated
    group by encounter_id
),

-- Admitting clinician determination
admitting_clinicians as (
    select
        encounter_id,
        admission_datetime,
        case
            when is_transfer and array_length(clinician_ids, 1) > 1
                then clinician_ids[2]
            else clinician_ids[1]
        end as admitting_clinician_id,
        case
            when is_transfer and array_length(clinician_names, 1) > 1
                then clinician_names[2]
            else clinician_names[1]
        end as admitting_clinician_name
    from clinician_data
),

-- Department changes aggregation
department_changes as (
    select
        encounter_id,
        string_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI'),
            '; '
            order by datetime
        ) as department_datetimes,
        array_agg(
            department_id
            order by datetime
        ) as department_ids,
        string_agg(
            department_name, ', '
            order by datetime
        ) as departments
    from encounter_history_consolidated
    where change_type is null or change_type in ('encounter_type', 'department')
    group by encounter_id
),

-- Location changes aggregation
location_changes as (
    select
        encounter_id,
        string_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI'),
            '; '
            order by datetime
        ) as location_datetimes,
        array_agg(
            location_id
            order by datetime
        ) as location_ids,
        string_agg(
            location_name, ', '
            order by datetime
        ) as locations
    from encounter_history_consolidated
    where change_type is null or change_type in ('encounter_type', 'location')
    group by encounter_id
),

-- Location group changes (deduplicated in single pass)
location_group_changes as (
    select
        encounter_id,
        string_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI'),
            '; '
            order by datetime
        ) as location_group_datetimes,
        array_agg(
            location_group_id
            order by datetime
        ) as location_group_ids,
        string_agg(
            location_group_name, ', '
            order by datetime
        ) as location_groups
    from encounter_history_consolidated
    where (change_type is null or change_type in ('encounter_type', 'location'))
        and (location_group_id != prev_location_group_id or prev_location_group_id is null)
    group by encounter_id
),

-- Diagnoses aggregation
encounter_diagnoses as (
    select
        ed.encounter_id,
        string_agg(
            case when ed.is_primary
                    then rd.name || ' (' || rd.code || ')'
            end,
            '; '
            order by ed.datetime
        ) as primary_diagnoses,
        string_agg(
            case when not ed.is_primary
                    then rd.name || ' (' || rd.code || ')'
            end,
            '; '
            order by ed.datetime
        ) as secondary_diagnoses
    from admission_encounters ae
    inner join "reporting"."encounter_diagnoses" ed
        on ed.encounter_id = ae.id
    inner join "reporting"."reference_data" rd
        on rd.id = ed.diagnosis_id
    where ed.certainty not in ('disproven', 'error')
    group by ed.encounter_id
),

-- Patient and reference data
patient_data as (
    select
        ae.id as encounter_id,
        p.id as patient_id,
        p.display_id,
        p.first_name,
        p.last_name,
        p.date_of_birth,
        p.sex,
        p.village_id,
        village.name as village_name,
        ae.patient_billing_type_id,
        bt.name as billing_type_name,
        ae.start_datetime,
        ae.end_datetime,
        ae.location_id,
        ae.facility_id,
        ae.facility_name
    from admission_encounters ae
    left join "reporting"."patients" p
        on p.id = ae.patient_id
    left join "reporting"."reference_data" village
        on village.id = p.village_id
    left join "reporting"."reference_data" bt
        on bt.id = ae.patient_billing_type_id
)

select
    pd.patient_id,
    pd.display_id,
    pd.first_name,
    pd.last_name,
    pd.date_of_birth,
    date_part('year', age(ac.admission_datetime, pd.date_of_birth)) as age,
    initcap(pd.sex::text) as sex,
    pd.village_id,
    pd.village_name as village,
    pd.patient_billing_type_id as billing_type_id,
    pd.billing_type_name as billing_type,
    ac.admitting_clinician_id,
    ac.admitting_clinician_name as admitting_clinician,
    ac.admission_datetime,
    case
        when pd.end_datetime is null then 'active'
        else 'discharged'
    end as admission_status,
    pd.end_datetime as discharge_datetime,
    pd.facility_id,
    pd.facility_name as facility,
    dc.department_ids,
    dc.departments,
    dc.department_datetimes,
    lgc.location_group_ids,
    lgc.location_groups,
    lgc.location_group_datetimes,
    lc.location_ids,
    lc.locations,
    lc.location_datetimes,
    ed.primary_diagnoses,
    ed.secondary_diagnoses
from patient_data pd
left join admitting_clinicians ac
    on ac.encounter_id = pd.encounter_id
left join department_changes dc
    on dc.encounter_id = pd.encounter_id
left join location_changes lc
    on lc.encounter_id = pd.encounter_id
left join location_group_changes lgc
    on lgc.encounter_id = pd.encounter_id
left join encounter_diagnoses ed
    on ed.encounter_id = pd.encounter_id
);
create or replace view "reporting"."ds__births" as (
select
    pbd.registration_date,
    case
        when left(pbd.registration_date::text, 10) = left(pad.registration_date::text, 10) then u.display_name
    end as registered_by,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    rd_ethnicity.name as ethnicity,
    rd_nationality.name as nationality,
    p.village_id,
    rd_village.name as village,
    case
        when
            p_mother.id is not null
            then concat(p_mother.first_name, ' ', p_mother.last_name, ' (', p_mother.display_id, ')')
    end as mother,
    case
        when
            p_father.id is not null
            then concat(p_father.first_name, ' ', p_father.last_name, ' (', p_father.display_id, ')')
    end as father,
    pbd.birth_time,
    pbd.gestational_age_estimate,
    case when pbd.registered_birth_place = 'health_facility' then 'Health facility'
        when pbd.registered_birth_place = 'home' then 'Home'
        when pbd.registered_birth_place = 'other' then 'Other'
        else pbd.registered_birth_place
    end as registered_birth_place,
    f.id as birth_facility_id,
    f.name as birth_facility,
    case when pbd.attendant_at_birth = 'doctor' then 'Doctor'
        when pbd.attendant_at_birth = 'midwife' then 'Midwife'
        when pbd.attendant_at_birth = 'nurse' then 'Nurse'
        when pbd.attendant_at_birth = 'traditional_birth_attentdant' then 'Traditional birth attendant'
        when pbd.attendant_at_birth = 'other' then 'Other'
        else pbd.attendant_at_birth
    end as attendant_at_birth,
    pbd.name_of_attendant_at_birth,
    case
        when pbd.birth_delivery_type = 'normal_vaginal_delivery' then 'Normal vaginal delivery'
        when pbd.birth_delivery_type = 'breech' then 'Breech'
        when pbd.birth_delivery_type = 'emergency_c_section' then 'Emergency C-section'
        when pbd.birth_delivery_type = 'elective_c_section' then 'Elective C-section'
        when pbd.birth_delivery_type = 'vacuum_extraction' then 'Vacuum extraction'
        when pbd.birth_delivery_type = 'forceps' then 'Forceps'
        when pbd.birth_delivery_type = 'other' then 'Other'
        else pbd.birth_delivery_type
    end as birth_delivery_type,
    initcap(pbd.birth_type::text) as birth_type,
    pbd.birth_weight,
    pbd.birth_length,
    pbd.apgar_score_one_minute,
    pbd.apgar_score_five_minutes,
    pbd.apgar_score_ten_minutes
from "reporting"."patient_birth_data" pbd
join "reporting"."patients" p on p.id = pbd.patient_id
left join "reporting"."reference_data" rd_village on rd_village.id = p.village_id
left join "reporting"."patient_additional_data" pad on pad.patient_id = p.id
left join "reporting"."reference_data" rd_nationality on rd_nationality.id = pad.nationality_id
left join "reporting"."reference_data" rd_ethnicity on rd_ethnicity.id = pad.ethnicity_id
left join "reporting"."patients" p_mother on p_mother.id = pad.mother_id
left join "reporting"."patients" p_father on p_father.id = pad.father_id
left join "reporting"."facilities" f on f.id = pbd.birth_facility_id
left join "reporting"."users" u on u.id = pad.registered_by_id
);
create or replace view "reporting"."ds__deaths" as (
with contributing_death_causes as (
    select
        cdc.patient_death_data_id,
        array_agg(
            cdc.condition_id
            order by cdc.time_after_onset
        ) as other_conditions
    from "reporting"."contributing_death_causes" cdc
    group by cdc.patient_death_data_id
),

encounters_with_death as (
    select distinct on (e.patient_id)
        e.patient_id,
        e.start_datetime,
        e.end_datetime,
        e.location_id,
        e.department_id,
        e.clinician_id
    from "reporting"."encounters" e
    join "reporting"."patients" p
        on p.id = e.patient_id
        and p.date_of_death between e.start_datetime and e.end_datetime
    order by e.patient_id asc, e.end_datetime desc
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(p.date_of_death::date, p.date_of_birth::date)) as age,
    p.sex,
    village.id as village_id,
    village.name as village,
    nationality.id as nationality_id,
    nationality.name as nationality,
    case
        when pdd.was_outside_health_facility then 'Died outside health facility'
        else facility.name
    end as place_of_death,
    facility.id as facility_id,
    department.id as department_id,
    department.name as department,
    location_group.id as location_group_id,
    location_group.name as location_group,
    location.id as location_id,
    location.name as location,
    p.date_of_death,
    clinician.id as attending_clinician_id,
    clinician.display_name as attending_clinician,
    primary_condition.id as primary_cause_condition_id,
    primary_condition.name as primary_cause_condition,
    case
        when pdd.primary_cause_mins_after_onset is null or pdd.primary_cause_mins_after_onset = 0
            then '0 minutes'
        when mod(pdd.primary_cause_mins_after_onset, (60 * 24 * 365)) = 0
            then concat(pdd.primary_cause_mins_after_onset / (60 * 24 * 365), ' years')
        when mod(pdd.primary_cause_mins_after_onset, (60 * 24 * 30)) = 0
            then concat(pdd.primary_cause_mins_after_onset / (60 * 24 * 30), ' months')
        when mod(pdd.primary_cause_mins_after_onset, (60 * 24 * 7)) = 0
            then concat(pdd.primary_cause_mins_after_onset / (60 * 24 * 7), ' weeks')
        when mod(pdd.primary_cause_mins_after_onset, (60 * 24)) = 0
            then concat(pdd.primary_cause_mins_after_onset / (60 * 24), ' days')
        when mod(pdd.primary_cause_mins_after_onset, 60) = 0
            then concat(pdd.primary_cause_mins_after_onset / 60, ' hours')
        else concat(pdd.primary_cause_mins_after_onset, ' minutes')
    end as time_between_onset_and_death,
    antecedent_condition_1.id as antecedent_cause_1_id,
    antecedent_condition_1.name as antecedent_cause_1,
    antecedent_condition_2.id as antecedent_cause_2_id,
    antecedent_condition_2.name as antecedent_cause_2,
    other_condition_1.id as other_condition_1_id,
    other_condition_1.name as other_condition_1,
    other_condition_2.id as other_condition_2_id,
    other_condition_2.name as other_condition_2,
    other_condition_3.id as other_condition_3_id,
    other_condition_3.name as other_condition_3,
    other_condition_4.id as other_condition_4_id,
    other_condition_4.name as other_condition_4,
    initcap(pdd.had_recent_surgery) as had_recent_surgery,
    pdd.last_surgery_date,
    surgery_reason.id as reason_for_surgery_id,
    surgery_reason.name as reason_for_surgery,
    pdd.manner as manner_of_death,
    pdd.external_cause_date,
    pdd.external_cause_location,
    initcap(pdd.was_pregnant) as was_pregnant,
    pdd.pregnancy_contributed,
    case
        when pdd.was_fetal_or_infant then 'Yes'
        else 'No'
    end as was_fetal_or_infant,
    initcap(pdd.was_stillborn) as was_stillborn,
    pdd.birth_weight,
    pdd.carrier_pregnancy_weeks as completed_weeks_of_pregnancy,
    pdd.carrier_age as age_of_mother,
    carrier_condition.name as condition_in_mother_affecting_fetus_or_newborn,
    case
        when pdd.was_within_day_of_birth then 'Yes'
        else 'No'
    end as death_within_day_of_birth,
    pdd.hours_survived_since_birth
from "reporting"."patient_death_data" pdd
join "reporting"."patients" p
    on p.id = pdd.patient_id
left join "reporting"."patient_additional_data" pd
    on pd.patient_id = p.id
left join "reporting"."reference_data" village
    on village.id = p.village_id
left join "reporting"."reference_data" nationality
    on nationality.id = pd.nationality_id
left join "reporting"."reference_data" primary_condition
    on primary_condition.id = pdd.primary_cause_condition_id
left join "reporting"."reference_data" antecedent_condition_1
    on antecedent_condition_1.id = pdd.antecedent_cause1_condition_id
left join "reporting"."reference_data" antecedent_condition_2
    on antecedent_condition_2.id = pdd.antecedent_cause2_condition_id
left join contributing_death_causes cdc
    on cdc.patient_death_data_id = pdd.id
left join "reporting"."reference_data" other_condition_1
    on other_condition_1.id = cdc.other_conditions[1]
left join "reporting"."reference_data" other_condition_2
    on other_condition_2.id = cdc.other_conditions[2]
left join "reporting"."reference_data" other_condition_3
    on other_condition_3.id = cdc.other_conditions[3]
left join "reporting"."reference_data" other_condition_4
    on other_condition_4.id = cdc.other_conditions[4]
left join "reporting"."reference_data" surgery_reason
    on surgery_reason.id = pdd.last_surgery_reason_id
left join "reporting"."reference_data" carrier_condition
    on carrier_condition.id = pdd.carrier_existing_condition_id
left join encounters_with_death ewd
    on ewd.patient_id = p.id
left join "reporting"."facilities" facility
    on facility.id = pdd.facility_id
left join "reporting"."departments" department
    on department.id = ewd.department_id
left join "reporting"."locations" location
    on location.id = ewd.location_id
left join "reporting"."location_groups" location_group
    on location_group.id = location.location_group_id
left join "reporting"."users" clinician
    on clinician.id = pdd.recorded_by_id
where pdd.visibility_status = 'current'
    and pdd.is_final
);
create or replace view "reporting"."ds__diagnoses" as (
select
    e.id as encounter_id,
    p.id as patient_id,
    diagnosis.id as diagnosis_id,
    diagnosis.name as diagnosis,
    ed.datetime as diagnosis_datetime,
    p.first_name,
    p.last_name,
    p.display_id,
    date_part('year', age(ed.datetime::date, p.date_of_birth)) as age,
    p.sex,
    coalesce(pad.primary_contact_number, pad.secondary_contact_number) as contact_number,
    village.id as village_id,
    village.name as village,
    clinician.id as clinician_id,
    clinician.display_name as clinician,
    d.id as department_id,
    d.name as department,
    l.id as location_id,
    l.name as location,
    f.id as facility_id,
    f.name as facility,
    initcap(ed.certainty) as certainty,
    case when ed.is_primary = true then 'Yes' else 'No' end as is_primary
from "reporting"."encounter_diagnoses" ed
join "reporting"."reference_data" diagnosis on diagnosis.id = ed.diagnosis_id
join "reporting"."encounters" e on e.id = ed.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
left join "reporting"."patient_additional_data" pad on pad.patient_id = p.id
left join "reporting"."reference_data" village on village.id = p.village_id
left join "reporting"."users" clinician on clinician.id = e.clinician_id
left join "reporting"."departments" d on d.id = e.department_id
join "reporting"."locations" l on l.id = e.location_id
join "reporting"."facilities" f
    on f.id = l.facility_id
    and not f.is_sensitive
);
create or replace view "reporting"."ds__encounters_emergency" as (
select
    t.id as triage_id,
    t.arrival_datetime,
    t.triage_datetime,
    t.closed_datetime,
    t.score,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    p.village_id,
    village.name as village,
    e.id as encounter_id,
    e.encounter_type,
    arrival_mode.name as arrival_mode,
    chief_complaint.name as chief_complaint,
    secondary_complaint.name as secondary_complaint,
    clinician.display_name as clinician,
    t.clinician_id,
    f.id as facility_id,
    f.name as facility
from "reporting"."triages" t
join "reporting"."encounters" e on e.id = t.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
left join "reporting"."locations" l on l.id = e.location_id
left join "reporting"."facilities" f on f.id = l.facility_id
left join "reporting"."reference_data" village on village.id = p.village_id
left join "reporting"."reference_data" arrival_mode on arrival_mode.id = t.arrival_mode_id
left join "reporting"."reference_data" chief_complaint on chief_complaint.id = t.chief_complaint_id
left join "reporting"."reference_data" secondary_complaint on secondary_complaint.id = t.secondary_complaint_id
left join "reporting"."users" clinician on clinician.id = t.clinician_id
);
create or replace view "reporting"."ds__encounter_diets" as (
with diets as (
    select
        ed.encounter_id,
        string_agg(
            rd.name, ', '
            order by rd.name
        ) as diets
    from "reporting"."encounter_diets" ed
    join "reporting"."reference_data" rd
        on rd.id = ed.diet_id
    group by ed.encounter_id
),

allergies as (
    select
        pa.patient_id,
        string_agg(
            rd.name, ', '
            order by rd.name
        ) as allergies 
    from "reporting"."patient_allergies" pa
    join "reporting"."reference_data" rd
        on rd.id = pa.allergy_id
    group by pa.patient_id
)

select
    e.id as encounter_id,
    p.id as patient_id,
    p.display_id,
    concat(p.first_name, ' ', p.last_name) as patient_name,
    e.start_datetime,
    case
        when age(current_date, p.date_of_birth) < interval '8 days'
            then concat(extract(day from age(current_date, p.date_of_birth)), ' days')
        when age(current_date, p.date_of_birth) >= interval '8 days'
            and age(current_date, p.date_of_birth) < interval '1 month'
            then concat(extract(week from age(current_date, p.date_of_birth)), ' weeks')
        when age(current_date, p.date_of_birth) >= interval '1 month'
            and age(current_date, p.date_of_birth) < interval '2 years'
            then concat(extract(month from age(current_date, p.date_of_birth)), ' months')
        when age(current_date, p.date_of_birth) >= interval '2 years'
            then concat(extract(year from age(current_date, p.date_of_birth)), ' years')
    end as age,
    l.id as location_id,
    l.name as location,
    lg.id as location_group_id,
    lg.name as location_group,
    d.diets,
    a.allergies
from "reporting"."encounters" e
join "reporting"."patients" p
    on p.id = e.patient_id
join "reporting"."locations" l
    on l.id = e.location_id
join "reporting"."facilities" f
    on f.id = l.facility_id
    and not f.is_sensitive
left join "reporting"."location_groups" lg
    on lg.id = l.location_group_id
left join diets d
    on d.encounter_id = e.id
left join allergies a
    on a.patient_id = p.id
where e.end_datetime is null
);
create or replace view "reporting"."ds__encounter_prescriptions" as (


select
    ep.encounter_id,
    ep.prescription_id,
    pr.datetime,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(pr.datetime, p.date_of_birth)) as age,
    p.sex,
    coalesce(pd.primary_contact_number, pd.secondary_contact_number) as contact_number,
    vil.id as village_id,
    vil.name as village,
    l.facility_id,
    f.name as facility,
    ep.is_selected_for_discharge,
    pr.medication_id,
    m.code as medication_code,
    m.name as medication,
    pr.route,
    pr.quantity,
    pr.repeats,
    pr.is_ongoing,
    pr.is_prn,
    pr.is_variable_dose,
    pr.dose_amount,
    pr.units,
    pr.frequency,
    pr.is_discontinued,
    pr.discontinued_by_id,
    pr.discontinuing_reason,
    pr.discontinued_datetime
from "reporting"."encounter_prescriptions" ep
join "reporting"."encounters" e on e.id = ep.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
join "reporting"."prescriptions" pr on pr.id = ep.prescription_id
join "reporting"."locations" l on l.id = e.location_id
join "reporting"."facilities" f 
    on f.id = l.facility_id
    and f.is_sensitive = False
left join "reporting"."patient_additional_data" pd on pd.patient_id = p.id
left join "reporting"."reference_data" vil on vil.id = p.village_id
join "reporting"."reference_data" m on m.id = pr.medication_id


);
create or replace view "reporting"."ds__imaging_requests" as (
with results as (
    select
        imaging_request_id,
        min(datetime) as completed_datetime
    from "reporting"."imaging_results"
    group by imaging_request_id
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(ir.datetime::date, p.date_of_birth)) as age,
    p.sex,
    v.id as village_id,
    v.name as village,
    f.id as facility_id,
    f.name as facility,
    d.id as department_id,
    d.name as department,
    lg.id as location_group_id,
    lg.name as location_group,
    ir.display_id as request_id,
    ir.datetime as requested_datetime,
    su.id as supervising_clinician_id,
    su.display_name as supervising_clinician,
    ru.id as requesting_clinician_id,
    ru.display_name as requesting_clinician,
    case
        when ir.priority = 'routine' then 'Routine'
        when ir.priority = 'urgent' then 'Urgent'
        when ir.priority = 'asap' then 'ASAP'
        when ir.priority = 'stat' then 'STAT'
        when ir.priority = 'today' then 'Today'
        else ir.priority
    end as priority,
    ir.imaging_type as imaging_type_id,
    case
        when ir.imaging_type = 'xRay' then 'X-Ray'
        when ir.imaging_type = 'ctScan' then 'CT Scan'
        when ir.imaging_type = 'ultrasound' then 'Ultrasound'
        when ir.imaging_type = 'mri' then 'MRI'
        when ir.imaging_type = 'ecg' then 'ECG'
        when ir.imaging_type = 'holterMonitor' then 'Holter Monitor'
        when ir.imaging_type = 'echocardiogram' then 'Echocardiogram'
        when ir.imaging_type = 'mammogram' then 'Mammogram'
        when ir.imaging_type = 'endoscopy' then 'Endoscopy'
        when ir.imaging_type = 'fluroscopy' then 'Fluroscopy'
        when ir.imaging_type = 'angiogram' then 'Angiogram'
        when ir.imaging_type = 'colonoscopy' then 'Colonoscopy'
        when ir.imaging_type = 'vascularStudy' then 'Vascular Study'
        when ir.imaging_type = 'stressTest' then 'Stress Test'
        else ir.imaging_type
    end as imaging_type,
    case
        when ia.id is not null then ia.name
        else n.content
    end as imaging_area,
    ir.status as status_id,
    case
        when ir.status = 'pending' then 'Pending'
        when ir.status = 'in_progress' then 'In progress'
        when ir.status = 'completed' then 'Completed'
        when ir.status = 'cancelled' then 'Cancelled'
        when ir.status = 'deleted' then 'Deleted'
        when ir.status = 'entered_in_error' then 'Entered in error'
        else 'Unknown'
    end as status,
    case
        when ir.status = 'completed' then irs.completed_datetime
    end as completed_datetime,
    case
        when ir.reason_for_cancellation = 'clinical' then 'Clinical reason'
        when ir.reason_for_cancellation = 'duplicate' then 'Duplicate'
        when ir.reason_for_cancellation = 'entered-in-error' then 'Entered in error'
        when ir.reason_for_cancellation = 'patient-discharged' then 'Patient discharged'
        when ir.reason_for_cancellation = 'patient-refused' then 'Patient refused'
        when ir.reason_for_cancellation = 'other' then 'Other'
    end as reason_for_cancellation
from "reporting"."imaging_requests" ir
join "reporting"."encounters" e on e.id = ir.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
join "reporting"."locations" l on l.id = e.location_id
left join "reporting"."location_groups" lg on lg.id = l.location_group_id
join "reporting"."facilities" f
    on f.id = l.facility_id
    and not f.is_sensitive
left join "reporting"."departments" d on d.id = e.department_id
left join "reporting"."users" su on su.id = e.clinician_id
left join "reporting"."users" ru on ru.id = ir.requested_by_id
left join "reporting"."notes" n
    on n.record_id = ir.id and n.record_type = 'ImagingRequest' and n.note_type = 'areaToBeImaged'
left join "reporting"."imaging_request_areas" ira on ira.imaging_request_id = ir.id
left join "reporting"."reference_data" ia on ia.id = ira.area_id
left join "reporting"."reference_data" v on v.id = p.village_id
left join results irs on irs.imaging_request_id = ir.id
);
create or replace view "reporting"."ds__lab_requests" as (


with lab_test_data as (
    select
        lr.id as lab_request_id,
        string_agg(ltt.name, ', '
            order by ltt.name
        ) as tests,
        max(lt.completed_datetime) as completed_datetime
    from "reporting"."lab_requests" lr
    join "reporting"."lab_tests" lt on lt.lab_request_id = lr.id
    join "reporting"."lab_test_types" ltt on ltt.id = lt.lab_test_type_id
    where ltt.is_sensitive = False
    group by lr.id
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(lr.requested_datetime, p.date_of_birth)) as age,
    p.sex,
    village.id as village_id,
    village.name as village,
    f.id as facility_id,
    f.name as facility,
    d.name as department,
    d.id as department_id,
    l.id as location_id,
    l.name as location,
    lg.id as location_group_id,
    lg.name as location_group,
    laboratory.id as laboratory_id,
    laboratory.name as laboratory,
    lr.display_id as request_id,
    case lr.status
        when 'reception_pending' then 'Reception pending'
        when 'results_pending' then 'Results pending'
        when 'to_be_verified' then 'To be verified'
        when 'verified' then 'Verified'
        when 'published' then 'Published'
        when 'cancelled' then 'Cancelled'
        when 'deleted' then 'Deleted'
        when 'sample-not-collected' then 'Sample not collected'
        when 'entered-in-error' then 'Entered in error'
        else lr.status
    end as status,
    lr.status as status_id,
    lr.requested_datetime,
    req_clinician.id as requested_by_id,
    req_clinician.display_name as requested_by,
    lr.department_id as requesting_department_id,
    req_department.name as requesting_department,
    lr.lab_test_priority_id as priority_id,
    priority.name as priority,
    category.id as lab_test_category_id,
    category.name as lab_test_category,
    ltp.name as lab_test_panel,
    lta.tests,
    lr.collected_datetime,
    lr.collected_by_id,
    collector.display_name as collected_by,
    lr.specimen_type_id,
    specimen.name as specimen_type,
    site.name as site,
    lta.completed_datetime,
    case lr.reason_for_cancellation
        when 'clinical' then 'Clinical reason'
        when 'duplicate' then 'Duplicate'
        when 'entered-in-error' then 'Entered in error'
        when 'patient-discharged' then 'Patient discharged'
        when 'patient-refused' then 'Patient refused'
        when 'other' then 'Other'
        else lr.reason_for_cancellation
    end as reason_for_cancellation
from "reporting"."lab_requests" lr
join lab_test_data lta on lta.lab_request_id = lr.id
join "reporting"."encounters" e on e.id = lr.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
left join "reporting"."reference_data" village on village.id = p.village_id
left join "reporting"."locations" l on l.id = e.location_id
left join "reporting"."location_groups" lg on lg.id = l.location_group_id
left join "reporting"."departments" d on d.id = e.department_id
left join "reporting"."facilities" f on f.id = l.facility_id
left join "reporting"."reference_data" laboratory on laboratory.id = lr.lab_test_laboratory_id
left join "reporting"."users" req_clinician on req_clinician.id = lr.requested_by_id
left join "reporting"."departments" req_department on req_department.id = lr.department_id
left join "reporting"."reference_data" priority on priority.id = lr.lab_test_priority_id
left join "reporting"."reference_data" category on category.id = lr.lab_test_category_id
left join "reporting"."users" collector on collector.id = lr.collected_by_id
left join "reporting"."reference_data" specimen on specimen.id = lr.specimen_type_id
left join "reporting"."reference_data" site on site.id = lr.lab_sample_site_id
left join "reporting"."lab_test_panel_requests" ltpr
    on ltpr.id = lr.lab_test_panel_request_id
left join "reporting"."lab_test_panels" ltp on ltp.id = ltpr.lab_test_panel_id


);
create or replace view "reporting"."ds__lab_tests" as (


select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(lr.requested_datetime, p.date_of_birth::date)) as age,
    p.sex,
    village.id as village_id,
    village.name as village,
    f.id as facility_id,
    f.name as facility,
    d.id as department_id,
    d.name as department,
    req_dept.id as requesting_department_id,
    req_dept.name as requesting_department,
    lg.id as location_group_id,
    lg.name as location_group,
    l.id as location_id,
    l.name as location,
    lr.display_id as lab_request_id,
    lr.status as status_id,
    case lr.status
        when 'reception_pending' then 'Reception pending'
        when 'results_pending' then 'Results pending'
        when 'to_be_verified' then 'To be verified'
        when 'verified' then 'Verified'
        when 'published' then 'Published'
        when 'cancelled' then 'Cancelled'
        when 'deleted' then 'Deleted'
        when 'sample-not-collected' then 'Sample not collected'
        when 'entered-in-error' then 'Entered in error'
        else lr.status
    end as status,
    ltp.id as lab_test_panel_id,
    ltp.name as lab_test_panel,
    category.id as lab_test_category_id,
    category.name as lab_test_category,
    lr.requested_datetime,
    requester.id as requested_by_id,
    requester.display_name as requested_by,
    lr.published_datetime as lab_request_published_datetime,
    lt.date as lab_test_date,
    lt.result,
    lt.verification,
    ltt.id as lab_test_type_id,
    ltt.name as lab_test_type,
    lt.completed_datetime as lab_test_completed_datetime
from "reporting"."lab_requests" lr
join "reporting"."encounters" e on e.id = lr.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
left join "reporting"."reference_data" village on village.id = p.village_id
left join "reporting"."locations" l on l.id = e.location_id
left join "reporting"."location_groups" lg on lg.id = l.location_group_id
left join "reporting"."departments" d on d.id = e.department_id
left join "reporting"."departments" req_dept on req_dept.id = lr.department_id
left join "reporting"."facilities" f on f.id = l.facility_id
left join "reporting"."users" requester on requester.id = lr.requested_by_id
left join "reporting"."lab_test_panel_requests" ltpr on ltpr.id = lr.lab_test_panel_request_id
left join "reporting"."lab_test_panels" ltp on ltp.id = ltpr.lab_test_panel_id
left join "reporting"."reference_data" category on category.id = lr.lab_test_category_id
join "reporting"."lab_tests" lt on lt.lab_request_id = lr.id
join "reporting"."lab_test_types" ltt on ltt.id = lt.lab_test_type_id
where ltt.is_sensitive = False


);
create or replace view "reporting"."ds__location_bookings" as (
select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(a.start_datetime::date, p.date_of_birth)) as age,
    p.sex,
    vil.id as village_id,
    vil.name as village,
    billing.id as billing_type_id,
    billing.name as billing_type,
    a.start_datetime as booking_start_datetime,
    a.end_datetime as booking_end_datetime,
    a.status as booking_status,
    u.id as clinician_id,
    u.display_name as clinician,
    lg.id as location_group_id,
    lg.name as location_group,
    l.id as location_id,
    l.name as location,
    a.booking_type_id,
    bt.name as booking_type
from "reporting"."location_bookings" a
join "reporting"."patients" p on p.id = a.patient_id
left join "reporting"."users" u on u.id = a.clinician_id
join "reporting"."locations" l on l.id = a.location_id
left join "reporting"."location_groups" lg on lg.id = l.location_group_id
join "reporting"."facilities" f on f.id = l.facility_id
    and not f.is_sensitive
left join "reporting"."patient_additional_data" pd on pd.patient_id = p.id
left join "reporting"."reference_data" billing on billing.id = pd.patient_billing_type_id
left join "reporting"."reference_data" vil on vil.id = p.village_id
left join "reporting"."reference_data" bt on bt.id = a.booking_type_id
);
create or replace view "reporting"."ds__ongoing_conditions" as (
select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(pc.recorded_datetime::date, p.date_of_birth)) as age,
    p.sex,
    village.name as village,
    village.id as village_id,
    conditions.name as condition,
    conditions.id as condition_id,
    pc.recorded_datetime,
    clinician.id as clinician_id,
    clinician.display_name as clinician,
    case when pc.is_resolved then pc.resolved_datetime end as date_resolved,
    case when pc.is_resolved then resolving_clinician.display_name end as clinician_resolving
from "reporting"."patient_conditions" pc
join "reporting"."patients" p on p.id = pc.patient_id
join "reporting"."reference_data" conditions on conditions.id = pc.condition_id
left join "reporting"."reference_data" village on village.id = p.village_id
left join "reporting"."users" clinician on clinician.id = pc.recorded_by_id
left join "reporting"."users" resolving_clinician
    on resolving_clinician.id = pc.resolved_by_id
);
create or replace view "reporting"."ds__outpatient_appointments" as (
with appointment_creators as (
    select
        appointment_id,
        created_by_user_id
    from "reporting"."outpatient_appointments_change_logs"
    where change_sequence = 1
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(a.start_datetime, p.date_of_birth)) as age,
    p.sex,
    coalesce(pd.primary_contact_number, pd.secondary_contact_number) as contact_number,
    vil.id as village_id,
    vil.name as village,
    billing.id as billing_type_id,
    billing.name as billing_type,
    a.start_datetime as appointment_start_datetime,
    a.end_datetime as appointment_end_datetime,
    a.appointment_type_id,
    apt.name as appointment_type,
    a.status as appointment_status,
    u.id as clinician_id,
    u.display_name as clinician,
    lg.id as location_group_id,
    lg.name as location_group,
    a.priority,
    a.schedule_id,
    a.until_date,
    a.interval,
    a.days_of_week,
    a.frequency,
    a.nth_weekday,
    ac.created_by_user_id,
    creator.display_name as created_by
from "reporting"."outpatient_appointments" a
join "reporting"."patients" p on p.id = a.patient_id
left join "reporting"."users" u on u.id = a.clinician_id
join "reporting"."location_groups" lg on lg.id = a.location_group_id
join "reporting"."facilities" f on f.id = lg.facility_id
    and not f.is_sensitive
left join "reporting"."patient_additional_data" pd on pd.patient_id = p.id
left join "reporting"."reference_data" billing on billing.id = pd.patient_billing_type_id
left join "reporting"."reference_data" vil on vil.id = p.village_id
left join "reporting"."reference_data" apt on apt.id = a.appointment_type_id
left join appointment_creators ac on ac.appointment_id = a.id
left join "reporting"."users" creator on creator.id = ac.created_by_user_id
);
create or replace view "reporting"."ds__patients" as (
select
    p.created_datetime as registration_date,
    u.display_name as registered_by,
    p.id as patient_id,
    p.first_name,
    p.middle_name,
    p.last_name,
    p.cultural_name,
    p.display_id,
    p.sex,
    p.village_id,
    village.name as village,
    p.date_of_birth,
    p.date_of_death,
    pad.birth_certificate,
    pad.driving_license,
    pad.passport,
    pad.blood_type,
    pad.title,
    pad.marital_status,
    pad.primary_contact_number,
    pad.secondary_contact_number,
    cob.name as country_of_birth,
    nationality.name as nationality,
    ethnicity.name as ethnicity,
    occupation.name as occupation,
    religion.name as religion,
    billing.name as patient_billing_type,
    pad.mother_id,
    pad.father_id,
    pad.street_village,
    case
        when pbd.patient_id is null then 'Patient'
        else 'Birth'
    end as registration_type,
    date_part(
        'year',
        age(
            coalesce(p.date_of_death::date, current_date),
            p.date_of_birth
        )
    ) as age,
    case
        when p.date_of_death is not null then 'Deceased'
        else 'Alive'
    end as status
from "reporting"."patients" p
left join "reporting"."patient_additional_data" pad on pad.patient_id = p.id
left join "reporting"."patient_birth_data" pbd on pbd.patient_id = p.id
left join "reporting"."users" u on u.id = pad.registered_by_id
left join "reporting"."reference_data" village on village.id = p.village_id and village.type = 'village'
left join "reporting"."reference_data" cob on cob.id = pad.country_of_birth_id and cob.type = 'country'
left join "reporting"."reference_data" nationality on nationality.id = pad.nationality_id and nationality.type = 'nationality'
left join "reporting"."reference_data" ethnicity on ethnicity.id = pad.ethnicity_id and ethnicity.type = 'ethnicity'
left join "reporting"."reference_data" occupation on occupation.id = pad.occupation_id and occupation.type = 'occupation'
left join "reporting"."reference_data" religion on religion.id = pad.religion_id and religion.type = 'religion'
left join "reporting"."reference_data" billing on billing.id = pad.patient_billing_type_id and billing.type = 'patientBillingType'
);
create or replace view "reporting"."ds__patients_access_logs" as (
with grouped_access_logs as (
    select
        lap.patient_id,
        lap.user_id,
        lap.facility_id,
        date_trunc('minute', min(lap.logged_at)) as date_time_viewed,
        -- Take the first values for fields that might vary within the same minute
        lap.is_mobile,
        lap.session_id,
        lap.device_id
    from "reporting"."patients_access_logs" lap
    group by
        lap.patient_id,
        lap.user_id,
        lap.facility_id,
        lap.is_mobile,
        lap.session_id,
        lap.device_id
)

select
    gal.patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    p.village_id,
    village.name as village,
    gal.user_id as viewed_by_user_id,
    u.display_name as viewed_by_user,
    u.email as user_email,
    u.role as user_role,
    f.name as viewed_at_facility,
    gal.date_time_viewed,
    gal.facility_id,
    gal.is_mobile,
    gal.session_id,
    gal.device_id
from grouped_access_logs gal
join "reporting"."patients" p on p.id = gal.patient_id
left join "reporting"."users" u on u.id = gal.user_id
left join "reporting"."facilities" f on f.id = gal.facility_id
left join "reporting"."reference_data" village on village.id = p.village_id
);
create or replace view "reporting"."ds__patients_change_logs" as (
with patient_edits as (
    -- Patient details edits
    select
        lcp.id as patient_id,
        lcp.display_id,
        lcp.first_name,
        lcp.last_name,
        lcp.date_of_birth,
        lcp.sex,
        lcp.village_id,
        lcp.updated_by_user_id,
        lcp.logged_at
    from "reporting"."patients_change_logs" lcp

    union all

    -- Patient additional data edits
    select
        lcpad.patient_id,
        p.display_id,
        p.first_name,
        p.last_name,
        p.date_of_birth,
        p.sex,
        p.village_id,
        lcpad.updated_by_user_id,
        lcpad.logged_at
    from "reporting"."patient_additional_data_change_logs" lcpad
    left join "reporting"."patients" p on p.id = lcpad.patient_id
),

grouped_edits as (
    select
        pe.patient_id,
        pe.display_id,
        pe.first_name,
        pe.last_name,
        pe.date_of_birth,
        pe.sex,
        pe.village_id,
        pe.updated_by_user_id,
        date_trunc('minute', pe.logged_at) as edited_datetime
    from patient_edits pe
    group by
        pe.patient_id,
        pe.display_id,
        pe.first_name,
        pe.last_name,
        pe.date_of_birth,
        pe.sex,
        pe.village_id,
        pe.updated_by_user_id,
        date_trunc('minute', pe.logged_at)
)

select
    ge.patient_id,
    ge.display_id,
    ge.first_name,
    ge.last_name,
    ge.date_of_birth,
    ge.sex,
    ge.village_id,
    village.name as village,
    ge.updated_by_user_id as edited_by_user_id,
    u.display_name as edited_by_user,
    u.email as user_email,
    u.role as user_role,
    ge.edited_datetime
from grouped_edits ge
left join "reporting"."users" u on u.id = ge.updated_by_user_id
left join "reporting"."reference_data" village on village.id = ge.village_id
);
create or replace view "reporting"."ds__patient_program_registrations" as (
with related_conditions as (
    select
        ppr.id as patient_program_registration_id,
        string_agg(
            prc.name, '; '
            order by pprc.datetime
        ) as conditions,
        array_agg(
            pprc.program_registry_condition_id
            order by pprc.datetime
        ) as condition_ids,
        string_agg(
            prcc.name, '; '
            order by pprc.datetime
        ) as condition_categories,
        array_agg(
            pprc.program_registry_condition_category_id
            order by pprc.datetime
        ) as condition_category_ids
    from "reporting"."patient_program_registration_conditions" pprc
    join "reporting"."patient_program_registrations" ppr on ppr.id = pprc.patient_program_registration_id
    left join "reporting"."program_registry_conditions" prc on prc.id = pprc.program_registry_condition_id
    left join "reporting"."program_registry_condition_categories" prcc on prcc.id = pprc.program_registry_condition_category_id
    group by ppr.id
)

select
    ppr.id as patient_program_registration_id,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.sex,
    village.id as village_id,
    village.name as village,
    registering_facility.id as registering_facility_id,
    registering_facility.name as registering_facility,
    registered_by.id as registered_by_id,
    registered_by.display_name as registered_by,
    case
        when pr.currently_at_type = 'facility' then currently_at_facility.name
        when pr.currently_at_type = 'village' then currently_at_village.name
    end as currently_at,
    pr.currently_at_type,
    c.condition_ids as related_condition_ids,
    c.conditions as related_conditions,
    c.condition_category_ids as related_condition_category_ids,
    c.condition_categories as related_condition_categories,
    prcs.id as clinical_status_id,
    prcs.name as clinical_status,
    ppr.registration_status,
    ppr.program_registry_id,
    subdivision.id as subdivision_id,
    subdivision.name as subdivision,
    division.id as division_id,
    division.name as division,
    ppr.datetime as registration_datetime,
    ppr.deactivated_by_id,
    deactivated_by.display_name as deactivated_by,
    ppr.deactivated_datetime,
    pad.primary_contact_number,
    pad.secondary_contact_number,
    pad.emergency_contact_name,
    pad.emergency_contact_number
from "reporting"."patient_program_registrations" ppr
join "reporting"."program_registries" pr on pr.id = ppr.program_registry_id
join "reporting"."patients" p on p.id = ppr.patient_id
left join "reporting"."patient_additional_data" pad on pad.patient_id = p.id
left join "reporting"."facilities" registering_facility on registering_facility.id = ppr.registering_facility_id
left join "reporting"."users" registered_by on registered_by.id = ppr.registered_by_id
left join "reporting"."reference_data" village on village.id = p.village_id
left join "reporting"."facilities" currently_at_facility on currently_at_facility.id = ppr.facility_id
left join "reporting"."reference_data" subdivision on subdivision.id = pad.subdivision_id
left join "reporting"."reference_data" division on division.id = pad.division_id
left join "reporting"."reference_data" currently_at_village on currently_at_village.id = ppr.village_id
left join related_conditions c on c.patient_program_registration_id = ppr.id
left join "reporting"."program_registry_clinical_statuses" prcs on prcs.id = ppr.clinical_status_id
left join "reporting"."users" deactivated_by on deactivated_by.id = ppr.deactivated_by_id
);
create or replace view "reporting"."ds__patient_vaccinations_upcoming" as (
select
    p.display_id,
    p.first_name,
    p.last_name,
    p.id as patient_id,
    p.date_of_birth,
    date_part('year', age(p.date_of_birth)) as age,
    p.sex,
    village.id as village_id,
    village.name as village,
    pvu.due_date,
    pvu.vaccine_category,
    pvu.vaccine_schedules_id,
    sv.label as vaccine_name,
    sv.dose_label as vaccine_schedule,
    pvu.status as vaccine_status
from "reporting"."patient_vaccinations_upcoming" pvu
join "reporting"."patients" p on p.id = pvu.patient_id
join "reporting"."vaccine_schedules" sv on sv.id = pvu.vaccine_schedules_id
left join "reporting"."reference_data" village on village.id = p.village_id
where p.date_of_death is null
);
create or replace view "reporting"."ds__procedures" as (
with filtered_procedure as (
    select
        pc.*,
        eh.department_id,
        eh.encounter_type,
        row_number() over (
            partition by pc.id
            order by eh.datetime desc
        ) as encounter_history_record
    from "reporting"."procedures" pc
    left join "reporting"."encounter_history" eh
        on eh.encounter_id = pc.encounter_id
        and eh.datetime::date <= pc.date
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(pc.date, p.date_of_birth)) as age,
    p.sex,
    nationality.name as nationality,
    encounter_facility.id as encounter_facility_id,
    encounter_facility.name as encounter_facility,
    encounter_department.id as encounter_department_id,
    encounter_department.name as encounter_department,
    case
        when coalesce(pc.encounter_type, e.encounter_type) = 'admission' then 'Hospital Admission'
        when coalesce(pc.encounter_type, e.encounter_type) = 'clinic' then 'Clinic'
        when coalesce(pc.encounter_type, e.encounter_type) in ('triage', 'observation', 'emergency') then 'Triage'
    end as encounter_type,
    e.start_datetime as encounter_start_datetime,
    e.end_datetime as encounter_end_datetime,
    procedure_facility.id as procedure_facility_id,
    procedure_facility.name as procedure_facility,
    procedure_area.id as procedure_area_id,
    procedure_area.name as procedure_area,
    procedure_location.id as procedure_location_id,
    procedure_location.name as procedure_location,
    procedure_type.id as procedure_type_id,
    procedure_type.name as procedure_type,
    pc.date as procedure_date,
    pc.start_time as procedure_start_time,
    pc.end_time as procedure_end_time,
    case
        when pc.end_time is not null and pc.start_time is not null then
            concat(
                lpad((
                    case
                        when pc.end_time < pc.start_time
                            then
                                (24 + extract(hour from pc.end_time) - extract(hour from pc.start_time))
                        else
                            extract(hour from (pc.end_time - pc.start_time))
                    end
                )::text, 2, '0'), ':',
                lpad((
                    case
                        when pc.end_time < pc.start_time
                            then
                                (extract(minute from pc.end_time) - extract(minute from pc.start_time))
                        else
                            extract(minute from (pc.end_time - pc.start_time))
                    end
                )::text, 2, '0')
            )
    end as procedure_duration,
    clinician.id as procedure_clinician_id,
    clinician.display_name as procedure_clinician,
    anaesthetist.id as procedure_anaesthetist_id,
    anaesthetist.display_name as procedure_anaesthetist,
    assistant_anaesthetist.id as procedure_assistant_anaesthetist_id,
    assistant_anaesthetist.display_name as procedure_assistant_anaesthetist,
    case
        when pc.is_completed then 'Y' else 'N'
    end as is_completed,
    pc.time_in,
    pc.time_out
from filtered_procedure pc
join "reporting"."encounters" e on e.id = pc.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
join "reporting"."reference_data" procedure_type on procedure_type.id = pc.procedure_type_id
join "reporting"."locations" procedure_location
    on procedure_location.id = pc.location_id
left join "reporting"."location_groups" procedure_area
    on procedure_area.id = procedure_location.location_group_id
join "reporting"."facilities" procedure_facility
    on procedure_facility.id = procedure_location.facility_id
    and not procedure_facility.is_sensitive
join "reporting"."locations" encounter_location
    on encounter_location.id = e.location_id
join "reporting"."facilities" encounter_facility
    on encounter_facility.id = encounter_location.facility_id
    and not encounter_facility.is_sensitive
join "reporting"."departments" encounter_department
    on encounter_department.id = coalesce(pc.department_id, e.department_id)
left join "reporting"."patient_additional_data" pd on pd.patient_id = p.id
left join "reporting"."reference_data" nationality on nationality.id = pd.nationality_id
left join "reporting"."users" assistant_anaesthetist on assistant_anaesthetist.id = pc.assistant_anaesthetist_id
left join "reporting"."users" anaesthetist on anaesthetist.id = pc.anaesthetist_id
left join "reporting"."users" clinician on clinician.id = pc.clinician_id
where pc.encounter_history_record = 1
);
create or replace view "reporting"."ds__referrals" as (
with diagnoses as (
    select
        ed.encounter_id,
        string_agg(concat(d.name), '; ') as diagnoses
    from "reporting"."encounter_diagnoses" ed
    left join "reporting"."reference_data" d on d.id = ed.diagnosis_id
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
    d.name as department
from "reporting"."referrals" rf
join "reporting"."encounters" e on e.id = rf.initiating_encounter_id
join "reporting"."locations" l on l.id = e.location_id
join "reporting"."facilities" f 
    on f.id = l.facility_id
    and not f.is_sensitive
join "reporting"."survey_responses" sr on sr.id = rf.survey_response_id
join "reporting"."surveys" s on s.id = sr.survey_id
join "reporting"."patients" p on p.id = e.patient_id
join "reporting"."users" u on u.id = e.clinician_id
join "reporting"."departments" d on d.id = e.department_id
left join diagnoses ed on ed.encounter_id = rf.initiating_encounter_id
);
create or replace view "reporting"."ds__sensitive_encounter_prescriptions" as (


select
    ep.encounter_id,
    ep.prescription_id,
    pr.datetime,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(pr.datetime, p.date_of_birth)) as age,
    p.sex,
    coalesce(pd.primary_contact_number, pd.secondary_contact_number) as contact_number,
    vil.id as village_id,
    vil.name as village,
    l.facility_id,
    f.name as facility,
    ep.is_selected_for_discharge,
    pr.medication_id,
    m.code as medication_code,
    m.name as medication,
    pr.route,
    pr.quantity,
    pr.repeats,
    pr.is_ongoing,
    pr.is_prn,
    pr.is_variable_dose,
    pr.dose_amount,
    pr.units,
    pr.frequency,
    pr.is_discontinued,
    pr.discontinued_by_id,
    pr.discontinuing_reason,
    pr.discontinued_datetime
from "reporting"."encounter_prescriptions" ep
join "reporting"."encounters" e on e.id = ep.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
join "reporting"."prescriptions" pr on pr.id = ep.prescription_id
join "reporting"."locations" l on l.id = e.location_id
join "reporting"."facilities" f 
    on f.id = l.facility_id
    and f.is_sensitive = True
left join "reporting"."patient_additional_data" pd on pd.patient_id = p.id
left join "reporting"."reference_data" vil on vil.id = p.village_id
join "reporting"."reference_data" m on m.id = pr.medication_id


);
create or replace view "reporting"."ds__sensitive_lab_requests" as (


with lab_test_data as (
    select
        lr.id as lab_request_id,
        string_agg(ltt.name, ', '
            order by ltt.name
        ) as tests,
        max(lt.completed_datetime) as completed_datetime
    from "reporting"."lab_requests" lr
    join "reporting"."lab_tests" lt on lt.lab_request_id = lr.id
    join "reporting"."lab_test_types" ltt on ltt.id = lt.lab_test_type_id
    where ltt.is_sensitive = True
    group by lr.id
)

select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(lr.requested_datetime, p.date_of_birth)) as age,
    p.sex,
    village.id as village_id,
    village.name as village,
    f.id as facility_id,
    f.name as facility,
    d.name as department,
    d.id as department_id,
    l.id as location_id,
    l.name as location,
    lg.id as location_group_id,
    lg.name as location_group,
    laboratory.id as laboratory_id,
    laboratory.name as laboratory,
    lr.display_id as request_id,
    case lr.status
        when 'reception_pending' then 'Reception pending'
        when 'results_pending' then 'Results pending'
        when 'to_be_verified' then 'To be verified'
        when 'verified' then 'Verified'
        when 'published' then 'Published'
        when 'cancelled' then 'Cancelled'
        when 'deleted' then 'Deleted'
        when 'sample-not-collected' then 'Sample not collected'
        when 'entered-in-error' then 'Entered in error'
        else lr.status
    end as status,
    lr.status as status_id,
    lr.requested_datetime,
    req_clinician.id as requested_by_id,
    req_clinician.display_name as requested_by,
    lr.department_id as requesting_department_id,
    req_department.name as requesting_department,
    lr.lab_test_priority_id as priority_id,
    priority.name as priority,
    category.id as lab_test_category_id,
    category.name as lab_test_category,
    ltp.name as lab_test_panel,
    lta.tests,
    lr.collected_datetime,
    lr.collected_by_id,
    collector.display_name as collected_by,
    lr.specimen_type_id,
    specimen.name as specimen_type,
    site.name as site,
    lta.completed_datetime,
    case lr.reason_for_cancellation
        when 'clinical' then 'Clinical reason'
        when 'duplicate' then 'Duplicate'
        when 'entered-in-error' then 'Entered in error'
        when 'patient-discharged' then 'Patient discharged'
        when 'patient-refused' then 'Patient refused'
        when 'other' then 'Other'
        else lr.reason_for_cancellation
    end as reason_for_cancellation
from "reporting"."lab_requests" lr
join lab_test_data lta on lta.lab_request_id = lr.id
join "reporting"."encounters" e on e.id = lr.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
left join "reporting"."reference_data" village on village.id = p.village_id
left join "reporting"."locations" l on l.id = e.location_id
left join "reporting"."location_groups" lg on lg.id = l.location_group_id
left join "reporting"."departments" d on d.id = e.department_id
left join "reporting"."facilities" f on f.id = l.facility_id
left join "reporting"."reference_data" laboratory on laboratory.id = lr.lab_test_laboratory_id
left join "reporting"."users" req_clinician on req_clinician.id = lr.requested_by_id
left join "reporting"."departments" req_department on req_department.id = lr.department_id
left join "reporting"."reference_data" priority on priority.id = lr.lab_test_priority_id
left join "reporting"."reference_data" category on category.id = lr.lab_test_category_id
left join "reporting"."users" collector on collector.id = lr.collected_by_id
left join "reporting"."reference_data" specimen on specimen.id = lr.specimen_type_id
left join "reporting"."reference_data" site on site.id = lr.lab_sample_site_id
left join "reporting"."lab_test_panel_requests" ltpr
    on ltpr.id = lr.lab_test_panel_request_id
left join "reporting"."lab_test_panels" ltp on ltp.id = ltpr.lab_test_panel_id


);
create or replace view "reporting"."ds__sensitive_lab_tests" as (


select
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(lr.requested_datetime, p.date_of_birth::date)) as age,
    p.sex,
    village.id as village_id,
    village.name as village,
    f.id as facility_id,
    f.name as facility,
    d.id as department_id,
    d.name as department,
    req_dept.id as requesting_department_id,
    req_dept.name as requesting_department,
    lg.id as location_group_id,
    lg.name as location_group,
    l.id as location_id,
    l.name as location,
    lr.display_id as lab_request_id,
    lr.status as status_id,
    case lr.status
        when 'reception_pending' then 'Reception pending'
        when 'results_pending' then 'Results pending'
        when 'to_be_verified' then 'To be verified'
        when 'verified' then 'Verified'
        when 'published' then 'Published'
        when 'cancelled' then 'Cancelled'
        when 'deleted' then 'Deleted'
        when 'sample-not-collected' then 'Sample not collected'
        when 'entered-in-error' then 'Entered in error'
        else lr.status
    end as status,
    ltp.id as lab_test_panel_id,
    ltp.name as lab_test_panel,
    category.id as lab_test_category_id,
    category.name as lab_test_category,
    lr.requested_datetime,
    requester.id as requested_by_id,
    requester.display_name as requested_by,
    lr.published_datetime as lab_request_published_datetime,
    lt.date as lab_test_date,
    lt.result,
    lt.verification,
    ltt.id as lab_test_type_id,
    ltt.name as lab_test_type,
    lt.completed_datetime as lab_test_completed_datetime
from "reporting"."lab_requests" lr
join "reporting"."encounters" e on e.id = lr.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
left join "reporting"."reference_data" village on village.id = p.village_id
left join "reporting"."locations" l on l.id = e.location_id
left join "reporting"."location_groups" lg on lg.id = l.location_group_id
left join "reporting"."departments" d on d.id = e.department_id
left join "reporting"."departments" req_dept on req_dept.id = lr.department_id
left join "reporting"."facilities" f on f.id = l.facility_id
left join "reporting"."users" requester on requester.id = lr.requested_by_id
left join "reporting"."lab_test_panel_requests" ltpr on ltpr.id = lr.lab_test_panel_request_id
left join "reporting"."lab_test_panels" ltp on ltp.id = ltpr.lab_test_panel_id
left join "reporting"."reference_data" category on category.id = lr.lab_test_category_id
join "reporting"."lab_tests" lt on lt.lab_request_id = lr.id
join "reporting"."lab_test_types" ltt on ltt.id = lt.lab_test_type_id
where ltt.is_sensitive = True


);
create or replace view "reporting"."ds__user_audit" as (
with non_system_notes as (
    select distinct on (n.record_id)
        n.record_id,
        first_value(n.datetime) over w as first_note_datetime,
        last_value(n.datetime) over w as last_note_datetime,
        last_value(concat_ws(' on behalf of ', author.display_name, on_behalf.display_name)) over w as last_clinician
    from "reporting"."notes" n
    left join "reporting"."users" author on author.id = n.authored_by_id
    left join "reporting"."users" on_behalf on on_behalf.id = n.on_behalf_of_id
    where n.note_type != 'system'
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
from "reporting"."encounters" e
left join "reporting"."users" u on u.id = e.clinician_id
left join "reporting"."roles" r on r.id = u.role
left join "reporting"."patients" p on p.id = e.patient_id
left join "reporting"."patient_additional_data" pad on pad.patient_id = e.patient_id
left join "reporting"."reference_data" bt
    on bt.id = coalesce(e.patient_billing_type_id, pad.patient_billing_type_id)
left join "reporting"."triages" t on t.encounter_id = e.id
join "reporting"."locations" l on l.id = e.location_id
left join "reporting"."location_groups" lg on lg.id = l.location_group_id
join "reporting"."facilities" f
    on f.id = l.facility_id
    and not f.is_sensitive
left join "reporting"."departments" d on d.id = e.department_id
left join "reporting"."discharges" ds on ds.encounter_id = e.id
left join non_system_notes n on n.record_id = e.id
);
create or replace view "reporting"."ds__usage_quality_metrics_patient_details" as (
with data as (
    select
        p.id as patient_id,
        pm.id as patient_merged_id,
        coalesce(nullif(trim(p.first_name),''), nullif(trim(pm.first_name),'')) as first_name,
        coalesce(nullif(trim(p.last_name),''), nullif(trim(pm.last_name),'')) as last_name,
        coalesce(p.date_of_birth, pm.date_of_birth) as date_of_birth,
        coalesce(nullif(trim(p.village_id),''), nullif(trim(pm.village_id),'')) as village_id,
        nullif(trim(pad.nursing_zone_id),'') as nursing_zone_id,
        nullif(trim(pad.medical_area_id),'') as medical_area_id,
        nullif(trim(pad.subdivision_id),'') as subdivision_id,
        nullif(trim(pad.division_id),'') as division_id,
        nullif(trim(pad.primary_contact_number),'') as primary_contact_number,
        nullif(trim(pad.secondary_contact_number),'') as secondary_contact_number
    from "reporting"."patients" p
    full join "reporting"."patients_merged" pm
    	on pm.id = p.id
    left join "reporting"."patient_additional_data" pad
        on pad.patient_id = coalesce(p.id, pm.id)
)
select
    count(*) as total_patients,
    count(*) filter (where first_name is null or last_name is null) as total_patients_with_incomplete_name,
    count(*) filter (where date_of_birth is null) as total_patients_with_missing_dob,
    count(*) filter (where date_of_birth <= '1900-01-01' or date_of_birth > now()::date) as total_patients_with_invalid_dob,
    count(*) filter (where coalesce(village_id, nursing_zone_id, medical_area_id, subdivision_id, division_id) is null) as total_patients_with_missing_location,
    count(*) filter (where coalesce(primary_contact_number, secondary_contact_number) is null) as total_patients_with_missing_contact,
    count(patient_merged_id) as total_patients_merged
from data
);
create or replace view "reporting"."ds__usage_quality_metrics_patient_registrations" as (
with data as (
    select
        p.created_datetime as registration_date,
        p.id as registration_patient_id,
        pbd.patient_id as birth_patient_id,
        p.date_of_birth,
        age(p.created_datetime, p.date_of_birth) < interval '6 months' as age_under_6m_at_registration
    from "reporting"."patients" p
    left join "reporting"."patient_birth_data" pbd
        on pbd.patient_id = p.id
)
select
    registration_date,
    count(*) filter (where birth_patient_id is null) as total_patient_registrations,
    count(birth_patient_id) as total_birth_registrations,
    count(*) filter (where birth_patient_id is null and age_under_6m_at_registration) as total_incorrect_registrations_for_patient_under_6mth
from data
group by registration_date
);
create or replace view "reporting"."int__admission_history_department" as (
with admission_department_log as (
    select
        eh.id,
        eh.encounter_id,
        eh.datetime as start_datetime,
        eh.department_id,
        case
            when eh.change_type is null or eh.change_type = 'encounter_type' then 'admission'
            else 'transfer-in'
        end as type
    from "reporting"."encounter_history" eh
    where (eh.change_type isnull or eh.change_type in ('department', 'encounter_type'))
        and eh.encounter_type = 'admission'
)

select
    dl.encounter_id,
    dl.department_id,
    d.name as department,
    d.facility_id,
    f.name as facility,
    dl.start_datetime,
    coalesce(lead(dl.start_datetime) over w, e.end_datetime) as end_datetime,
    case
        when coalesce(lead(dl.start_datetime::date) over w, e.end_datetime::date) - dl.start_datetime::date < 1 then 1
        else coalesce(lead(dl.start_datetime::date) over w, e.end_datetime::date) - dl.start_datetime::date
    end as length_of_stay,
    coalesce(dl.type = 'admission', false) as admission,
    coalesce(lead(dl.department_id) over w isnull and e.end_datetime notnull, false) as discharge,
    coalesce(dl.type = 'transfer-in', false) as transfer_in,
    coalesce(lead(dl.department_id) over w notnull, false) as transfer_out,
    coalesce(lead(dl.start_datetime) over w isnull and e.end_datetime::date = p.date_of_death, false) as death
from admission_department_log dl
join "reporting"."encounters" e on e.id = dl.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
join "reporting"."departments" d on d.id = dl.department_id
join "reporting"."facilities" f on f.id = d.facility_id
window w as (
    partition by encounter_id
    order by dl.start_datetime
)
);
create or replace view "reporting"."int__admission_history_location" as (
with admission_location_log as (
    select
        eh.id,
        eh.encounter_id,
        eh.datetime as start_datetime,
        eh.location_id,
        case
            when eh.change_type is null or eh.change_type = 'encounter_type' then 'admission'
            else 'transfer-in'
        end as type
    from "reporting"."encounter_history" eh
    where (eh.change_type isnull or eh.change_type in ('location', 'encounter_type'))
        and eh.encounter_type = 'admission'
)

select
    ll.encounter_id,
    l.location_group_id,
    lg.name as location_group,
    ll.location_id,
    l.name as location,
    l.facility_id,
    f.name as facility,
    ll.start_datetime,
    coalesce(lead(ll.start_datetime) over w, e.end_datetime) as end_datetime,
    case
        when coalesce(lead(ll.start_datetime::date) over w, e.end_datetime::date) - ll.start_datetime::date < 1 then 1
        else coalesce(lead(ll.start_datetime::date) over w, e.end_datetime::date) - ll.start_datetime::date
    end as length_of_stay,
    coalesce(ll.type = 'admission', false) as admission,
    coalesce(lead(ll.location_id) over w isnull and e.end_datetime notnull, false) as discharge,
    coalesce(ll.type = 'transfer-in', false) as transfer_in,
    coalesce(lead(ll.location_id) over w notnull, false) as transfer_out,
    coalesce(lead(ll.start_datetime) over w isnull and e.end_datetime::date = p.date_of_death, false) as death
from admission_location_log ll
join "reporting"."encounters" e on e.id = ll.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
join "reporting"."locations" l on l.id = ll.location_id
join "reporting"."location_groups" lg on lg.id = l.location_group_id
join "reporting"."facilities" f on f.id = l.facility_id
window w as (
    partition by ll.encounter_id
    order by ll.start_datetime
)
);
create or replace view "reporting"."int__encounter_notes_final" as (
-- May include notes for the test patient.
with notes_ordering as (
    select
        id,
        datetime,
        content,
        note_type,
        record_type,
        record_id,
        authored_by_id,
        on_behalf_of_id,
        updated_note_id,
        visibility_status,
        row_number() over (partition by coalesce(updated_note_id, id) order by datetime desc) as row_number
    from "reporting"."notes"
    where record_type = 'Encounter'
        and note_type != 'system'
)
select 
    id,
    datetime,
    content,
    note_type,
    record_type,
    record_id,
    authored_by_id,
    on_behalf_of_id,
    visibility_status
from notes_ordering
where row_number = 1
);
create or replace view "reporting"."int__lab_requests_history" as (
select distinct on (lr.id, coalesce(lrl.status, lr.status))
    lr.id as request_id,
    lr.requested_datetime::date as requested_date,
    lr.encounter_id,
    f.id as facility_id,
    f.name as facility,
    d.id as department_id,
    d.name as department,
    ltc.id as lab_test_category_id,
    ltc.name as lab_test_category,
    coalesce(lrl.status, lr.status) as status,
    coalesce(lrl.updated_datetime, lr.updated_datetime)::date as status_start_date,
    case
        when coalesce(lrl.status, lr.status) = 'published'
            then
                coalesce(lrl.updated_datetime, lr.updated_datetime)::date
        when lead(coalesce(lrl.updated_datetime, lr.updated_datetime)) over w is not null
            then
                case
                    when coalesce(lrl.updated_datetime, lr.updated_datetime)::date
                        = (lead(coalesce(lrl.updated_datetime, lr.updated_datetime)) over w)::date
                        then (lead(coalesce(lrl.updated_datetime, lr.updated_datetime)) over w)::date
                    else (lead(coalesce(lrl.updated_datetime, lr.updated_datetime)) over w - interval '1 day')::date
                end
        else current_date
    end as status_end_date
from "reporting"."lab_requests" lr
left join "reporting"."lab_request_logs" lrl on lrl.lab_request_id = lr.id
left join "reporting"."encounters" e on e.id = lr.encounter_id
left join "reporting"."departments" d on d.id = coalesce(lr.department_id, e.department_id)
left join "reporting"."facilities" f on f.id = d.facility_id
left join "reporting"."reference_data" ltc on ltc.id = lr.lab_test_category_id
where lr.status not in ('deleted', 'cancelled', 'entered-in-error')
window
    w as (
        partition by lr.id
        order by coalesce(lrl.updated_datetime, lr.updated_datetime)
    )
order by lr.id, coalesce(lrl.status, lr.status)
);
create or replace view "reporting"."ds__encounter_summary" as (


with  __dbt__cte__int__encounter_notes_final as (
-- May include notes for the test patient.
with notes_ordering as (
    select
        id,
        datetime,
        content,
        note_type,
        record_type,
        record_id,
        authored_by_id,
        on_behalf_of_id,
        updated_note_id,
        visibility_status,
        row_number() over (partition by coalesce(updated_note_id, id) order by datetime desc) as row_number
    from "reporting"."notes"
    where record_type = 'Encounter'
        and note_type != 'system'
)
select 
    id,
    datetime,
    content,
    note_type,
    record_type,
    record_id,
    authored_by_id,
    on_behalf_of_id,
    visibility_status
from notes_ordering
where row_number = 1
), encounter_history_consolidated as (
    select
        eh.encounter_id,
        eh.datetime,
        eh.change_type,
        eh.updated_by_id,
        eh.clinician_id,
        eh.department_id,
        eh.location_id,
        eh.encounter_type,
        clinician.display_name as clinician_name,
        actor.display_name as updated_by_name,
        d.name as department_name,
        l.name as location_name,
        lg.id as location_group_id,
        lg.name as location_group_name,
        row_number() over (
            partition by eh.encounter_id, eh.change_type
            order by eh.datetime
        ) as change_sequence,
        lag(lg.id) over (
            partition by eh.encounter_id
            order by eh.datetime
        ) as prev_location_group_id
    from "reporting"."encounter_history" eh
    join "reporting"."users" actor
        on actor.id = eh.updated_by_id
    join "reporting"."users" clinician
        on clinician.id = eh.clinician_id
    join "reporting"."departments" d
        on d.id = eh.department_id
    join "reporting"."locations" l
        on l.id = eh.location_id
    join "reporting"."facilities" f
        on f.id = l.facility_id
        and f.is_sensitive = False
    left join "reporting"."location_groups" lg
        on lg.id = l.location_group_id
),

encounter_changes as (
    select
        encounter_id,
        
        -- Location changes: tracks all location changes throughout the encounter
        array_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI:SS')
            order by datetime
        ) filter (where change_type isnull or change_type = 'location') as location_datetimes,
        array_agg(
            location_id
            order by datetime
        ) filter (where change_type isnull or change_type = 'location') as location_ids,
        string_agg(
            location_name, ', '
            order by datetime
        ) filter (where change_type isnull or change_type = 'location') as locations,
        
        -- Location group changes: tracks location group changes (only when group actually changes)
        array_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI:SS')
            order by datetime
        ) filter (where change_type isnull or (change_type = 'location' and location_group_id is distinct from prev_location_group_id)) as location_group_datetimes,
        array_agg(
            location_group_id
            order by datetime
        ) filter (where change_type isnull or (change_type = 'location' and location_group_id is distinct from prev_location_group_id)) as location_group_ids,
        string_agg(
            location_group_name, ', '
            order by datetime
        ) filter (where change_type isnull or (change_type = 'location' and location_group_id is distinct from prev_location_group_id)) as location_groups,
        
        -- Department changes: tracks all department changes throughout the encounter
        array_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI:SS')
            order by datetime
        ) filter (where change_type isnull or change_type = 'department') as department_datetimes,
        array_agg(
            department_id
            order by datetime
        ) filter (where change_type isnull or change_type = 'department') as department_ids,
        string_agg(
            department_name, ', '
            order by datetime
        ) filter (where change_type isnull or change_type = 'department') as departments,
        
        -- Encounter type changes: tracks encounter type progression (emergency types)
        string_agg(
            case
                when encounter_type = 'triage' then 'Triage'
                when encounter_type = 'observation' then 'Active ED care'
                when encounter_type = 'emergency' then 'Emergency short stay'
            end, ', '
            order by datetime
        ) filter (where change_type isnull or change_type = 'encounter_type') as encounter_type_emergency,
        
        -- Encounter type changes: tracks encounter type progression (inpatient types)
        string_agg(
            case
                when encounter_type = 'admission' then 'Hospital admission'
            end, ', '
            order by datetime
        ) filter (where change_type isnull or change_type = 'encounter_type') as encounter_type_inpatient,
        
        -- Encounter type changes: tracks encounter type progression (outpatient types)
        string_agg(
            case
                when encounter_type = 'clinic' then 'Clinic'
                when encounter_type = 'imaging' then 'Imaging'
                when encounter_type = 'surveyResponse' then 'Survey response'
                when encounter_type = 'vaccination' then 'Vaccination'
            end, ', '
            order by datetime
        ) filter (where change_type isnull or change_type = 'encounter_type') as encounter_type_outpatient
    from encounter_history_consolidated
    group by encounter_id
),

encounter_diagnoses as (
    select
        ed.encounter_id,
        string_agg(
            concat(
                'Name: ', d.name,
                ', Code: ', d.code,
                ', Is primary: ', case when ed.is_primary then 'primary' else 'secondary' end,
                ', Certainty: ', ed.certainty
            ),
            E'\n'
            order by ed.is_primary desc, ed.datetime asc
        ) as diagnoses
    from "reporting"."encounters" e
    join "reporting"."encounter_diagnoses" ed
        on ed.encounter_id = e.id
    join "reporting"."reference_data" d
        on d.id = ed.diagnosis_id
    where ed.certainty not in ('disproven', 'error')
    group by ed.encounter_id
),

encounter_prescriptions as (
    select
        ep.encounter_id,
        string_agg(
            concat(
                'Name: ', m.name,
                ', Discontinued: ', case when p.is_discontinued then 'true' else 'false' end,
                ', Discontinuing reason: ', p.discontinuing_reason
            ),
            '' || E'\n' || ''
            order by p.datetime
        ) as medications
    from "reporting"."encounter_prescriptions" ep
    join "reporting"."prescriptions" p
        on p.id = ep.prescription_id
    join "reporting"."reference_data" m on m.id = p.medication_id
    group by ep.encounter_id
),

encounter_vaccinations as (
    select
        av.encounter_id,
        string_agg(
            concat(
                v.name,
                ', Label: ', sv.label,
                ', Schedule: ', sv.dose_label
            ),
            E'\n'
            order by av.datetime
        ) as vaccinations
    from "reporting"."vaccine_administrations" av
    join "reporting"."vaccine_schedules" sv
        on sv.id = av.scheduled_vaccine_id
    join "reporting"."reference_data" v
        on v.id = sv.vaccine_id
    group by av.encounter_id
),

encounter_procedures as (
    select
        p.encounter_id,
        string_agg(
            concat(
                'Name: ', proc.name,
                ', Date: ', to_char(p.date, 'YYYY-MM-DD'),
                ', Location: ', loc.name,
                ', Notes: ', p.note,
                ', Completed notes: ', p.completed_note
            ),
            E'\n'
            order by p.date
        ) as procedures
    from "reporting"."procedures" p
    left join "reporting"."reference_data" proc
        on proc.id = p.procedure_type_id
    left join "reporting"."locations" loc
        on loc.id = p.location_id
    group by p.encounter_id
),

encounter_lab_requests as (
    select
        lr.encounter_id,
        string_agg(
            coalesce(ltp.name, ltt.name), '' || E'\n' || ''
            order by lr.collected_datetime
        ) as lab_requests
    from "reporting"."lab_requests" lr
    left join "reporting"."lab_test_panel_requests" ltpr
        on ltpr.id = lr.lab_test_panel_request_id
    left join "reporting"."lab_test_panels" ltp
        on ltp.id = ltpr.lab_test_panel_id
    left join "reporting"."lab_tests" lt
        on lt.lab_request_id = lr.id
        and lr.lab_test_panel_request_id isnull
    left join "reporting"."lab_test_types" ltt
        on ltt.id = lt.lab_test_type_id
    where lr.status not in ('cancelled', 'deleted', 'entered-in-error')
    group by lr.encounter_id
),

imaging_request_areas as (
    select
        ir.encounter_id,
        ira.imaging_request_id,
        case
            when ir.imaging_type = 'xRay' then 'X-Ray'
            when ir.imaging_type = 'ctScan' then 'CT Scan'
            when ir.imaging_type = 'ecg' then 'Electrocardiogram (ECG)'
            when ir.imaging_type = 'mri' then 'MRI'
            when ir.imaging_type = 'ultrasound' then 'Ultrasound'
            when ir.imaging_type = 'holterMonitor' then 'Holter Monitor'
            when ir.imaging_type = 'echocardiogram' then 'Echocardiogram'
            when ir.imaging_type = 'mammogram' then 'Mammogram'
            when ir.imaging_type = 'endoscopy' then 'Endoscopy'
            when ir.imaging_type = 'fluroscopy' then 'Fluroscopy'
            when ir.imaging_type = 'angiogram' then 'Angiogram'
            when ir.imaging_type = 'colonoscopy' then 'Colonoscopy'
            when ir.imaging_type = 'vascularStudy' then 'Vascular Study'
            when ir.imaging_type = 'stressTest' then 'Stress Test'
            else ir.imaging_type
        end as imaging_type,
        coalesce(
            string_agg(
                area.name, ', '
                order by area.name
            ),
            string_agg(case
                when n.note_type = 'areaToBeImaged' then n.content
            end, ', '
            order by n.datetime)
        ) as areas_to_be_imaged,
        string_agg(case
            when n.note_type = 'other' then n.content
        end, ','
        order by n.datetime) as notes
    from "reporting"."imaging_requests" ir
    left join "reporting"."imaging_request_areas" ira
        on ira.imaging_request_id = ir.id
    left join "reporting"."reference_data" area
        on area.id = ira.area_id
    left join "reporting"."notes" n
        on n.record_id = ir.id
        and n.record_type = 'ImagingRequest'
    where ir.status not in ('cancelled', 'deleted', 'entered_in_error')
    group by ir.encounter_id, ira.imaging_request_id, ir.imaging_type
),

encounter_imaging_requests as (
    select
        encounter_id,
        string_agg(
            concat(imaging_type, ', Areas to be imaged: ', areas_to_be_imaged, ', Notes: ', notes), '' || E'\n' || ''
        ) as imaging_requests
    from imaging_request_areas
    group by encounter_id
),

encounter_notes as (
    select
        n.record_id as encounter_id,
        string_agg(concat(
            'Note type: ',
            coalesce(ts.text, n.note_type),
            ', Content: ', n.content,
            ', Note date: ', to_char(n.datetime, 'YYYY-MM-DD HH24:MI:SS')
        ),
        E'\n'
        order by n.datetime) as notes
    from __dbt__cte__int__encounter_notes_final n
    left join (
        select 
            string_id,
            coalesce(
                max(case when language = 'default' then text end),
                max(case when language = 'default' then text end),
                string_id
            ) as text
        from "public"."translated_strings"
        where language in ('default', 'default')
        group by string_id
    ) ts
        on ts.string_id = 'note.property.type.' || n.note_type
    group by n.record_id
)

select
    e.id as encounter_id,
    e.start_datetime,
    e.end_datetime,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(e.start_datetime, p.date_of_birth)) as age,
    p.sex,
    eth.name as ethnicity,
    e.patient_billing_type_id,
    bt.name as patient_billing_type,
    case when e.end_datetime is not null then
            case
                when e.end_datetime::date - e.start_datetime::date < 1 then 1
                else e.end_datetime::date - e.start_datetime::date
            end
    end as length_of_stay,
    f.id as facility_id,
    f.name as facility,
    ec.encounter_type_emergency,
    ec.encounter_type_inpatient,
    ec.encounter_type_outpatient,
    dd.id as discharge_disposition_id,
    dd.name as discharge_disposition,
    t.score as triage_score,
    am.id as arrival_mode_id,
    am.name as arrival_mode,
    case when t.closed_datetime notnull and t.triage_datetime notnull and t.closed_datetime > t.triage_datetime
            then concat(
                    lpad((
                        extract(day from (t.closed_datetime - t.triage_datetime)) * 24
                        + extract(hour from (t.closed_datetime - t.triage_datetime))
                    )::text, 2, '0'), ':',
                    lpad(extract(minute from (t.closed_datetime - t.triage_datetime))::text, 2, '0'), ':',
                    lpad(
                        (extract(second from (t.closed_datetime - t.triage_datetime))::int)::text, 2, '0'
                    )
                )
    end as triage_wait_time,
    ehc.updated_by_id as encountering_clinician_id,
    ehc.updated_by_name as encountering_clinician,
    c.id as supervising_clinician_id,
    c.display_name as supervising_clinician,
    dp.id as discharging_department_id,
    dp.name as discharging_department,
    lg.id as discharging_location_group_id,
    lg.name as discharging_location_group,
    l.id as discharging_location_id,
    l.name as discharging_location,
    ec.department_datetimes[array_upper(ec.department_datetimes, 1)] as time_assigned_to_discharging_department,
    ec.location_group_datetimes[array_upper(ec.location_group_datetimes, 1)] as time_assigned_to_discharging_location_group,
    ec.location_datetimes[array_upper(ec.location_datetimes, 1)] as time_assigned_to_discharging_location,
    ec.department_ids,
    ec.departments,
    array_to_string(ec.department_datetimes, ', ') as department_datetimes,
    ec.location_group_ids,
    ec.location_groups,
    array_to_string(ec.location_group_datetimes, ', ') as location_group_datetimes,
    ec.location_ids,
    ec.locations,
    array_to_string(ec.location_datetimes, ', ') as location_datetimes,
    e.reason_for_encounter,
    ed.diagnoses,
    ep.medications,
    ev.vaccinations,
    epr.procedures,
    elr.lab_requests,
    eir.imaging_requests,
    case
        when length(en.notes) > 32000
            then concat(
                    'THIS CELL HAS BEEN CROPPED AS IT EXCEEDED THE MAXIMUM LENGTH IN EXCEL - PLEASE SEE TAMANU FOR ',
                    'FULL NOTES HISTORY', '' || E'\n' || '', left(en.notes, 32000)
                )
        else en.notes
    end as notes
from "reporting"."encounters" e
join "reporting"."patients" p on p.id = e.patient_id
join "reporting"."locations" l on l.id = e.location_id
join "reporting"."facilities" f
    on f.id = l.facility_id
    and f.is_sensitive = False
left join "reporting"."users" c on c.id = e.clinician_id
join "reporting"."departments" dp on dp.id = e.department_id
left join "reporting"."location_groups" lg on lg.id = l.location_group_id
join encounter_changes ec on ec.encounter_id = e.id
join encounter_history_consolidated ehc on ehc.encounter_id = e.id and ehc.change_type is null
left join "reporting"."triages" t on t.encounter_id = e.id
left join "reporting"."discharges" d on d.encounter_id = e.id
left join "reporting"."patient_additional_data" pd on pd.patient_id = e.patient_id
left join "reporting"."reference_data" eth on eth.id = pd.ethnicity_id
left join "reporting"."reference_data" bt on bt.id = e.patient_billing_type_id
left join "reporting"."reference_data" am on am.id = t.arrival_mode_id
left join "reporting"."reference_data" dd on dd.id = d.disposition_id
left join encounter_diagnoses ed on ed.encounter_id = e.id
left join encounter_prescriptions ep on ep.encounter_id = e.id
left join encounter_vaccinations ev on ev.encounter_id = e.id
left join encounter_procedures epr on epr.encounter_id = e.id
left join encounter_lab_requests elr on elr.encounter_id = e.id
left join encounter_imaging_requests eir on eir.encounter_id = e.id
left join encounter_notes en on en.encounter_id = e.id
where e.end_datetime is not null


);
create or replace view "reporting"."ds__sensitive_encounter_summary" as (


with  __dbt__cte__int__encounter_notes_final as (
-- May include notes for the test patient.
with notes_ordering as (
    select
        id,
        datetime,
        content,
        note_type,
        record_type,
        record_id,
        authored_by_id,
        on_behalf_of_id,
        updated_note_id,
        visibility_status,
        row_number() over (partition by coalesce(updated_note_id, id) order by datetime desc) as row_number
    from "reporting"."notes"
    where record_type = 'Encounter'
        and note_type != 'system'
)
select 
    id,
    datetime,
    content,
    note_type,
    record_type,
    record_id,
    authored_by_id,
    on_behalf_of_id,
    visibility_status
from notes_ordering
where row_number = 1
), encounter_history_consolidated as (
    select
        eh.encounter_id,
        eh.datetime,
        eh.change_type,
        eh.updated_by_id,
        eh.clinician_id,
        eh.department_id,
        eh.location_id,
        eh.encounter_type,
        clinician.display_name as clinician_name,
        actor.display_name as updated_by_name,
        d.name as department_name,
        l.name as location_name,
        lg.id as location_group_id,
        lg.name as location_group_name,
        row_number() over (
            partition by eh.encounter_id, eh.change_type
            order by eh.datetime
        ) as change_sequence,
        lag(lg.id) over (
            partition by eh.encounter_id
            order by eh.datetime
        ) as prev_location_group_id
    from "reporting"."encounter_history" eh
    join "reporting"."users" actor
        on actor.id = eh.updated_by_id
    join "reporting"."users" clinician
        on clinician.id = eh.clinician_id
    join "reporting"."departments" d
        on d.id = eh.department_id
    join "reporting"."locations" l
        on l.id = eh.location_id
    join "reporting"."facilities" f
        on f.id = l.facility_id
        and f.is_sensitive = True
    left join "reporting"."location_groups" lg
        on lg.id = l.location_group_id
),

encounter_changes as (
    select
        encounter_id,
        
        -- Location changes: tracks all location changes throughout the encounter
        array_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI:SS')
            order by datetime
        ) filter (where change_type isnull or change_type = 'location') as location_datetimes,
        array_agg(
            location_id
            order by datetime
        ) filter (where change_type isnull or change_type = 'location') as location_ids,
        string_agg(
            location_name, ', '
            order by datetime
        ) filter (where change_type isnull or change_type = 'location') as locations,
        
        -- Location group changes: tracks location group changes (only when group actually changes)
        array_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI:SS')
            order by datetime
        ) filter (where change_type isnull or (change_type = 'location' and location_group_id is distinct from prev_location_group_id)) as location_group_datetimes,
        array_agg(
            location_group_id
            order by datetime
        ) filter (where change_type isnull or (change_type = 'location' and location_group_id is distinct from prev_location_group_id)) as location_group_ids,
        string_agg(
            location_group_name, ', '
            order by datetime
        ) filter (where change_type isnull or (change_type = 'location' and location_group_id is distinct from prev_location_group_id)) as location_groups,
        
        -- Department changes: tracks all department changes throughout the encounter
        array_agg(
            to_char(datetime, 'YYYY-MM-DD HH24:MI:SS')
            order by datetime
        ) filter (where change_type isnull or change_type = 'department') as department_datetimes,
        array_agg(
            department_id
            order by datetime
        ) filter (where change_type isnull or change_type = 'department') as department_ids,
        string_agg(
            department_name, ', '
            order by datetime
        ) filter (where change_type isnull or change_type = 'department') as departments,
        
        -- Encounter type changes: tracks encounter type progression (emergency types)
        string_agg(
            case
                when encounter_type = 'triage' then 'Triage'
                when encounter_type = 'observation' then 'Active ED care'
                when encounter_type = 'emergency' then 'Emergency short stay'
            end, ', '
            order by datetime
        ) filter (where change_type isnull or change_type = 'encounter_type') as encounter_type_emergency,
        
        -- Encounter type changes: tracks encounter type progression (inpatient types)
        string_agg(
            case
                when encounter_type = 'admission' then 'Hospital admission'
            end, ', '
            order by datetime
        ) filter (where change_type isnull or change_type = 'encounter_type') as encounter_type_inpatient,
        
        -- Encounter type changes: tracks encounter type progression (outpatient types)
        string_agg(
            case
                when encounter_type = 'clinic' then 'Clinic'
                when encounter_type = 'imaging' then 'Imaging'
                when encounter_type = 'surveyResponse' then 'Survey response'
                when encounter_type = 'vaccination' then 'Vaccination'
            end, ', '
            order by datetime
        ) filter (where change_type isnull or change_type = 'encounter_type') as encounter_type_outpatient
    from encounter_history_consolidated
    group by encounter_id
),

encounter_diagnoses as (
    select
        ed.encounter_id,
        string_agg(
            concat(
                'Name: ', d.name,
                ', Code: ', d.code,
                ', Is primary: ', case when ed.is_primary then 'primary' else 'secondary' end,
                ', Certainty: ', ed.certainty
            ),
            E'\n'
            order by ed.is_primary desc, ed.datetime asc
        ) as diagnoses
    from "reporting"."encounters" e
    join "reporting"."encounter_diagnoses" ed
        on ed.encounter_id = e.id
    join "reporting"."reference_data" d
        on d.id = ed.diagnosis_id
    where ed.certainty not in ('disproven', 'error')
    group by ed.encounter_id
),

encounter_prescriptions as (
    select
        ep.encounter_id,
        string_agg(
            concat(
                'Name: ', m.name,
                ', Discontinued: ', case when p.is_discontinued then 'true' else 'false' end,
                ', Discontinuing reason: ', p.discontinuing_reason
            ),
            '' || E'\n' || ''
            order by p.datetime
        ) as medications
    from "reporting"."encounter_prescriptions" ep
    join "reporting"."prescriptions" p
        on p.id = ep.prescription_id
    join "reporting"."reference_data" m on m.id = p.medication_id
    group by ep.encounter_id
),

encounter_vaccinations as (
    select
        av.encounter_id,
        string_agg(
            concat(
                v.name,
                ', Label: ', sv.label,
                ', Schedule: ', sv.dose_label
            ),
            E'\n'
            order by av.datetime
        ) as vaccinations
    from "reporting"."vaccine_administrations" av
    join "reporting"."vaccine_schedules" sv
        on sv.id = av.scheduled_vaccine_id
    join "reporting"."reference_data" v
        on v.id = sv.vaccine_id
    group by av.encounter_id
),

encounter_procedures as (
    select
        p.encounter_id,
        string_agg(
            concat(
                'Name: ', proc.name,
                ', Date: ', to_char(p.date, 'YYYY-MM-DD'),
                ', Location: ', loc.name,
                ', Notes: ', p.note,
                ', Completed notes: ', p.completed_note
            ),
            E'\n'
            order by p.date
        ) as procedures
    from "reporting"."procedures" p
    left join "reporting"."reference_data" proc
        on proc.id = p.procedure_type_id
    left join "reporting"."locations" loc
        on loc.id = p.location_id
    group by p.encounter_id
),

encounter_lab_requests as (
    select
        lr.encounter_id,
        string_agg(
            coalesce(ltp.name, ltt.name), '' || E'\n' || ''
            order by lr.collected_datetime
        ) as lab_requests
    from "reporting"."lab_requests" lr
    left join "reporting"."lab_test_panel_requests" ltpr
        on ltpr.id = lr.lab_test_panel_request_id
    left join "reporting"."lab_test_panels" ltp
        on ltp.id = ltpr.lab_test_panel_id
    left join "reporting"."lab_tests" lt
        on lt.lab_request_id = lr.id
        and lr.lab_test_panel_request_id isnull
    left join "reporting"."lab_test_types" ltt
        on ltt.id = lt.lab_test_type_id
    where lr.status not in ('cancelled', 'deleted', 'entered-in-error')
    group by lr.encounter_id
),

imaging_request_areas as (
    select
        ir.encounter_id,
        ira.imaging_request_id,
        case
            when ir.imaging_type = 'xRay' then 'X-Ray'
            when ir.imaging_type = 'ctScan' then 'CT Scan'
            when ir.imaging_type = 'ecg' then 'Electrocardiogram (ECG)'
            when ir.imaging_type = 'mri' then 'MRI'
            when ir.imaging_type = 'ultrasound' then 'Ultrasound'
            when ir.imaging_type = 'holterMonitor' then 'Holter Monitor'
            when ir.imaging_type = 'echocardiogram' then 'Echocardiogram'
            when ir.imaging_type = 'mammogram' then 'Mammogram'
            when ir.imaging_type = 'endoscopy' then 'Endoscopy'
            when ir.imaging_type = 'fluroscopy' then 'Fluroscopy'
            when ir.imaging_type = 'angiogram' then 'Angiogram'
            when ir.imaging_type = 'colonoscopy' then 'Colonoscopy'
            when ir.imaging_type = 'vascularStudy' then 'Vascular Study'
            when ir.imaging_type = 'stressTest' then 'Stress Test'
            else ir.imaging_type
        end as imaging_type,
        coalesce(
            string_agg(
                area.name, ', '
                order by area.name
            ),
            string_agg(case
                when n.note_type = 'areaToBeImaged' then n.content
            end, ', '
            order by n.datetime)
        ) as areas_to_be_imaged,
        string_agg(case
            when n.note_type = 'other' then n.content
        end, ','
        order by n.datetime) as notes
    from "reporting"."imaging_requests" ir
    left join "reporting"."imaging_request_areas" ira
        on ira.imaging_request_id = ir.id
    left join "reporting"."reference_data" area
        on area.id = ira.area_id
    left join "reporting"."notes" n
        on n.record_id = ir.id
        and n.record_type = 'ImagingRequest'
    where ir.status not in ('cancelled', 'deleted', 'entered_in_error')
    group by ir.encounter_id, ira.imaging_request_id, ir.imaging_type
),

encounter_imaging_requests as (
    select
        encounter_id,
        string_agg(
            concat(imaging_type, ', Areas to be imaged: ', areas_to_be_imaged, ', Notes: ', notes), '' || E'\n' || ''
        ) as imaging_requests
    from imaging_request_areas
    group by encounter_id
),

encounter_notes as (
    select
        n.record_id as encounter_id,
        string_agg(concat(
            'Note type: ',
            coalesce(ts.text, n.note_type),
            ', Content: ', n.content,
            ', Note date: ', to_char(n.datetime, 'YYYY-MM-DD HH24:MI:SS')
        ),
        E'\n'
        order by n.datetime) as notes
    from __dbt__cte__int__encounter_notes_final n
    left join (
        select 
            string_id,
            coalesce(
                max(case when language = 'default' then text end),
                max(case when language = 'default' then text end),
                string_id
            ) as text
        from "public"."translated_strings"
        where language in ('default', 'default')
        group by string_id
    ) ts
        on ts.string_id = 'note.property.type.' || n.note_type
    group by n.record_id
)

select
    e.id as encounter_id,
    e.start_datetime,
    e.end_datetime,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    date_part('year', age(e.start_datetime, p.date_of_birth)) as age,
    p.sex,
    eth.name as ethnicity,
    e.patient_billing_type_id,
    bt.name as patient_billing_type,
    case when e.end_datetime is not null then
            case
                when e.end_datetime::date - e.start_datetime::date < 1 then 1
                else e.end_datetime::date - e.start_datetime::date
            end
    end as length_of_stay,
    f.id as facility_id,
    f.name as facility,
    ec.encounter_type_emergency,
    ec.encounter_type_inpatient,
    ec.encounter_type_outpatient,
    dd.id as discharge_disposition_id,
    dd.name as discharge_disposition,
    t.score as triage_score,
    am.id as arrival_mode_id,
    am.name as arrival_mode,
    case when t.closed_datetime notnull and t.triage_datetime notnull and t.closed_datetime > t.triage_datetime
            then concat(
                    lpad((
                        extract(day from (t.closed_datetime - t.triage_datetime)) * 24
                        + extract(hour from (t.closed_datetime - t.triage_datetime))
                    )::text, 2, '0'), ':',
                    lpad(extract(minute from (t.closed_datetime - t.triage_datetime))::text, 2, '0'), ':',
                    lpad(
                        (extract(second from (t.closed_datetime - t.triage_datetime))::int)::text, 2, '0'
                    )
                )
    end as triage_wait_time,
    ehc.updated_by_id as encountering_clinician_id,
    ehc.updated_by_name as encountering_clinician,
    c.id as supervising_clinician_id,
    c.display_name as supervising_clinician,
    dp.id as discharging_department_id,
    dp.name as discharging_department,
    lg.id as discharging_location_group_id,
    lg.name as discharging_location_group,
    l.id as discharging_location_id,
    l.name as discharging_location,
    ec.department_datetimes[array_upper(ec.department_datetimes, 1)] as time_assigned_to_discharging_department,
    ec.location_group_datetimes[array_upper(ec.location_group_datetimes, 1)] as time_assigned_to_discharging_location_group,
    ec.location_datetimes[array_upper(ec.location_datetimes, 1)] as time_assigned_to_discharging_location,
    ec.department_ids,
    ec.departments,
    array_to_string(ec.department_datetimes, ', ') as department_datetimes,
    ec.location_group_ids,
    ec.location_groups,
    array_to_string(ec.location_group_datetimes, ', ') as location_group_datetimes,
    ec.location_ids,
    ec.locations,
    array_to_string(ec.location_datetimes, ', ') as location_datetimes,
    e.reason_for_encounter,
    ed.diagnoses,
    ep.medications,
    ev.vaccinations,
    epr.procedures,
    elr.lab_requests,
    eir.imaging_requests,
    case
        when length(en.notes) > 32000
            then concat(
                    'THIS CELL HAS BEEN CROPPED AS IT EXCEEDED THE MAXIMUM LENGTH IN EXCEL - PLEASE SEE TAMANU FOR ',
                    'FULL NOTES HISTORY', '' || E'\n' || '', left(en.notes, 32000)
                )
        else en.notes
    end as notes
from "reporting"."encounters" e
join "reporting"."patients" p on p.id = e.patient_id
join "reporting"."locations" l on l.id = e.location_id
join "reporting"."facilities" f
    on f.id = l.facility_id
    and f.is_sensitive = True
left join "reporting"."users" c on c.id = e.clinician_id
join "reporting"."departments" dp on dp.id = e.department_id
left join "reporting"."location_groups" lg on lg.id = l.location_group_id
join encounter_changes ec on ec.encounter_id = e.id
join encounter_history_consolidated ehc on ehc.encounter_id = e.id and ehc.change_type is null
left join "reporting"."triages" t on t.encounter_id = e.id
left join "reporting"."discharges" d on d.encounter_id = e.id
left join "reporting"."patient_additional_data" pd on pd.patient_id = e.patient_id
left join "reporting"."reference_data" eth on eth.id = pd.ethnicity_id
left join "reporting"."reference_data" bt on bt.id = e.patient_billing_type_id
left join "reporting"."reference_data" am on am.id = t.arrival_mode_id
left join "reporting"."reference_data" dd on dd.id = d.disposition_id
left join encounter_diagnoses ed on ed.encounter_id = e.id
left join encounter_prescriptions ep on ep.encounter_id = e.id
left join encounter_vaccinations ev on ev.encounter_id = e.id
left join encounter_procedures epr on epr.encounter_id = e.id
left join encounter_lab_requests elr on elr.encounter_id = e.id
left join encounter_imaging_requests eir on eir.encounter_id = e.id
left join encounter_notes en on en.encounter_id = e.id
where e.end_datetime is not null


);
create or replace view "reporting"."ds__vaccinations" as (
with vaccine_administrations_metadata as (
    select
        id,
        max(updated_at) as updated_at
    from "reporting"."vaccine_administrations_change_logs"
    group by id
),

administered_circumstances as (
    select
        a.id,
        string_agg(rd_cir.name, '; ') as circumstance_name
    from "reporting"."vaccine_administrations" a
    cross join lateral unnest(a.circumstance_ids) c (unnest_circumstance_id)
    left join "reporting"."reference_data" rd_cir
        on rd_cir.id = c.unnest_circumstance_id
    group by a.id
)

select
    p.display_id,
    p.first_name,
    p.last_name,
    p.id as patient_id,
    p.date_of_birth,
    date_part('year', age(p.date_of_birth)) as age,
    p.sex,
    p.village_id,
    rd_vil.name as village,
    f.id as facility_id,
    f.name as facility,
    d.id as department_id,
    d.name as department,
    lg.id as location_group_id,
    lg.name as location_group,
    l.id as location_id,
    l.name as location,
    av.scheduled_vaccine_id,
    case
        when av.is_given_elsewhere = true and av.datetime is null then null
        else av.datetime::date
    end as vaccination_date,
    sv.category as vaccine_category,
    sv.label as vaccine_name,
    case when sv.category = 'Other' then av.vaccine_brand end as vaccine_brand,
    case when sv.category = 'Other' then av.disease end as disease,
    case
        when av.status = 'GIVEN' then 'Given'
        when av.status = 'NOT_GIVEN' then 'Not given'
        when av.status = 'RECORDED_IN_ERROR' then 'Recorded in error'
        when av.status = 'HISTORICAL' then 'Historical'
    end as vaccine_status,
    sv.dose_label as vaccine_schedule,
    av.batch,
    case
        when av.status in ('GIVEN', 'NOT_GIVEN', 'RECORDED_IN_ERROR') then u.display_name
    end as recorded_by,
    case
        when av.is_given_elsewhere = true then ac.circumstance_name
    end as circumstances,
    case
        when av.status = 'NOT_GIVEN' then null
        when av.status = 'GIVEN' and av.is_given_elsewhere = true then null
        when av.status in ('HISTORICAL', 'RECORDED_IN_ERROR') and av.is_given_elsewhere = true then av.given_by
        when av.status = 'GIVEN' then av.given_by
    end as given_by,
    case when av.is_given_elsewhere = true then av.given_by end as given_elsewhere_by,
    case
        when av.status = 'NOT_GIVEN' then av.given_by
    end as not_given_clinician,
    case
        when av.status = 'NOT_GIVEN' then rd_reason.name
    end as not_given_reason,
    case
        when av.status = 'HISTORICAL' then u.display_name
    end as modified_by,
    vam.updated_at
from "reporting"."vaccine_administrations" av
join "reporting"."encounters" e on e.id = av.encounter_id
join "reporting"."patients" p on p.id = e.patient_id
left join vaccine_administrations_metadata vam on vam.id = av.id
join "reporting"."locations" l on l.id = av.location_id
left join "reporting"."departments" d on d.id = av.department_id
left join "reporting"."location_groups" lg on lg.id = l.location_group_id
join "reporting"."facilities" f
    on f.id = l.facility_id
    and not f.is_sensitive
left join "reporting"."vaccine_schedules" sv on sv.id = av.scheduled_vaccine_id
left join "reporting"."users" u on u.id = av.recorded_by_id
left join "reporting"."reference_data" rd_vil on rd_vil.id = p.village_id
left join "reporting"."reference_data" rd_reason on rd_reason.id = av.not_given_reason_id
left join administered_circumstances ac on ac.id = av.id
);