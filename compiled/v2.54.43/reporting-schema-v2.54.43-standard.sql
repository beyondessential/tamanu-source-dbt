drop schema if exists reporting cascade;
create schema reporting;
grant usage on schema reporting to reporting;
alter default privileges in schema reporting grant select on tables to reporting;
create or replace view "reporting"."map__omop_visit_type" as (
-- Tamanu encounter_type codes -> OMOP Visit concept IDs (OHDSI Athena, vocabulary 'Visit').
-- Universal mapping: applies to every deployment, so it lives in tamanu-source-dbt
-- (derived-elements-conventions.md § map__omop seeds).
-- View-over-values rather than a seed so it ships in the compiled production bundle.

select
    local_code,
    local_name,
    concept_id,
    concept_name,
    vocabulary_id
from (
    values
        ('admission',       'Inpatient Admission',  9201, 'Inpatient Visit',          'Visit'),
        -- concept 262 is not a direct encounter_type lookup; it is applied by
        -- clinical__visit_occurrence when an admission encounter had a prior
        -- emergency/triage/observation phase in encounter_history (BL-002)
        ('admission_from_emergency', 'Emergency Room and Inpatient Admission', 262, 'Emergency Room and Inpatient Visit', 'Visit'),
        ('clinic',          'Outpatient Clinic',    9202, 'Outpatient Visit',          'Visit'),
        ('imaging',         'Imaging',              9202, 'Outpatient Visit',          'Visit'),
        ('emergency',       'Emergency',            9203, 'Emergency Room Visit',      'Visit'),
        ('observation',     'Observation',          9203, 'Emergency Room Visit',      'Visit'),
        ('triage',          'Triage',               9203, 'Emergency Room Visit',      'Visit'),
        ('surveyResponse',  'Survey Response',         0, 'No matching concept',       'Visit'),
        ('vaccination',     'Vaccination',          9202, 'Outpatient Visit',          'Visit')
) as t (local_code, local_name, concept_id, concept_name, vocabulary_id)
);
create or replace view "reporting"."map__omop_sex" as (
-- Tamanu sex codes -> OMOP Gender concept IDs (OHDSI Athena, vocabulary 'Gender').
-- Universal mapping: applies to every deployment, so it lives in tamanu-source-dbt
-- (derived-elements-conventions.md § map__omop seeds).
-- View-over-values rather than a seed so it ships in the compiled production bundle.

select
    local_code,
    local_name,
    concept_id,
    concept_name,
    vocabulary_id
from (
    values
        ('male', 'Male', 8507, 'MALE', 'Gender'),
        ('female', 'Female', 8532, 'FEMALE', 'Gender'),
        ('other', 'Other', 0, 'No matching concept', 'Gender')
) as t (local_code, local_name, concept_id, concept_name, vocabulary_id)
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
            (created_at at time zone 'Australia/Sydney')::date as registration_date
from "public"."patients"
where id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
    and visibility_status = 'merged'
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
create or replace view "reporting"."discharges" as (
select distinct on (d.encounter_id)
    d.id,
    d.note,
    d.encounter_id,
    d.discharger_id as discharged_by_id,
    d.disposition_id,
    d.created_at at time zone 'Australia/Sydney' as created_datetime
from "public"."discharges" d
join "public"."encounters" e on e.id = d.encounter_id
where d.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
order by d.encounter_id asc, d.created_at asc
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
where p.deleted_at is null
    and exists (
        select 1
        from "public"."encounter_prescriptions" ep
        join "public"."encounters" e on e.id = ep.encounter_id
        where ep.prescription_id = p.id
            and ep.deleted_at is null
            and e.deleted_at is null
            and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
    )
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
    eh.change_type::text []
from "public"."encounter_history" eh
join "public"."encounters" e on e.id = eh.encounter_id
where eh.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
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
create or replace view "reporting"."invoice_insurance_plan_items" as (
select
    id,
    invoice_insurance_plan_id,
    invoice_product_id,
    coverage_value
from "public"."invoice_insurance_plan_items"
where deleted_at is null
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
create or replace view "reporting"."patient_field_values" as (
select
    patient_id,
    definition_id,
    value
from "public"."patient_field_values"
where deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
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
create or replace view "reporting"."invoice_price_list_items" as (
select
    id,
    invoice_price_list_id,
    invoice_product_id,
    price,
    is_hidden
from "public"."invoice_price_list_items"
where deleted_at is null
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
            (created_at at time zone 'Australia/Sydney')::date as registration_date
from "public"."patient_additional_data"
where deleted_at is null
    and id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."invoice_items" as (
select
    ii.id,
    ii.invoice_id,
    ii.order_date::date as date,
    ii.product_id,
    ii.product_code_final,
    ii.product_name_final,
    ii.price_final,
    ii.manual_entry_price,
    ii.quantity,
    ii.ordered_by_user_id,
    ii.approved,
    ii.source_record_type,
    ii.source_record_id
from "public"."invoice_items" ii
join "public"."invoices" i on i.id = ii.invoice_id
join "public"."encounters" e on e.id = i.encounter_id
where
    ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."invoice_discounts" as (
select
    id.id,
    id.invoice_id,
    id.percentage,
    id.reason,
    id.is_manual,
    id.applied_by_user_id,
    id.applied_time
from "public"."invoice_discounts" id
join "public"."invoices" i on i.id = id.invoice_id
join "public"."encounters" e on e.id = i.encounter_id
where
    id.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."invoices" as (
select
    i.id,
    i.display_id,
    i.date::timestamp as datetime,
    i.status,
    i.patient_payment_status,
    i.insurer_payment_status,
    i.encounter_id
from "public"."invoices" i
join "public"."encounters" e on e.id = i.encounter_id
where
    i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
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
create or replace view "reporting"."lab_request_logs" as (
select
    lrl.id,
    lrl.created_at at time zone 'Australia/Sydney' as created_datetime,
    lrl.updated_at at time zone 'Australia/Sydney' as updated_datetime,
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
    (created_at at time zone 'Australia/Sydney')::date as registration_date
from "public"."patient_birth_data"
where deleted_at is null
    and id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."invoice_item_finalised_insurances" as (
select
    iifi.id,
    iifi.invoice_item_id,
    iifi.invoice_insurance_plan_id,
    iifi.coverage_value_final
from "public"."invoice_item_finalised_insurances" iifi
join "public"."invoice_items" ii on ii.id = iifi.invoice_item_id
join "public"."invoices" i on i.id = ii.invoice_id
join "public"."encounters" e on e.id = i.encounter_id
where
    iifi.deleted_at is null
    and ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."outpatient_appointments_change_logs" as (
-- Base model for outpatient appointment change logs
-- Extracts appointment modifications from logs.changes table
-- Each row represents a change event to an appointment

with appointment_changes as (
    select
        c.id as change_id,
        c.record_id as appointment_id,
        c.logged_at at time zone 'Australia/Sydney' as modified_datetime,
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
            order by c.logged_at, c.record_updated_at, c.id
        ) as created_by_user_id,
        -- Use LAG to get the previous record state
        lag(c.record_data) over (
            partition by c.record_id
            order by c.logged_at, c.record_updated_at, c.id
        ) as previous_record_data,
        -- Track change sequence
        row_number() over (
            partition by c.record_id
            order by c.logged_at, c.record_updated_at, c.id
        ) as change_sequence
    from "logs"."changes" c
    where c.table_name = 'appointments'
        and c.record_deleted_at is null
        and (c.record_data ->> 'appointment_type_id') is not null
        and (c.record_data ->> 'patient_id') != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
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
create or replace view "reporting"."medication_dispenses" as (
select
    md.id,
    md.pharmacy_order_prescription_id,
    md.quantity,
    md.dispensed_at::timestamp as dispensed_at,
    md.dispensed_by_user_id
from "public"."medication_dispenses" md
join "public"."pharmacy_order_prescriptions" pop
    on pop.id = md.pharmacy_order_prescription_id
join "public"."pharmacy_orders" po on po.id = pop.pharmacy_order_id
join "public"."encounters" e on e.id = po.encounter_id
where md.deleted_at is null
    and pop.deleted_at is null
    and po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
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
    visibility_status,
    autopsy_requested,
    autopsy_findings_used,
    manner_of_death_description,
    pregnancy_moment,
    multiple_pregnancy,
    mother_condition_description
from "public"."patient_death_data"
where deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."lab_test_panels" as (
select
    id,
    code,
    external_code,
    name,
    category_id,
    visibility_status,
    available_facilities
from "public"."lab_test_panels"
where deleted_at is null
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
create or replace view "reporting"."user_designations" as (
select
    id,
    user_id,
    designation_id
from "public"."user_designations"
where deleted_at is null
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
    fc.logged_at at time zone 'Australia/Sydney' as logged_at,
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
create or replace view "reporting"."lab_test_panel_lab_test_types" as (
select
    id,
    lab_test_panel_id,
    lab_test_type_id
from "public"."lab_test_panel_lab_test_types"
where deleted_at is null
);
create or replace view "reporting"."lab_requests" as (
select
    lr.id,
    lr.created_at at time zone 'Australia/Sydney' as created_datetime,
    lr.updated_at at time zone 'Australia/Sydney' as updated_datetime,
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
create or replace view "reporting"."patients" as (
select
    id,
    created_at at time zone 'Australia/Sydney' as created_datetime,
    updated_at at time zone 'Australia/Sydney' as updated_datetime,
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
create or replace view "reporting"."roles" as (
select
    id,
    name
from "public"."roles"
where deleted_at is null
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
create or replace view "reporting"."pharmacy_orders" as (
select
    po.id,
    po.encounter_id,
    po.ordering_clinician_id,
    po.facility_id,
    po.is_discharge_prescription,
    po.date::timestamp as datetime
from "public"."pharmacy_orders" po
join "public"."encounters" e on e.id = po.encounter_id
where po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."pharmacy_order_prescriptions" as (
select
    pop.id,
    pop.pharmacy_order_id,
    pop.prescription_id,
    pop.ongoing_prescription_id,
    pop.display_id,
    pop.quantity,
    pop.repeats,
    pop.is_completed
from "public"."pharmacy_order_prescriptions" pop
join "public"."pharmacy_orders" po on po.id = pop.pharmacy_order_id
join "public"."encounters" e on e.id = po.encounter_id
where pop.deleted_at is null
    and po.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."invoice_products" as (
select
    id,
    name,
    insurable,
    category,
    source_record_id,
    visibility_status
from "public"."invoice_products"
where deleted_at is null
);
create or replace view "reporting"."invoices_invoice_insurance_plans" as (
select
    iiip.id,
    iiip.invoice_id,
    iiip.invoice_insurance_plan_id
from "public"."invoices_invoice_insurance_plans" iiip
join "public"."invoices" i on i.id = iiip.invoice_id
join "public"."encounters" e on e.id = i.encounter_id
where
    iiip.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
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
    fc.logged_at at time zone 'Australia/Sydney' as logged_at,
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
create or replace view "reporting"."refresh_tokens" as (
select
    id,
    device_id,
    user_id,
    expires_at at time zone 'Australia/Sydney' as expires_at,
    created_at at time zone 'Australia/Sydney' as created_at,
    updated_at at time zone 'Australia/Sydney' as updated_at
from
    "public"."refresh_tokens"
where deleted_at is null
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
create or replace view "reporting"."invoice_price_lists" as (
select
    id,
    name,
    code,
    rules,
    evaluation_order,
    created_at at time zone 'Australia/Sydney' as created_at,
    visibility_status
from "public"."invoice_price_lists"
where deleted_at is null
);
create or replace view "reporting"."invoice_patient_payments" as (
select
    ipp.id,
    ipp.invoice_payment_id,
    ipp.method_id,
    ipp.cheque_number
from "public"."invoice_patient_payments" ipp
join "public"."invoice_payments" ipay on ipay.id = ipp.invoice_payment_id
join "public"."invoices" i on i.id = ipay.invoice_id
join "public"."encounters" e on e.id = i.encounter_id
where
    ipp.deleted_at is null
    and ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."permissions" as (
select
    id,
    role_id,
    verb,
    noun,
    object_id
from "public"."permissions"
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
create or replace view "reporting"."invoice_payments" as (
select
    ipay.id,
    ipay.invoice_id,
    ipay.date::date,
    ipay.receipt_number,
    ipay.amount,
    ipay.original_payment_id
from "public"."invoice_payments" ipay
join "public"."invoices" i on i.id = ipay.invoice_id
join "public"."encounters" e on e.id = i.encounter_id
where
    ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
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
create or replace view "reporting"."programs" as (
select
    id,
    code,
    name
from "public"."programs"
where deleted_at is null
);
create or replace view "reporting"."patient_facilities" as (
select
    id,
    created_at at time zone 'Australia/Sydney' as created_at,
    patient_id,
    facility_id
from "public"."patient_facilities"
where deleted_at is null
    and patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
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
create or replace view "reporting"."document_metadata" as (
select
    id,
    name,
    type,
    created_at at time zone 'Australia/Sydney' as created_datetime,
    patient_id,
    encounter_id
from "public"."document_metadata"
where deleted_at is null
);
create or replace view "reporting"."invoice_insurer_payments" as (
select
    iip.id,
    iip.invoice_payment_id,
    iip.insurer_id,
    iip.status,
    iip.reason
from "public"."invoice_insurer_payments" iip
join "public"."invoice_payments" ipay on ipay.id = iip.invoice_payment_id
join "public"."invoices" i on i.id = ipay.invoice_id
join "public"."encounters" e on e.id = i.encounter_id
where
    iip.deleted_at is null
    and ipay.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."invoices_change_logs" as (
select
    c.id as change_id,
    c.record_id::uuid as invoice_id,
    c.logged_at,
    c.updated_by_user_id,
    c.record_data ->> 'status' as status,
    i.encounter_id,
    lag(c.record_data ->> 'status') over (
        partition by c.record_id
        order by c.logged_at, c.record_updated_at, c.id
    ) as previous_status,
    row_number() over (
        partition by c.record_id
        order by c.logged_at, c.record_updated_at, c.id
    ) as change_sequence
from "logs"."changes" c
join "public"."invoices" i
    on i.id = c.record_id::uuid
    and i.deleted_at is null
join "public"."encounters" e
    on e.id = i.encounter_id
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
where
    c.table_name = 'invoices'
    and c.record_deleted_at is null
);
create or replace view "reporting"."invoice_item_discounts" as (
select
    iid.id,
    iid.invoice_item_id,
    iid.amount,
    iid.type,
    iid.reason
from "public"."invoice_item_discounts" iid
join "public"."invoice_items" ii on ii.id = iid.invoice_item_id
join "public"."invoices" i on i.id = ii.invoice_id
join "public"."encounters" e on e.id = i.encounter_id
where
    iid.deleted_at is null
    and ii.deleted_at is null
    and i.deleted_at is null
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
);
create or replace view "reporting"."discharges_change_logs" as (
-- Base model for discharge change logs
-- Extracts discharge record changes from logs.changes
-- Each row represents a change event on a discharge record, ordered by change_sequence

select
    c.id as change_id,
    c.record_id as discharge_id,
    d.encounter_id,
    c.logged_at at time zone 'Australia/Sydney' as changed_datetime,
    c.updated_by_user_id as changed_by_user_id,
    c.record_data ->> 'note' as note,
    c.record_data ->> 'discharger_id' as discharger_id,
    c.record_data ->> 'disposition_id' as disposition_id,
    row_number() over (
        partition by c.record_id
        order by c.logged_at, c.record_updated_at, c.id
    ) as change_sequence
from "logs"."changes" c
join "public"."discharges" d
    on d.id = c.record_id
    and d.deleted_at is null
join "public"."encounters" e
    on e.id = d.encounter_id
    and e.deleted_at is null
    and e.patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
where
    c.table_name = 'discharges'
    and c.record_deleted_at is null
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
create or replace view "reporting"."reference_data" as (
select
    id,
    code,
    name,
    type,
    visibility_status,
    available_facilities
from "public"."reference_data"
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
    range_text as result_type,
    options,
    lab_test_category_id,
    visibility_status,
    is_sensitive,
    available_facilities
from "public"."lab_test_types"
where deleted_at is null
);
create or replace view "reporting"."invoice_insurance_plans" as (
select
    id,
    name,
    code,
    default_coverage,
    visibility_status
from "public"."invoice_insurance_plans"
where deleted_at is null
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
create or replace view "reporting"."notes" as (
-- May include notes for the test patient.
select
    n.id,
    n.date::timestamp as datetime,
    n.content,
    n.note_type_id,
    rd.code as note_type,
    n.record_type,
    n.record_id,
    n.author_id as authored_by_id,
    n.on_behalf_of_id,
    n.revised_by_id as updated_note_id,
    n.visibility_status
from "public"."notes" n
join "public"."reference_data" rd
    on rd.id = n.note_type_id
where n.deleted_at is null
);
create or replace view "reporting"."reference_data_relations" as (
select
    id,
    reference_data_id,
    reference_data_parent_id,
    type
from "public"."reference_data_relations"
where deleted_at is null
);
create or replace view "reporting"."ref__location" as (
-- ref__location -- OMOP LOCATION wrapper over Tamanu geographic reference data.
-- One row per village (BL-001..BL-002), denormalised with its subdivision, division,
-- and country resolved by walking reference_data_relations (BL-003..BL-004).
-- Sources only from bases/ (D10); OMOP column naming applied (D2).
-- See specs/dbt-model/ref__location.md.

with recursive places as (
    select
        id,
        code,
        name,
        type as level
    from "reporting"."reference_data"
    -- every level of the address hierarchy is kept so the ancestor chain above a
    -- village stays connected even where an intermediate level (e.g. settlement)
    -- sits between two emitted levels, though only villages are emitted (BL-002)
    where type in ('village', 'settlement', 'subdivision', 'division', 'country')
),

-- parent links where both ends are geographic places, so the walk stays inside
-- the address hierarchy without depending on the relation's own type (BL-002)
relations as (
    select
        r.reference_data_id as child_id,
        r.reference_data_parent_id as parent_id
    from "reporting"."reference_data_relations" r
    inner join places c on c.id = r.reference_data_id
    inner join places par on par.id = r.reference_data_parent_id
),

-- each village paired with itself and every ancestor (BL-003)
-- (cast to text so the anchor and recursive terms share a column type)
ancestry (location_id, ancestor_id) as (
    select id::text, id::text from places where level = 'village'
    union all
    select a.location_id, r.parent_id::text
    from ancestry a
    inner join relations r on r.child_id = a.ancestor_id
),

ancestor_levels as (
    select
        a.location_id,
        p.level as ancestor_level,
        p.name as ancestor_name
    from ancestry a
    inner join places p on p.id = a.ancestor_id
)

-- one row per village; the village name is the OMOP city, ancestor levels map onto
-- the remaining OMOP LOCATION columns where available. This CASE is the per-deployment
-- adjustment point if a deployment's level->column correspondence differs (BL-004)
select
    pl.id as location_id,
    pl.code as location_source_value,
    pl.name as city,
    max(case when al.ancestor_level = 'subdivision' then al.ancestor_name end)
        as county,
    max(case when al.ancestor_level = 'division' then al.ancestor_name end)
        as state,
    max(case when al.ancestor_level = 'country' then al.ancestor_name end)
        as country_source_value
from places pl
left join ancestor_levels al on al.location_id = pl.id
where pl.level = 'village'
group by pl.id, pl.code, pl.name
);
create or replace view "reporting"."ref__provider" as (
-- ref__provider -- OMOP PROVIDER wrapper over Tamanu users (clinicians/examiners).
-- One row per user (BL-001); thin projection with no joins, so grain is users.id verbatim.
-- Native UUID PK (D1). Sources only from bases/ (D10); OMOP column naming applied (D2).
-- Specialty/care-site/demographics deliberately omitted (BL-004).
-- See specs/dbt-model/ref__provider.md for BL-001..BL-004.

with users as (
    select * from "reporting"."users"
)

select
    -- identity (BL-001, BL-002) -- native UUID PK, no remap to OMOP integer IDs (D1)
    u.id           as provider_id,
    u.display_name as provider_name,
    u.display_id   as provider_source_value,

    -- single-valued account role, carried to distinguish clinical from non-clinical users
    -- (specialty is a many-to-many in user_designations and is not emitted, BL-003/BL-004)
    u.role         as role

from users u
);
create or replace view "reporting"."ref__care_site" as (
-- ref__care_site -- OMOP CARE_SITE wrapper. Heterogeneous by design: one row per Tamanu
-- department (the organizational care unit, care_site_type = 'department') and one row per
-- location (the physical room/bed, care_site_type = 'location'). Locations feed both
-- clinical__visit_occurrence.care_site_id and clinical__visit_detail.care_site_id. Each care
-- site is denormalised with its parent facility. Native UUID PK (D1). Sources only from
-- bases/ (D10); OMOP column naming applied (D2).
-- See specs/dbt-model/ref__care_site.md for BL-001..BL-006.

with departments as (
    select * from "reporting"."departments"
),

locations as (
    select * from "reporting"."locations"
),

facilities as (
    select * from "reporting"."facilities"
),

-- organizational care unit (BL-001, BL-005)
department_sites as (
    select
        'department'   as care_site_type,
        d.id::varchar  as care_site_id,
        d.name         as care_site_name,
        d.code         as care_site_source_value,
        d.facility_id  as facility_id
    from departments d
),

-- physical care unit: individual location (room/bed) (BL-001, BL-006)
location_sites as (
    select
        'location'      as care_site_type,
        loc.id::varchar as care_site_id,
        loc.name        as care_site_name,
        loc.code        as care_site_source_value,
        loc.facility_id as facility_id
    from locations loc
),

care_sites as (
    select * from department_sites
    union all
    select * from location_sites
)

select
    -- identity (BL-001) -- native UUID PK, no remap to OMOP integer IDs (D1)
    cs.care_site_id,
    cs.care_site_type,
    cs.care_site_name,
    cs.care_site_source_value,

    -- place of service: source value only. No place_of_service_concept_id — OMOP's Place
    -- of Service vocabulary has no standard concepts, so there is nothing domain-correct to
    -- populate; the source value is retained for deployments that map it downstream (BL-002)
    f.type as place_of_service_source_value,

    -- parent facility, denormalised onto the care site (BL-003)
    cs.facility_id as facility_id,
    f.name         as facility_name

from care_sites cs
-- left join so a care site whose facility is missing/soft-deleted is still emitted (BL-003)
left join facilities f on f.id = cs.facility_id
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
    pdd.mother_condition_description as condition_in_mother_affecting_fetus_or_newborn,
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
create or replace view "reporting"."ds__encounter_invoices" as (
with invoice_finalised as (
    -- BL-015: most recent transition into finalised status per invoice
    select
        icl.invoice_id,
        max(icl.logged_at at time zone 'Australia/Sydney') as finalised_at
    from "reporting"."invoices_change_logs" icl
    where
        icl.status = 'finalised'
        and (icl.previous_status is null or icl.previous_status != 'finalised')
    group by icl.invoice_id
),

invoice_context as materialized (
    -- Per-invoice context for price-list resolution, mirroring the inputs the
    -- app passes to getIdForPatientEncounter. Facility-agnostic: the consumer
    -- applies any facility or sensitivity scoping. Billing type falls back to
    -- the patient's additional data when the encounter has none.
    -- `materialized` is load-bearing: it is referenced once, so without the hint
    -- Postgres inlines it and drives the `cross join invoice_price_lists` from
    -- the encounters table (exploding to ~745k rows). Materialising bounds the
    -- cross join to the invoice count (3.6x faster on the all-time view).
    select
        i.id as invoice_id,
        f.id as facility_id,
        coalesce(e.patient_billing_type_id, pad.patient_billing_type_id) as patient_billing_type_id,
        -- BL-006: patient age in completed years at the invoice date, computed once
        date_part('year', age(i.datetime, p.date_of_birth)) as age_at_invoice
    from "reporting"."invoices" i
    join "reporting"."encounters" e
        on e.id = i.encounter_id
    join "reporting"."locations" l
        on l.id = e.location_id
    join "reporting"."facilities" f
        on f.id = l.facility_id
    join "reporting"."patients" p
        on p.id = e.patient_id
    left join "reporting"."patient_additional_data" pad
        on pad.patient_id = e.patient_id
),

claimed_facilities as (
    -- Facilities explicitly claimed by a current price list -- computed once
    -- so the facility-exclusion check below is a small anti-join rather than a
    -- correlated re-scan of invoice_price_lists per invoice.
    select distinct ipl.rules ->> 'facilityId' as facility_id
    from "reporting"."invoice_price_lists" ipl
    where ipl.visibility_status = 'current'
        and (ipl.rules ->> 'facilityId') is not null
),

invoice_price_list as (
    -- BL-006: resolve the single matching price list per invoice, mirroring
    -- getIdForPatientEncounter. Matches on facility (with exclusionary logic),
    -- patient billing type, and patient age in completed years at the invoice
    -- date (the app resolves at invoice time). When several match, the lowest
    -- evaluation_order wins, then earliest created_at, then code -- mirroring
    -- the application ordering (Postgres asc is nulls-last, so price lists with
    -- no evaluation_order fall back to created_at/code, as the app intends).
    select distinct on (ic.invoice_id)
        ic.invoice_id,
        ipl.id as invoice_price_list_id
    from invoice_context ic
    cross join "reporting"."invoice_price_lists" ipl
    where ipl.visibility_status = 'current'
        -- Facility: direct match, or no facility rule and this facility
        -- is not explicitly claimed by another price list
        and (
            (ipl.rules ->> 'facilityId') = ic.facility_id
            or (
                (ipl.rules ->> 'facilityId') is null
                and not exists (
                    select 1 from claimed_facilities cf
                    where cf.facility_id = ic.facility_id
                )
            )
        )
        -- Patient billing type
        and (
            (ipl.rules ->> 'patientType') is null
            or (ipl.rules ->> 'patientType') = ic.patient_billing_type_id
        )
        -- Patient age at the invoice date: exact numeric or min/max range
        and (
            (ipl.rules -> 'patientAge') is null
            or (
                jsonb_typeof(ipl.rules -> 'patientAge') = 'number'
                and ic.age_at_invoice
                = (ipl.rules ->> 'patientAge')::integer
            )
            or (
                jsonb_typeof(ipl.rules -> 'patientAge') = 'object'
                and (
                    (ipl.rules -> 'patientAge' ->> 'min') is null
                    or ic.age_at_invoice
                    >= (ipl.rules -> 'patientAge' ->> 'min')::integer
                )
                and (
                    (ipl.rules -> 'patientAge' ->> 'max') is null
                    or ic.age_at_invoice
                    <= (ipl.rules -> 'patientAge' ->> 'max')::integer
                )
            )
        )
    order by ic.invoice_id asc, ipl.evaluation_order asc, ipl.created_at asc, ipl.code asc
),

item_unit_price as (
    -- BL-007: mirrors getInvoiceItemPrice. Resolves the unit price once
    -- (price_final, else manual entry, else the resolved price-list price, else 0).
    select
        ii.id as invoice_item_id,
        ii.invoice_id,
        ii.product_id,
        ii.date,
        -- product_name_final is snapshotted at finalisation, so it is null for
        -- in-progress invoices -- fall back to the live product name
        coalesce(ii.product_name_final, ip.name) as product_name,
        ii.quantity,
        ip.category,
        ip.insurable,
        coalesce(
            ii.price_final,
            ii.manual_entry_price,
            ipli.price,
            0
        ) as price
    from "reporting"."invoice_items" ii
    left join "reporting"."invoice_products" ip
        on ip.id = ii.product_id
    left join invoice_price_list ipl_match
        on ipl_match.invoice_id = ii.invoice_id
    -- One price-list item per (price list and product) is guaranteed by a DB
    -- unique constraint on invoice_price_list_items, so this join cannot fan out.
    left join "reporting"."invoice_price_list_items" ipli
        on ipli.invoice_price_list_id = ipl_match.invoice_price_list_id
        and ipli.invoice_product_id = ii.product_id
        and ipli.is_hidden = false
),

item_resolved_price as (
    -- BL-008: mirrors getInvoiceItemTotalDiscountedPrice. Applies the item-level
    -- discount (percentage or flat amount) to unit price x quantity.
    select
        iup.invoice_item_id,
        iup.invoice_id,
        iup.product_id,
        iup.date,
        iup.product_name,
        iup.quantity,
        iup.category,
        iup.insurable,
        iup.price,
        case
            when iid.type = 'percentage'
                then iup.price * iup.quantity * (1 - coalesce(iid.amount, 0))
            when iid.type = 'amount'
                -- flat amount subtracted with no floor, so an over-large discount
                -- can take the line total negative (matching the application)
                then iup.price * iup.quantity - coalesce(iid.amount, 0)
            else iup.price * iup.quantity
        end as discounted_total
    from item_unit_price iup
    -- Tamanu enforces one discount per item (application logic, no DB
    -- unique constraint) and the id tie-break makes distinct on
    -- deterministic if unexpected duplicates exist
    left join (
        select distinct on (invoice_item_id)
            invoice_item_id,
            amount,
            type
        from "reporting"."invoice_item_discounts"
        order by invoice_item_id, id
    ) iid on iid.invoice_item_id = iup.invoice_item_id
),

item_coverage as (
    -- BL-010: mirrors getInvoiceItemCoveragePercentage applied per plan (as the
    -- app does over invoiceForResponse's insurancePlanItems). For each insurance
    -- plan currently linked to the invoice, coverage is the finalised snapshot
    -- for that (item, plan) when present, otherwise the live per-product
    -- coverage, falling back to the plan default, then 0. Summed across the
    -- item's plans. Driving from the linked plans (not the finalised rows) keeps
    -- finalised a per-plan override, so a mix of finalised and live plans, or a
    -- plan unlinked after finalisation, resolves exactly as the app does.
    select
        irp.invoice_item_id,
        sum(coalesce(
            -- Finalised: snapshotted per-plan coverage, immune to plan changes
            fin.coverage_value_final,
            -- Live: per-product coverage, then the plan default
            iipi.coverage_value,
            iip.default_coverage,
            0
        )) as total_pct
    from item_resolved_price irp
    join "reporting"."invoices_invoice_insurance_plans" iiip
        on iiip.invoice_id = irp.invoice_id
    join "reporting"."invoice_insurance_plans" iip
        on iip.id = iiip.invoice_insurance_plan_id
    left join "reporting"."invoice_insurance_plan_items" iipi
        on iipi.invoice_insurance_plan_id = iiip.invoice_insurance_plan_id
        and iipi.invoice_product_id = irp.product_id
    left join "reporting"."invoice_item_finalised_insurances" fin
        on fin.invoice_item_id = irp.invoice_item_id
        and fin.invoice_insurance_plan_id = iiip.invoice_insurance_plan_id
    where irp.insurable = true
    group by irp.invoice_item_id
),

insurance_coverage_agg as (
    -- BL-010: per-invoice insurance coverage, mirroring
    -- getInsuranceCoverageTotalAmount. Applies the combined coverage percentage
    -- to each insurable item's discounted price, capping per-item coverage at
    -- the discounted total (handles combined percentages over 100%). No filter
    -- on the sign of the discounted total -- the app includes negatively
    -- discounted items, where the cap pins coverage to the (negative) total.
    select
        irp.invoice_id,
        round(sum(least(
            irp.discounted_total * ic.total_pct / 100,
            irp.discounted_total
        )), 2) as insurance_coverage
    from item_resolved_price irp
    join item_coverage ic
        on ic.invoice_item_id = irp.invoice_item_id
    group by irp.invoice_id
),

invoice_items_agg as (
    -- BL-009: invoice item total and BL-016: the products with no category
    select
        irp.invoice_id,
        string_agg(
            irp.product_name, ', '
            order by irp.date
        ) filter (where irp.category is null) as products_no_category,
        sum(irp.discounted_total) as item_total
    from item_resolved_price irp
    group by irp.invoice_id
),

invoice_discount_pct as (
    -- BL-011: Tamanu enforces one discount per invoice (application logic, no DB
    -- unique constraint) and if unexpected duplicates exist the most recently
    -- applied one wins deterministically
    select distinct on (invoice_id)
        invoice_id,
        percentage
    from "reporting"."invoice_discounts"
    order by invoice_id, applied_time desc, id
),

invoice_payments_agg as (
    -- BL-012: refunds are stored as positive amounts with
    -- original_payment_id set and negated so the sum gives the net patient
    -- payment total. The ipp.id filter keeps only patient payments, so a
    -- refund is netted only when it shares the patient-payment linkage of the
    -- payment it reverses. Insurer-payment refunds (no invoice_patient_payments
    -- row) are intentionally excluded, matching the patient-payment scope.
    select
        ipay.invoice_id,
        sum(
            case when ipay.original_payment_id is not null then -ipay.amount else ipay.amount end
        ) filter (where ipp.id is not null) as patient_payment
    from "reporting"."invoice_payments" ipay
    left join "reporting"."invoice_patient_payments" ipp
        on ipp.invoice_payment_id = ipay.id
    group by ipay.invoice_id
)

-- One row per invoice. The status column lets consumers filter (e.g. exclude
-- cancelled) and aggregate; the snapshot-over-live coverage rule means a single
-- dataset serves both finalised and in-progress invoices.
select
    i.id as invoice_id,
    i.encounter_id,
    i.status,
    i.datetime as invoice_datetime,
    -- BL-015: finalisation timestamp, in deployment-local time (null until finalised)
    inf.finalised_at as invoice_finalised_datetime,
    -- BL-009: invoice total (sum of discounted item totals)
    iia.item_total as invoice_total,
    ica.insurance_coverage,
    -- BL-011: invoice-level discount amount, percentage applied to the patient
    -- subtotal (item total less insurance coverage), mirroring
    -- getInvoiceLevelDiscountAmount over patientSubtotal
    round(
        (coalesce(iia.item_total, 0) - coalesce(ica.insurance_coverage, 0))
        * coalesce(idsc.percentage, 0),
        2
    ) as invoice_discount,
    ipa.patient_payment,
    iia.products_no_category
from "reporting"."invoices" i
left join invoice_finalised inf
    on inf.invoice_id = i.id
left join invoice_items_agg iia
    on iia.invoice_id = i.id
left join insurance_coverage_agg ica
    on ica.invoice_id = i.id
left join invoice_discount_pct idsc
    on idsc.invoice_id = i.id
left join invoice_payments_agg ipa
    on ipa.invoice_id = i.id
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
    pad.country_id,
    pvu.due_date,
    pvu.vaccine_category,
    pvu.vaccine_schedules_id,
    sv.label as vaccine_name,
    sv.dose_label as vaccine_schedule,
    pvu.status as vaccine_status
-- BL-001: one row per outstanding scheduled dose per patient
from "reporting"."patient_vaccinations_upcoming" pvu
join "reporting"."patients" p on p.id = pvu.patient_id
join "reporting"."vaccine_schedules" sv on sv.id = pvu.vaccine_schedules_id
left join "reporting"."reference_data" village on village.id = p.village_id
-- BL-003: current country of residence (patient_additional_data is one row per
-- patient, so this join does not fan out the vaccination rows)
left join "reporting"."patient_additional_data" pad on pad.patient_id = p.id
-- BL-002: exclude deceased patients
where p.date_of_death is null
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
create or replace view "reporting"."ds__usage_quality_metrics_patient_details" as (
with data as (
    select
        p.id as patient_id,
        pm.id as patient_merged_id,
        coalesce(nullif(trim(p.first_name), ''), nullif(trim(pm.first_name), '')) as first_name,
        coalesce(nullif(trim(p.last_name), ''), nullif(trim(pm.last_name), '')) as last_name,
        coalesce(p.date_of_birth, pm.date_of_birth) as date_of_birth,
        coalesce(nullif(trim(p.village_id), ''), nullif(trim(pm.village_id), '')) as village_id,
        nullif(trim(pad.nursing_zone_id), '') as nursing_zone_id,
        nullif(trim(pad.medical_area_id), '') as medical_area_id,
        nullif(trim(pad.subdivision_id), '') as subdivision_id,
        nullif(trim(pad.division_id), '') as division_id,
        nullif(trim(pad.primary_contact_number), '') as primary_contact_number,
        nullif(trim(pad.secondary_contact_number), '') as secondary_contact_number
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
create or replace view "reporting"."ds__invoice_products" as (


with price_pivot as (
    select
        invoice_product_id
        , max(case when invoice_price_list_id = 'invoicePriceList-1' then price end)
            as price_1
    from "reporting"."invoice_price_list_items"
    where is_hidden = false
    group by invoice_product_id
),

insurance_pivot as (
    select
        invoice_product_id
        , max(case when invoice_insurance_plan_id = 'insurance-plan-1' then coverage_value end)
            as cov_1
    from "reporting"."invoice_insurance_plan_items"
    group by invoice_product_id
),

-- available_facilities lives on the originating reference data row.
-- For drugs, procedure types and imaging areas, source_record_id points
-- at reference_data and for lab products it points at lab_test_panels
-- or lab_test_types and only one of these joins will match per product.
product_available_facility_ids as (
    select
        ip.id as invoice_product_id,
        coalesce(
            rd.available_facilities,
            ltp.available_facilities,
            ltt.available_facilities
        ) as available_facility_ids
    from "reporting"."invoice_products" ip
    left join "reporting"."reference_data" rd
        on rd.id = ip.source_record_id
    left join "reporting"."lab_test_panels" ltp
        on ltp.id = ip.source_record_id
    left join "reporting"."lab_test_types" ltt
        on ltt.id = ip.source_record_id
),

product_available_facilities as (
    select
        pafi.invoice_product_id,
        string_agg(f.name, ', ' order by f.name) as available_facilities
    from product_available_facility_ids pafi
    cross join lateral jsonb_array_elements_text(pafi.available_facility_ids) as fid
    join "reporting"."facilities" f
        on f.id = fid
    group by pafi.invoice_product_id
)

select
    ip.id,
    ip.name,
    ip.insurable,
    ip.category,
    ip.source_record_id,
    paf.available_facilities,
    ip.visibility_status,
    coalesce(ltt.external_code, ltp.external_code) as external_code
    , pp.price_1 as "Price: Price List 1"
    , case
        when ip.insurable = false then 'n/a'
        else cast(
            coalesce(
                insurp.cov_1,100
            ) as text
        )
    end as "Insurance: Insurance Plan 1"
from "reporting"."invoice_products" ip
left join price_pivot pp on pp.invoice_product_id = ip.id
left join insurance_pivot insurp on insurp.invoice_product_id = ip.id
left join product_available_facilities paf on paf.invoice_product_id = ip.id
left join "reporting"."lab_test_types" ltt on ltt.id = ip.source_record_id
left join "reporting"."lab_test_panels" ltp on ltp.id = ip.source_record_id
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
    subdivision.id as subdivision_id,
    subdivision.name as subdivision,
    division.id as division_id,
    division.name as division,
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
left join "reporting"."reference_data" village on village.id = p.village_id
left join "reporting"."reference_data" cob on cob.id = pad.country_of_birth_id
left join "reporting"."reference_data" nationality on nationality.id = pad.nationality_id
left join "reporting"."reference_data" ethnicity on ethnicity.id = pad.ethnicity_id
left join "reporting"."reference_data" occupation on occupation.id = pad.occupation_id
left join "reporting"."reference_data" religion on religion.id = pad.religion_id
left join "reporting"."reference_data" billing on billing.id = pad.patient_billing_type_id
left join "reporting"."reference_data" subdivision on subdivision.id = pad.subdivision_id
left join "reporting"."reference_data" division on division.id = pad.division_id
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
        and f.is_sensitive = False
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
            partition by eh.encounter_id, ('encounter_type' = any(eh.change_type))
            order by eh.datetime
        ) as encounter_type_change_sequence,
        lag(lg.id) over (
            partition by eh.encounter_id
            order by eh.datetime
        ) as prev_location_group_id
    from admission_encounters ae
    left join "reporting"."encounter_history" eh
        on eh.encounter_id = ae.id
        and eh.encounter_type = 'admission'
        and (eh.change_type is null or eh.change_type && array['encounter_type', 'examiner', 'department', 'location'])
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
        bool_or('encounter_type' = any(change_type) and encounter_type_change_sequence = 1) as is_transfer,
        min(datetime) filter (where change_type is null or change_type && array['encounter_type', 'examiner']) as admission_datetime,
        array_agg(
            datetime
            order by datetime
        ) filter (where change_type is null or change_type && array['encounter_type', 'examiner']
        ) as clinician_datetimes,
        array_agg(
            clinician_id
            order by datetime
        ) filter (where change_type is null or change_type && array['encounter_type', 'examiner']
        ) as clinician_ids,
        array_agg(
            clinician_name
            order by datetime
        ) filter (where change_type is null or change_type && array['encounter_type', 'examiner']
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
    where change_type is null or change_type && array['encounter_type', 'department']
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
    where change_type is null or change_type && array['encounter_type', 'location']
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
    where (change_type is null or change_type && array['encounter_type', 'location'])
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
            case when ed.is_primary
                    then rd.code
            end,
            '; '
            order by ed.datetime
        ) as primary_diagnoses_codes,
        string_agg(
            case when not ed.is_primary
                    then rd.name || ' (' || rd.code || ')'
            end,
            '; '
            order by ed.datetime
        ) as secondary_diagnoses,
        string_agg(
            case when not ed.is_primary
                    then rd.code
            end,
            '; '
            order by ed.datetime
        ) as secondary_diagnoses_codes
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
    ed.primary_diagnoses_codes,
    ed.secondary_diagnoses,
    ed.secondary_diagnoses_codes
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
    and f.is_sensitive = False
join "reporting"."survey_responses" sr on sr.id = rf.survey_response_id
join "reporting"."surveys" s on s.id = sr.survey_id
join "reporting"."patients" p on p.id = e.patient_id
join "reporting"."users" u on u.id = e.clinician_id
join "reporting"."departments" d on d.id = e.department_id
left join diagnoses ed on ed.encounter_id = rf.initiating_encounter_id


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
    and f.is_sensitive = False
left join "reporting"."departments" d on d.id = e.department_id
left join "reporting"."discharges" ds on ds.encounter_id = e.id
left join non_system_notes n on n.record_id = e.id


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
create or replace view "reporting"."ds__imaging_requests" as (


with results as (
    select
        imaging_request_id,
        min(datetime) as completed_datetime
    from "reporting"."imaging_results"
    group by imaging_request_id
),

imaging_area_notes as (
    select
        record_id as imaging_request_id,
        string_agg(content, ', ' order by datetime) as imaging_area
    from "reporting"."notes"
    where record_type = 'ImagingRequest'
        and note_type = 'areaToBeImaged'
    group by record_id
),

imaging_areas as (
    select
        ir.id as imaging_request_id,
        coalesce(
            string_agg(ia.name, ', ' order by ia.name),
            n.imaging_area
        ) as imaging_area
    from "reporting"."imaging_requests" ir
    left join "reporting"."imaging_request_areas" ira on ira.imaging_request_id = ir.id
    left join "reporting"."reference_data" ia on ia.id = ira.area_id
    left join imaging_area_notes n on n.imaging_request_id = ir.id
    group by ir.id, n.imaging_area
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
    areas.imaging_area,
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
    and f.is_sensitive = False
left join "reporting"."departments" d on d.id = e.department_id
left join "reporting"."users" su on su.id = e.clinician_id
left join "reporting"."users" ru on ru.id = ir.requested_by_id
left join imaging_areas areas on areas.imaging_request_id = ir.id
left join "reporting"."reference_data" v on v.id = p.village_id
left join results irs on irs.imaging_request_id = ir.id


);
create or replace view "reporting"."ds__discharge_audit" as (


-- Discharge Audit Dataset
-- One row per discharge record, which is one row per discharged encounter.
--
-- Exposes both discharge timestamps side by side:
--   discharge_datetime_entered   - the clinical discharge date and time keyed into the discharge form
--   discharge_recorded_datetime  - when the discharge was actually recorded in Tamanu
--
-- The gap between them is the discharge-recording backlog.

-- BL-001: the discharges base is already one row per encounter with deleted discharges,
-- deleted encounters and the test patient removed
with discharge_records as (
    select
        d.id as discharge_id,
        d.encounter_id,
        d.discharged_by_id,
        d.disposition_id,
        d.created_datetime,
        -- BL-004: system-generated discharges are flagged, not filtered out
        coalesce(d.note like 'Automatically discharged%', false) as is_auto_discharge
    from "reporting"."discharges" d
),

-- BL-002: the earliest change log entry for a discharge is its insert
change_log_summary as (
    select
        cl.discharge_id,
        min(cl.changed_datetime) as recorded_datetime,
        -- BL-008: edits after the insert. The left join below leaves this null, not zero,
        -- where the change log does not cover the discharge at all
        count(*) - 1 as later_edit_count,
        max(cl.changed_by_user_id) filter (where cl.change_sequence = 1) as recorded_by_user_id
    from "reporting"."discharges_change_logs" cl
    group by cl.discharge_id
),

encounter_details as (
    select
        e.id as encounter_id,
        e.patient_id,
        e.encounter_type,
        e.start_datetime,
        e.end_datetime,
        e.department_id,
        e.location_id,
        dept.name as department_name,
        loc.name as location_name,
        f.id as facility_id,
        f.name as facility_name
    from "reporting"."encounters" e
    join "reporting"."locations" loc on loc.id = e.location_id
    join "reporting"."facilities" f on f.id = loc.facility_id
        -- BL-009: the standard and sensitive variants partition on this flag
        and f.is_sensitive = False
    left join "reporting"."departments" dept on dept.id = e.department_id
),

-- BL-010: diagnoses recorded against the encounter, split primary from secondary and
-- rolled up so the one-row-per-encounter grain is preserved. Same four columns as the
-- admissions dataset, but the name columns carry the name alone -- the code already has
-- its own column, so appending it to the name repeated it and left neither column clean
-- to filter or group on. admissions.sql still appends; the two differ on this until it
-- is changed too. The encounter_diagnoses base model already drops deleted rows and
-- diagnoses of disproven or error certainty.
encounter_diagnosis_summary as (
    select
        edx.encounter_id,
        string_agg(
            case when edx.is_primary
                    then rd.name
            end,
            '; '
            order by edx.datetime
        ) as primary_diagnoses,
        string_agg(
            case when edx.is_primary
                    then rd.code
            end,
            '; '
            order by edx.datetime
        ) as primary_diagnoses_codes,
        string_agg(
            case when not edx.is_primary
                    then rd.name
            end,
            '; '
            order by edx.datetime
        ) as secondary_diagnoses,
        string_agg(
            case when not edx.is_primary
                    then rd.code
            end,
            '; '
            order by edx.datetime
        ) as secondary_diagnoses_codes
    from "reporting"."encounter_diagnoses" edx
    join "reporting"."reference_data" rd on rd.id = edx.diagnosis_id
    group by edx.encounter_id
),

discharge_audit as (
    select
        dr.discharge_id,
        dr.is_auto_discharge,
        dr.disposition_id as discharge_disposition_id,
        dr.discharged_by_id as discharger_id,
        ed.encounter_id,
        ed.encounter_type,
        ed.patient_id,
        ed.department_id,
        ed.department_name,
        ed.location_id,
        ed.location_name,
        ed.facility_id,
        ed.facility_name,
        ed.start_datetime as admission_datetime,
        ed.end_datetime as discharge_datetime_entered,
        cls.later_edit_count,
        cls.recorded_by_user_id,
        -- BL-002: fall back to the discharge record's own creation time where the
        -- change log does not reach back far enough
        coalesce(cls.recorded_datetime, dr.created_datetime) as discharge_recorded_datetime
    from discharge_records dr
    join encounter_details ed on ed.encounter_id = dr.encounter_id
    left join change_log_summary cls on cls.discharge_id = dr.discharge_id
)

select
    da.discharge_id,
    da.encounter_id,
    da.encounter_type,
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    initcap(p.sex::text) as sex,
    p.village_id,
    village.name as village,
    da.facility_id,
    da.facility_name as facility,
    da.department_id,
    da.department_name as department,
    da.location_id,
    da.location_name as location,
    da.admission_datetime,
    da.discharge_datetime_entered,
    da.discharge_recorded_datetime,
    -- BL-003: both timestamps are naive deployment-local, so the date difference is
    -- the number of calendar days the discharge went unrecorded
    da.discharge_recorded_datetime::date
    - da.discharge_datetime_entered::date as days_between_discharge_and_recording,
    da.discharge_disposition_id,
    disposition.name as discharge_disposition,
    da.discharger_id,
    -- BL-006: the clinician named on the form and the user who recorded it are
    -- different people in general, so both are kept
    discharger.display_name as discharger_on_form,
    da.recorded_by_user_id,
    -- BL-005: the nil UUID audit user has no matching user, so this renders blank
    recorder.display_name as recorded_by_user,
    da.is_auto_discharge,
    da.later_edit_count,
    eds.primary_diagnoses,
    eds.primary_diagnoses_codes,
    eds.secondary_diagnoses,
    eds.secondary_diagnoses_codes
from discharge_audit da
-- BL-001: the patient base drops deleted, merged and test patients, and this join
-- carries that exclusion into the grain
join "reporting"."patients" p on p.id = da.patient_id
left join "reporting"."reference_data" village on village.id = p.village_id
left join "reporting"."reference_data" disposition on disposition.id = da.discharge_disposition_id
left join "reporting"."users" discharger on discharger.id = da.discharger_id
left join "reporting"."users" recorder on recorder.id = da.recorded_by_user_id
left join encounter_diagnosis_summary eds on eds.encounter_id = da.encounter_id


);
create or replace view "reporting"."ds__medication_dispenses" as (


select
    md.id,
    md.quantity,
    md.dispensed_at,
    e.patient_id,
    po.facility_id,
    f.name as facility,
    pr.medication_id,
    m.code as medication_code,
    m.name as medication
from "reporting"."medication_dispenses" md
join "reporting"."pharmacy_order_prescriptions" pop
    on pop.id = md.pharmacy_order_prescription_id
join "reporting"."pharmacy_orders" po
    on po.id = pop.pharmacy_order_id
join "reporting"."encounters" e 
    on e.id = po.encounter_id
-- prescription_id is not null on all pharmacy_order_prescriptions rows (enforced by source not_null test).
-- ongoing_prescription_id is the nullable supplementary reference and is not used for the medication lookup
join "reporting"."prescriptions" pr
    on pr.id = pop.prescription_id
join "reporting"."reference_data" m
    on m.id = pr.medication_id
join "reporting"."facilities" f
    on f.id = po.facility_id
    and f.is_sensitive = False


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
    and procedure_facility.is_sensitive = False
join "reporting"."locations" encounter_location
    on encounter_location.id = e.location_id
join "reporting"."facilities" encounter_facility
    on encounter_facility.id = encounter_location.facility_id
    and encounter_facility.is_sensitive = False
join "reporting"."departments" encounter_department
    on encounter_department.id = coalesce(pc.department_id, e.department_id)
left join "reporting"."patient_additional_data" pd on pd.patient_id = p.id
left join "reporting"."reference_data" nationality on nationality.id = pd.nationality_id
left join "reporting"."users" assistant_anaesthetist on assistant_anaesthetist.id = pc.assistant_anaesthetist_id
left join "reporting"."users" anaesthetist on anaesthetist.id = pc.anaesthetist_id
left join "reporting"."users" clinician on clinician.id = pc.clinician_id
where pc.encounter_history_record = 1


);
create or replace view "reporting"."ds__outpatient_appointments_audit" as (


-- Outpatient Appointments Audit Dataset
-- This dataset tracks changes/modifications to outpatient appointments
-- Each row represents a modification event (excludes initial creation)
--
-- Included changes:
--   - Status changed to 'Cancelled' (individual cancellations only)
--   - Changes to: start/end datetime, clinician, location group, appointment type, priority
--
-- Excluded changes:
--   - Initial appointment creation (change_sequence = 1)
--   - Status-only changes (unless changing to 'Cancelled')
--   - Appointments automatically cancelled when their schedule was cancelled
--     (i.e., bulk cancellations via "cancel this and all future appointments")
--
-- change_number: starts from 1 for the first modification, increments for subsequent changes
--
-- Note: schedule_id never changes on existing appointments in Tamanu.
-- When a schedule is modified, old appointments are cancelled and new ones are created.

with change_evaluation as (
    select
        cl.*,
        -- Determine if this change has meaningful field modifications
        case
            -- Status changed to Cancelled
            when cl.status = 'Cancelled' and cl.prev_status is distinct from 'Cancelled' then true
            -- Any non-status fields changed
            when (
                cl.prev_start_datetime is distinct from cl.start_datetime
                or cl.prev_end_datetime is distinct from cl.end_datetime
                or cl.prev_clinician_id is distinct from cl.clinician_id
                or cl.prev_location_group_id is distinct from cl.location_group_id
                or cl.prev_appointment_type_id is distinct from cl.appointment_type_id
                or cl.prev_is_high_priority is distinct from cl.is_high_priority
            ) then true
            else false
        end as is_meaningful_change
    from "reporting"."outpatient_appointments_change_logs" cl
    left join "public"."appointment_schedules" s on s.id = cl.schedule_id
    where
        -- Exclude appointments that were automatically cancelled when the schedule was cancelled
        -- (Keep appointments that were individually cancelled, not bulk-cancelled via schedule)
        not (
            cl.status = 'Cancelled'
            and s.cancelled_at_date is not null
            and cl.start_datetime::date > s.cancelled_at_date::date
        )
),

numbered_changes as (
    select
        ce.*,
        -- Assign change number: starts from 1 for first modification
        row_number() over (
            partition by ce.appointment_id
            order by ce.modified_datetime
        ) as change_number
    from change_evaluation ce
    where ce.is_meaningful_change = true
        and ce.change_sequence > 1  -- Exclude initial creation
)

select
    fc.change_id,
    fc.appointment_id,
    fc.change_number,
    -- Patient details
    p.id as patient_id,
    p.display_id,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    -- Current appointment details
    fc.start_datetime as appointment_start_datetime,
    fc.end_datetime as appointment_end_datetime,
    apt.name as appointment_type,
    fc.appointment_type_id,
    clinician.display_name as clinician,
    fc.clinician_id,
    lg.name as location_group,
    fc.location_group_id,
    case when fc.is_high_priority then 'Yes' else 'No' end as priority,
    fc.schedule_id,
    case
        when fc.schedule_id is not null then 'Yes'
        else 'No'
    end as is_repeating,
    -- Modification details
    creator.display_name as created_by,
    fc.created_by_user_id,
    modifier.display_name as modified_by,
    fc.modified_by_user_id,
    fc.modified_datetime,
    case when fc.status = 'Cancelled' then 'Yes' else 'No' end as is_cancelled,
    -- Previous appointment details (only shown if different from current)
    case
        when fc.prev_start_datetime is distinct from fc.start_datetime
        then fc.prev_start_datetime
    end as prev_start_datetime,
    case
        when fc.prev_end_datetime is distinct from fc.end_datetime
        then fc.prev_end_datetime
    end as prev_end_datetime,
    case
        when fc.prev_appointment_type_id is distinct from fc.appointment_type_id
        then prev_apt.name
    end as prev_appointment_type,
    case
        when fc.prev_appointment_type_id is distinct from fc.appointment_type_id
        then fc.prev_appointment_type_id
    end as prev_appointment_type_id,
    case
        when fc.prev_clinician_id is distinct from fc.clinician_id
        then prev_clinician.display_name
    end as prev_clinician,
    case
        when fc.prev_clinician_id is distinct from fc.clinician_id
        then fc.prev_clinician_id
    end as prev_clinician_id,
    case
        when fc.prev_location_group_id is distinct from fc.location_group_id
        then prev_lg.name
    end as prev_location_group,
    case
        when fc.prev_location_group_id is distinct from fc.location_group_id
        then fc.prev_location_group_id
    end as prev_location_group_id,
    case
        when fc.prev_is_high_priority is not null
            and fc.prev_is_high_priority is distinct from fc.is_high_priority
        then case when fc.prev_is_high_priority then 'Yes' else 'No' end
    end as prev_priority,
    -- Facility details for filtering
    f.id as facility_id,
    f.name as facility
from numbered_changes fc
join "reporting"."patients" p on p.id = fc.patient_id
left join "reporting"."users" clinician on clinician.id = fc.clinician_id
left join "reporting"."users" prev_clinician on prev_clinician.id = fc.prev_clinician_id
left join "reporting"."users" creator on creator.id = fc.created_by_user_id
left join "reporting"."users" modifier on modifier.id = fc.modified_by_user_id
join "reporting"."location_groups" lg on lg.id = fc.location_group_id
left join "reporting"."location_groups" prev_lg on prev_lg.id = fc.prev_location_group_id
left join "reporting"."reference_data" apt on apt.id = fc.appointment_type_id
left join "reporting"."reference_data" prev_apt on prev_apt.id = fc.prev_appointment_type_id
left join "public"."appointment_schedules" s on s.id = fc.schedule_id
-- Join to facility for filtering by sensitivity
join "reporting"."facilities" f on f.id = lg.facility_id
    and f.is_sensitive = False


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
    p.date_of_birth,
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
    e.encounter_type,
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
    and f.is_sensitive = False


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
    and f.is_sensitive = False
left join "reporting"."patient_additional_data" pd on pd.patient_id = p.id
left join "reporting"."reference_data" billing on billing.id = pd.patient_billing_type_id
left join "reporting"."reference_data" vil on vil.id = p.village_id
left join "reporting"."reference_data" bt on bt.id = a.booking_type_id


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
    and f.is_sensitive = False
left join "reporting"."patient_additional_data" pd on pd.patient_id = p.id
left join "reporting"."reference_data" billing on billing.id = pd.patient_billing_type_id
left join "reporting"."reference_data" vil on vil.id = p.village_id
left join "reporting"."reference_data" apt on apt.id = a.appointment_type_id
left join appointment_creators ac on ac.appointment_id = a.id
left join "reporting"."users" creator on creator.id = ac.created_by_user_id


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
join "reporting"."facilities" f on f.id = l.facility_id and f.is_sensitive = False
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
    and f.is_sensitive = False
left join "reporting"."location_groups" lg
    on lg.id = l.location_group_id
left join diets d
    on d.encounter_id = e.id
left join allergies a
    on a.patient_id = p.id
where e.end_datetime is null


);
create or replace view "reporting"."ds__user_access_audit" as (
with user_designations_agg as (
    -- BL-003: comma-separated, alphabetically sorted, deduplicated
    -- BL-005: label resolved from reference_data.name
    select
        ud.user_id,
        string_agg(distinct rd.name, ', ' order by rd.name) as designations
    -- BL-004: soft-deleted designation links filtered by base__user_designations
    from "reporting"."user_designations" ud
    left join "reporting"."reference_data" rd on rd.id = ud.designation_id
    group by ud.user_id
),

role_permissions_agg as (
    -- BL-006: verb:noun tokens, alphabetically sorted, deduplicated
    select
        p.role_id,
        string_agg(
            distinct concat(p.verb, ':', p.noun),
            ', '
            order by concat(p.verb, ':', p.noun)
        ) as permissions
    -- BL-007: soft-deleted permissions filtered by base__permissions
    from "reporting"."permissions" p
    group by p.role_id
)

-- BL-001: include only users with visibility_status = 'current'
-- BL-002: soft-deleted users excluded by base__users
select
    u.id as user_id,
    u.display_id as user_display_id,
    u.display_name as user_name,
    u.email as user_email,
    u.role as user_role_id,
    r.name as user_role,
    ud.designations as user_designations,
    rp.permissions as role_permissions,
    u.visibility_status
from "reporting"."users" u
left join "reporting"."roles" r on r.id = u.role
left join user_designations_agg ud on ud.user_id = u.id
-- BL-008: permissions are role-scoped. no user-level overrides
left join role_permissions_agg rp on rp.role_id = u.role
where u.visibility_status = 'current'
);
create or replace view "reporting"."vaccine_administrations_change_logs" as (
with filtered_changes as (
    select
        av.changelog_id,
        av.logged_at at time zone 'Australia/Sydney' as logged_at,
        av.updated_by_user_id,
        av.record_created_at at time zone 'Australia/Sydney' as record_created_at,
        av.record_updated_at at time zone 'Australia/Sydney' as record_updated_at,
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
    fc.logged_at,
    fc.record_created_at as created_at,
    fc.record_updated_at as updated_at,
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
create or replace view "reporting"."clinical__condition_occurrence" as (
-- clinical__condition_occurrence -- OMOP-lite CONDITION_OCCURRENCE domain. One row per
-- encounter diagnosis (BL-001). FK graph anchored on the encounter (BL-002); the ICD-10
-- code is retained as the source value and condition_concept_id is deferred to the future
-- vocab__ layer (BL-003). Sources only from bases/ (D10).
-- See specs/dbt-model/clinical__condition_occurrence.md for BL-001..BL-006.

with encounter_diagnoses as (
    select * from "reporting"."encounter_diagnoses"
),

encounters as (
    select * from "reporting"."encounters"
),

reference_data as (
    select * from "reporting"."reference_data"
)

select
    -- identity (BL-001)
    ed.id as condition_occurrence_id,

    -- person anchored on the encounter (BL-002)
    e.patient_id as person_id,

    -- diagnosis datetimes; encounter diagnoses are point-in-time, so no end (BL-004)
    ed.datetime::date as condition_start_date,
    ed.datetime as condition_start_datetime,
    null::date as condition_end_date,
    null::timestamp as condition_end_datetime,

    -- provenance: every row here is an EHR encounter diagnosis (BL-006)
    'encounter diagnosis' as condition_type_source_value,

    -- status + primary/secondary flag; certainty retained verbatim (BL-005)
    ed.certainty as condition_status_source_value,
    ed.is_primary,

    -- provider + visit FKs (BL-002)
    ed.diagnosed_by_id as provider_id,
    ed.encounter_id as visit_occurrence_id,

    -- diagnosis ICD-10 code + name; concept_id deferred to vocab__ (BL-003)
    rd.code as condition_source_value,
    rd.name as condition_source_name

from encounter_diagnoses ed
join encounters e on e.id = ed.encounter_id
left join reference_data rd on rd.id = ed.diagnosis_id
);
create or replace view "reporting"."clinical__visit_detail" as (
-- clinical__visit_detail -- OMOP-lite VISIT_DETAIL domain. One row per encounter segment
-- (BL-001): a contiguous department/location/encounter_type phase within a single
-- encounter. Segments walk the unified encounter_history timeline (BL-002); encounters
-- with no history at all get one synthesized whole-visit segment (BL-005). Per-segment
-- visit concept from map__omop_visit_type (BL-003, inner join -- see BL-003 for the
-- consequence of an unmapped encounter_type); segments chained via
-- preceding_visit_detail_id (BL-004). care_site_id is the segment's location_id (BL-006);
-- department carried as an attribute (BL-007). Sources only from bases/ (D10).
-- See specs/dbt-model/clinical__visit_detail.md for BL-001..BL-007.

with encounters as (
    select * from "reporting"."encounters"
),

encounter_history as (
    select * from "reporting"."encounter_history"
),

visit_map as (
    select * from "reporting"."map__omop_visit_type"
),

-- each encounter_history row is one segment start (BL-002). encounter_history is already
-- a single timeline carrying department, location, type and clinician per event, so no
-- separate department/location streams need merging
history_segments as (
    select
        -- encounter_history.id is uuid; cast to match encounters.id (varchar) for the
        -- union with synthesized_segments and the varchar visit_detail_id contract
        eh.id::varchar as visit_detail_id,
        eh.encounter_id as visit_occurrence_id,
        eh.datetime as visit_detail_start_datetime,
        eh.department_id,
        eh.location_id,
        eh.clinician_id as provider_id,
        eh.encounter_type as visit_detail_source_value
    from encounter_history eh
),

-- an encounter with no encounter_history rows gets one segment covering the whole visit,
-- taken from the encounter record itself, so every visit has at least one detail (BL-005)
synthesized_segments as (
    select
        e.id::varchar as visit_detail_id,
        e.id as visit_occurrence_id,
        e.start_datetime as visit_detail_start_datetime,
        e.department_id,
        e.location_id,
        e.clinician_id as provider_id,
        e.encounter_type as visit_detail_source_value
    from encounters e
    where not exists (
            select 1 from encounter_history eh
            where eh.encounter_id = e.id
        )
),

-- columns listed explicitly (by name from each branch) so reordering either CTE can't
-- silently mis-map the union
segments as (
    select
        visit_detail_id,
        visit_occurrence_id,
        visit_detail_start_datetime,
        department_id,
        location_id,
        provider_id,
        visit_detail_source_value
    from history_segments
    union all
    select
        visit_detail_id,
        visit_occurrence_id,
        visit_detail_start_datetime,
        department_id,
        location_id,
        provider_id,
        visit_detail_source_value
    from synthesized_segments
),

-- close each segment at the next segment's start, falling back to the encounter end for
-- the final (open) segment; chain segments within an encounter (BL-002, BL-004)
bounded as (
    select
        s.visit_detail_id,
        s.visit_occurrence_id,
        e.patient_id as person_id,
        s.visit_detail_start_datetime,
        coalesce(
            lead(s.visit_detail_start_datetime) over w,
            e.end_datetime
        ) as visit_detail_end_datetime,
        s.department_id,
        s.location_id,
        s.provider_id,
        s.visit_detail_source_value,
        lag(s.visit_detail_id) over w as preceding_visit_detail_id
    from segments s
    join encounters e on e.id = s.visit_occurrence_id
    window w as (
        partition by s.visit_occurrence_id
        order by s.visit_detail_start_datetime, s.visit_detail_id
    )
)

select
    b.visit_detail_id,
    b.visit_occurrence_id,
    b.person_id,

    -- per-segment visit concept (BL-003)
    vm.concept_id as visit_detail_concept_id,

    -- date + datetime pair, mirroring clinical__visit_occurrence (BL-002)
    b.visit_detail_start_datetime::date as visit_detail_start_date,
    b.visit_detail_start_datetime,
    b.visit_detail_end_datetime::date as visit_detail_end_date,
    b.visit_detail_end_datetime,

    -- care site is the segment's location. FK to ref__care_site (location-type rows) (BL-006)
    b.location_id as care_site_id,

    -- department (organizational unit) carried as an attribute. FKs to ref__care_site
    -- (department-type rows) (BL-007)
    b.department_id,

    b.provider_id,

    -- source value retained alongside concept (D1)
    b.visit_detail_source_value,

    -- intra-visit ordering (BL-004)
    b.preceding_visit_detail_id

from bounded b
join visit_map vm on vm.local_code = b.visit_detail_source_value
);
create or replace view "reporting"."clinical__visit_occurrence" as (
-- clinical__visit_occurrence -- OMOP-lite VISIT_OCCURRENCE domain. One row per encounter,
-- provided its encounter_type is covered by map__omop_visit_type (BL-001, BL-002 -- inner
-- join, see BL-002 for the consequence of an unmapped encounter_type). Visit-concept shadow
-- column sits alongside local encounter_type source value; native UUID PK (D1 OMOP-lite).
-- Sources only from bases/ (D10).
-- See specs/dbt-model/clinical__visit_occurrence.md for BL-001..BL-007.

with encounters as (
    select * from "reporting"."encounters"
),

visit_map as (
    select * from "reporting"."map__omop_visit_type"
),

-- collect the distinct encounter types seen in history for each encounter;
-- used to detect admission encounters that passed through an ER phase (BL-002)
encounter_history_types as (
    select distinct
        encounter_id,
        encounter_type
    from "reporting"."encounter_history"
)

select
    -- identity (BL-001)
    e.id as visit_occurrence_id,

    -- patient FK (BL-001)
    e.patient_id as person_id,

    -- visit type: concept shadow + retained source value (BL-002)
    -- admission encounters that had a prior emergency/triage/observation phase
    -- map to 262 (Emergency Room and Inpatient Visit); all others use the map
    case
        when e.encounter_type = 'admission'
            and exists (
                select 1 from encounter_history_types eht
                where eht.encounter_id = e.id
                    and eht.encounter_type in ('emergency', 'triage', 'observation')
            )
            then 262
        else vm.concept_id
    end as visit_concept_id,

    -- visit datetimes (BL-004)
    e.start_datetime::date as visit_start_date,
    e.start_datetime as visit_start_datetime,
    e.end_datetime::date as visit_end_date,
    e.end_datetime as visit_end_datetime,

    -- visit type provenance: constant EHR administration record (BL-003)
    32817 as visit_type_concept_id,

    -- provider (BL-005)
    e.clinician_id as provider_id,

    -- care site is the encounter's location. FK to ref__care_site (location-type rows) (BL-006)
    e.location_id as care_site_id,

    -- source value retained alongside concept (BL-007)
    e.encounter_type as visit_source_value

from encounters e
join visit_map vm on vm.local_code = e.encounter_type
);
create or replace view "reporting"."clinical__drug_exposure" as (
-- clinical__drug_exposure -- OMOP-lite DRUG_EXPOSURE domain. One row per drug exposure,
-- unioning three standard sources: medication prescriptions (BL-006), vaccine
-- administrations with status = 'GIVEN' (BL-007), and pharmacy dispenses (BL-008). Drug
-- identity retained as source value; FK graph wired from the encounter (BL-002);
-- *_concept_id (RxNorm/CVX) deferred to the future vocab__ layer (BL-003). Sources only
-- from bases/ (D10). Deployment-specific drug sources are added by per-deployment override
-- (see spec). See spec for BL-001..BL-008.

with prescriptions as (
    select * from "reporting"."prescriptions"
),

encounter_prescriptions as (
    select * from "reporting"."encounter_prescriptions"
),

reference_data as (
    select * from "reporting"."reference_data"
),

vaccine_administrations as (
    select * from "reporting"."vaccine_administrations"
),

vaccine_schedules as (
    select * from "reporting"."vaccine_schedules"
),

medication_dispenses as (
    select * from "reporting"."medication_dispenses"
),

pharmacy_order_prescriptions as (
    select * from "reporting"."pharmacy_order_prescriptions"
),

pharmacy_orders as (
    select * from "reporting"."pharmacy_orders"
),

encounters as (
    select * from "reporting"."encounters"
),

-- prescription branch: every prescription, joined to its encounter and drug (BL-006)
prescription_exposures as (
    select
        -- BL-006: PK is encounter_prescriptions.id, NOT prescriptions.id -- only that
        -- table's own id is unique, so a prescription linked to >1 encounter yields
        -- distinct exposure rows rather than colliding on the primary key
        ep.id::varchar as drug_exposure_id,
        e.patient_id::varchar as person_id,
        coalesce(p.start_datetime, p.datetime)::date as drug_exposure_start_date,
        coalesce(p.start_datetime, p.datetime) as drug_exposure_start_datetime,
        p.end_datetime as drug_exposure_end_datetime,
        'prescription' as drug_exposure_type_source_value,  -- provenance / union discriminator (BL-005)
        p.quantity::numeric as quantity,
        p.repeats as refills,
        p.route as route_source_value,
        -- exposure still occurred even when discontinued; keep the row, record why it stopped (BL-006)
        case when p.is_discontinued then p.discontinuing_reason end as stop_reason,
        p.prescriber_id::varchar as provider_id,
        ep.encounter_id::varchar as visit_occurrence_id,
        rd.code as drug_source_value,
        rd.name as drug_source_name
    from prescriptions p
    join encounter_prescriptions ep on ep.prescription_id = p.id
    join encounters e on e.id = ep.encounter_id
    left join reference_data rd on rd.id = p.medication_id
),

-- vaccination branch: GIVEN administrations only (BL-007). RECORDED_IN_ERROR (a deleted
-- GIVEN) and HISTORICAL (a hidden shadow of a separate GIVEN row) are excluded so a real
-- exposure isn't double-counted; NOT_GIVEN belongs in clinical__observation, not here
vaccination_exposures as (
    select
        av.id::varchar as drug_exposure_id,
        e.patient_id::varchar as person_id,
        av.datetime::date as drug_exposure_start_date,
        av.datetime as drug_exposure_start_datetime,
        av.datetime as drug_exposure_end_datetime,  -- point event: end equals start (BL-004)
        'vaccination' as drug_exposure_type_source_value,
        null::numeric as quantity,
        null::integer as refills,
        av.injection_site as route_source_value,
        null::varchar as stop_reason,
        -- recorded_by_id (a real user FK) preferred; given_by is free text (may name a
        -- non-Tamanu-user) and is only a fallback when no recording user was captured.
        -- provider_id's FK test is scoped off vaccination rows for this reason (BL-002)
        coalesce(av.recorded_by_id, av.given_by)::varchar as provider_id,
        av.encounter_id::varchar as visit_occurrence_id,
        rd.code as drug_source_value,
        -- prefer the canonical reference_data name (scheduled doses); fall back to the
        -- denormalised vaccine_name so ad hoc/catch-up doses still name the vaccine (BL-007)
        coalesce(rd.name, av.vaccine_name) as drug_source_name
    from vaccine_administrations av
    join encounters e on e.id = av.encounter_id
    left join vaccine_schedules vs on vs.id = av.scheduled_vaccine_id
    left join reference_data rd on rd.id = vs.vaccine_id
    where av.status = 'GIVEN'
),

-- dispense branch: physical hand-over of stock; drug identity comes from the originating
-- prescription, since a dispense carries no medication_id of its own (BL-008)
dispense_exposures as (
    select
        md.id::varchar as drug_exposure_id,
        e.patient_id::varchar as person_id,
        md.dispensed_at::date as drug_exposure_start_date,
        md.dispensed_at as drug_exposure_start_datetime,
        md.dispensed_at as drug_exposure_end_datetime,  -- point event: end equals start (BL-004)
        'dispense' as drug_exposure_type_source_value,
        md.quantity::numeric as quantity,
        null::integer as refills,
        p.route as route_source_value,
        null::varchar as stop_reason,
        md.dispensed_by_user_id::varchar as provider_id,
        po.encounter_id::varchar as visit_occurrence_id,
        rd.code as drug_source_value,
        rd.name as drug_source_name
    from medication_dispenses md
    join pharmacy_order_prescriptions pop on pop.id = md.pharmacy_order_prescription_id
    join pharmacy_orders po on po.id = pop.pharmacy_order_id
    join encounters e on e.id = po.encounter_id
    join prescriptions p on p.id = pop.prescription_id
    left join reference_data rd on rd.id = p.medication_id
)

-- columns listed explicitly per branch so reordering one branch can't silently mis-map
select
    drug_exposure_id,
    person_id,
    drug_exposure_start_date,
    drug_exposure_start_datetime,
    drug_exposure_end_datetime,
    drug_exposure_type_source_value,
    quantity,
    refills,
    route_source_value,
    stop_reason,
    provider_id,
    visit_occurrence_id,
    drug_source_value,
    drug_source_name
from prescription_exposures

union all

select
    drug_exposure_id,
    person_id,
    drug_exposure_start_date,
    drug_exposure_start_datetime,
    drug_exposure_end_datetime,
    drug_exposure_type_source_value,
    quantity,
    refills,
    route_source_value,
    stop_reason,
    provider_id,
    visit_occurrence_id,
    drug_source_value,
    drug_source_name
from vaccination_exposures

union all

select
    drug_exposure_id,
    person_id,
    drug_exposure_start_date,
    drug_exposure_start_datetime,
    drug_exposure_end_datetime,
    drug_exposure_type_source_value,
    quantity,
    refills,
    route_source_value,
    stop_reason,
    provider_id,
    visit_occurrence_id,
    drug_source_value,
    drug_source_name
from dispense_exposures
);
create or replace view "reporting"."clinical__person" as (
-- clinical__person -- OMOP-lite PERSON domain. One row per patient (BL-001).
-- Concept-ID shadow columns sit alongside local source values; native UUID PK
-- (D1 OMOP-lite). Sources only from bases/ (D10).
-- See specs/dbt-model/clinical__person.md for BL-001..BL-007.

with patients as (
    select * from "reporting"."patients"
),

additional as (
    select
        patient_id,
        ethnicity_id
    from "reporting"."patient_additional_data"
),

birth as (
    select
        patient_id,
        birth_time
    from "reporting"."patient_birth_data"
),

sex_map as (
    select * from "reporting"."map__omop_sex"
)

select
    -- identity (BL-001)
    p.id as person_id,
    -- source business identifier (display_id / MRN); a direct identifier that
    -- bases/ drops on analytics targets, so NULL on the replica (BL-006)
    p.display_id as person_source_value,

    -- gender: concept shadow + retained source value (BL-002)
    sm.concept_id as gender_concept_id,
    p.sex as gender_source_value,

    -- birth (BL-003)
    extract(year from p.date_of_birth)::int as year_of_birth,
    extract(month from p.date_of_birth)::int as month_of_birth,
    extract(day from p.date_of_birth)::int as day_of_birth,
    case
        when b.birth_time is not null
            then (p.date_of_birth + b.birth_time)::timestamp
    end as birth_datetime,

    -- ethnicity source value; concept shadow is deployment-specific (BL-004)
    a.ethnicity_id as ethnicity_source_value,

    -- location: FK to ref__location (patient's village) (BL-007)
    p.village_id as location_id
from patients p
-- enrichment joins are all left joins so a missing record yields NULL rather than
-- dropping the patient; only the patient record itself is required (BL-005)
left join additional a on a.patient_id = p.id
left join birth b on b.patient_id = p.id
left join sex_map sm on sm.local_code = lower(p.sex)
);
create or replace view "reporting"."int__admission_history_department" as (
with admission_department_log as (
    select
        eh.id,
        eh.encounter_id,
        eh.datetime as start_datetime,
        eh.department_id,
        case
            when eh.change_type is null or 'encounter_type' = any(eh.change_type) then 'admission'
            else 'transfer-in'
        end as type
    from "reporting"."encounter_history" eh
    where (eh.change_type isnull or eh.change_type && array['department', 'encounter_type'])
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
create or replace view "reporting"."int__triage_observations" as (
-- int__triage_observations -- unpivots the wide triages row into one row per recorded
-- triage element (tall shape), for the triage branch of clinical__observation.
-- Elements: the acuity score, and the chief/secondary complaints (resolved to their
-- reference_data names, type = 'triageReason'). Blank/unrecorded elements are dropped.
-- Values are kept as text here; the numeric cast happens in clinical__observation.

with triages as (
    select * from "reporting"."triages"
),

reference_data as (
    select * from "reporting"."reference_data"
),

triage_elements as (
    select
        t.id as triage_id,
        t.encounter_id,
        t.clinician_id,
        -- triage_time is application-required on the triage form, so it's the canonical
        -- "when"; a null here is a data-quality issue AC-006 should surface, not paper over
        t.triage_datetime as observation_datetime,
        t.score,
        cc.name as chief_complaint,
        sc.name as secondary_complaint
    from triages t
    left join reference_data cc on cc.id = t.chief_complaint_id
    left join reference_data sc on sc.id = t.secondary_complaint_id
)

-- one row per recorded element; blanks are dropped
select
    te.triage_id,
    te.encounter_id,
    te.clinician_id,
    te.observation_datetime,
    m.observation_source_value,
    m.observation_source_name,
    m.value_source_value
from triage_elements te
cross join lateral (values
    ('triage_score',        'Triage score',        te.score),
    ('chief_complaint',     'Chief complaint',     te.chief_complaint),
    ('secondary_complaint', 'Secondary complaint', te.secondary_complaint)
) as m (observation_source_value, observation_source_name, value_source_value)
where m.value_source_value is not null and trim(m.value_source_value) != ''
);
create or replace view "reporting"."int__admission_history_location" as (
with admission_location_log as (
    select
        eh.id,
        eh.encounter_id,
        eh.datetime as start_datetime,
        eh.location_id,
        case
            when eh.change_type is null or 'encounter_type' = any(eh.change_type) then 'admission'
            else 'transfer-in'
        end as type
    from "reporting"."encounter_history" eh
    where (eh.change_type isnull or eh.change_type && array['location', 'encounter_type'])
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
create or replace view "reporting"."int__patient_birth_measurements" as (
-- int__patient_birth_measurements -- unpivots the wide patient_birth_data into one row per
-- recorded birth measurement (tall shape), for the birth-data branch of clinical__measurement.
-- Inner-joins patients (which filters deleted/test/merged patients and supplies the birth
-- date), so every row is a valid patient; birth measurements are patient-level (no encounter).
-- Values are kept as text here; the numeric cast happens in clinical__measurement.

with patient_birth_data as (
    select * from "reporting"."patient_birth_data"
),

patients as (
    select * from "reporting"."patients"
),

birth as (
    select
        pbd.patient_id,
        pbd.birth_weight,
        pbd.birth_length,
        pbd.apgar_score_one_minute,
        pbd.apgar_score_five_minutes,
        pbd.apgar_score_ten_minutes,
        pbd.gestational_age_estimate,
        -- a birth measurement is taken at birth; fall back to the registration date
        coalesce(
            (p.date_of_birth + pbd.birth_time)::timestamp,
            p.date_of_birth::timestamp,
            pbd.registration_date::timestamp
        ) as measurement_datetime
    from patient_birth_data pbd
    join patients p on p.id = pbd.patient_id
)

-- one row per recorded measure; blanks are dropped
select
    b.patient_id,
    m.measurement_source_value,
    m.measurement_source_name,
    m.value_source_value,
    b.measurement_datetime
from birth b
cross join lateral (values
    ('birth_weight',             'Birth weight',             b.birth_weight::varchar),
    ('birth_length',             'Birth length',             b.birth_length::varchar),
    ('apgar_score_one_minute',   'APGAR score (1 minute)',   b.apgar_score_one_minute::varchar),
    ('apgar_score_five_minutes', 'APGAR score (5 minutes)',  b.apgar_score_five_minutes::varchar),
    ('apgar_score_ten_minutes',  'APGAR score (10 minutes)', b.apgar_score_ten_minutes::varchar),
    ('gestational_age_estimate', 'Gestational age estimate', b.gestational_age_estimate::varchar)
) as m (measurement_source_value, measurement_source_name, value_source_value)
where m.value_source_value is not null and trim(m.value_source_value) != ''
);
create or replace view "reporting"."metric__encounter_diagnosis" as (
-- metric__encounter_diagnosis -- D5 metric view for the morbidity indicator registered in
-- documentations/metrics/*.yml: encounter_diagnosis.
--
-- Per-diagnosis (subject) grain: one row per recorded diagnosis, value_numeric 1, so a
-- consumer aggregates at whatever grain it needs -- any subset of the disaggregations, and
-- any time grain from day upwards (BL-002).
--
-- The registry carries the definition; this model is its implementation (BL-001).
-- See specs/dbt-model/metric__encounter_diagnosis.md for BL-001..BL-009.

with condition_occurrence as (
    select * from "reporting"."clinical__condition_occurrence"
),

visit_occurrence as (
    select * from "reporting"."clinical__visit_occurrence"
),

person as (
    select * from "reporting"."clinical__person"
),

locations as (
    select * from "reporting"."locations"
),

-- BL-003: the encounter-diagnosis branch of clinical__condition_occurrence. Certainty
-- 'disproven' and 'error' are already excluded upstream, by bases/encounter_diagnoses, so
-- this model inherits that rule rather than restating it -- a restatement here would drift
-- the day the base changes.
--
-- The program-registry branch is excluded: a condition tracked alongside an enrolment has no
-- encounter (clinical__condition_occurrence BL-008), so it carries neither a facility nor an
-- encounter type, and counting it here would mix comorbidity tracking into a morbidity count.
diagnoses as (
    select
        cco.condition_occurrence_id,
        cco.condition_start_date,
        cco.is_primary,
        loc.facility_id,
        -- BL-005: the encounter's own type -- lets a consumer scope morbidity to emergency,
        -- outpatient or inpatient activity without a separate metric per setting
        vo.visit_source_value as encounter_type,
        pr.gender_source_value as sex,
        -- BL-007: the diagnosis as recorded, coalesced so the column is never NULL. Tupaia
        -- exposes these as array filters, and an array filter drops a NULL row -- an
        -- undiagnosed-but-recorded row would silently disappear rather than show as unknown.
        coalesce(cco.condition_source_value, 'Not recorded') as diagnosis_code,
        coalesce(
            cco.condition_source_name, cco.condition_source_value, 'Not recorded'
        ) as diagnosis,
        coalesce(cco.condition_status_source_value, 'Not recorded') as diagnosis_certainty,
        -- age in whole years at the diagnosis; the NULL rule lives in the macro
        
case
    when pr.year_of_birth is not null then
        extract(year from age(
            cco.condition_start_date,
            make_date(
                pr.year_of_birth,
                pr.month_of_birth,
                pr.day_of_birth
            )
        ))::int
end
 as age_years
    from condition_occurrence cco
    -- inner join: this is what excludes the registry branch, whose visit_occurrence_id is
    -- NULL. It resolves for every encounter diagnosis whose encounter_type is covered by
    -- map__omop_visit_type, which clinical__visit_occurrence inner-joins -- an uncovered
    -- type would drop the diagnosis rather than surface it (OQ-002)
    join visit_occurrence vo
        on vo.visit_occurrence_id = cco.visit_occurrence_id
    -- inner join: a diagnosis whose patient bases/patients excludes (soft-deleted or merged
    -- away) is excluded from the metric entirely, not counted with blank demographics
    join person pr
        on pr.person_id = cco.person_id
    -- BL-005: inner join -- encounters always carry a location in practice, so a failure to
    -- match here (the encounter's location has since been soft-deleted) is a genuine
    -- anomaly, excluded from the metric rather than surfacing with a NULL facility_id
    join locations loc
        on loc.id = vo.care_site_id
    where cco.condition_type_source_value = 'encounter diagnosis'
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' --
-- Tamanu records a diagnosis against a date, and a diagnosis is point-in-time, so there is
-- no period to close (BL-002).
--
-- BL-006: the diagnosis code and name are emitted raw and ungrouped. Classifying either one
-- -- an ICD-10 chapter, a block, a national grouping -- is a presentation choice a
-- deployment may set differently, so it happens at the deployment/data-table layer, the same
-- division as age_years (BL-008). macros/diagnosis__icd10_chapter.sql stays available for a
-- deployment to apply over diagnosis_code there.
select
    'encounter_diagnosis'::text as metric_id,
    null::text as variant_id,
    condition_occurrence_id::varchar as subject_id,
    condition_start_date as period_start,
    -- BL-002: a diagnosis is point-in-time, and neither source records a resolution date
    null::date as period_end,
    'day'::text as period_granularity,
    -- BL-004: one diagnosis per row, so the count contribution is always 1. Additive, so a
    -- data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    encounter_type,
    sex,
    diagnosis_code,
    diagnosis,
    diagnosis_certainty,
    is_primary,
    -- BL-008: age in whole years at the diagnosis. Unbanded -- an age classification is a
    -- presentation choice a deployment may set differently, so the consumer's data table
    -- bands it.
    age_years
from diagnoses
);
create or replace view "reporting"."metric__outpatient_visit" as (
-- metric__outpatient_visit -- D5 metric view for the outpatient visit indicator registered in
-- documentations/metrics/*.yml: opd_visit.
--
-- Per-visit (subject) grain: one row per outpatient visit, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs -- any subset of the disaggregations, and any time
-- grain from day upwards (BL-002).
--
-- The registry carries the definition; this model is its implementation (BL-001).

with visit_detail as (
    select * from "reporting"."clinical__visit_detail"
),

visit_occurrence as (
    select * from "reporting"."clinical__visit_occurrence"
),

person as (
    select * from "reporting"."clinical__person"
),

locations as (
    select * from "reporting"."locations"
),

-- BL-003: an outpatient visit is the first history segment of an encounter whose OMOP
-- visit concept is 9202/Outpatient Visit -- covering clinic, vaccination, and imaging.
-- Facility, location and demographics are resolved off that same segment; the encounter
-- end comes from the visit occurrence (BL-002).
outpatient_visits as (
    select
        vd.visit_occurrence_id,
        vd.visit_detail_start_date,
        vo.visit_end_date,
        loc.facility_id,
        -- BL-006: the location itself, one level finer than facility -- lets a consumer
        -- join to bases/location_groups (or similar) for area/clinic detail later, without
        -- this model resolving that join itself
        loc.id as location_id,
        pr.gender_source_value as sex,
        -- age in whole years at the visit; null year_of_birth -> null. month_of_birth/
        -- day_of_birth are extracted from the same date_of_birth column in
        -- clinical__person, so they're populated whenever year_of_birth is -- make_date
        -- below never errors on a partial date.
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    vd.visit_detail_start_date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years
    from visit_detail vd
    -- inner join: a visit_detail row cannot exist without its parent encounter, so this
    -- always resolves
    join visit_occurrence vo
        on vo.visit_occurrence_id = vd.visit_occurrence_id
    -- inner join: a visit whose patient bases/patients excludes (soft-deleted or merged
    -- away) is excluded from the metric entirely, not counted with blank demographics
    join person pr
        on pr.person_id = vd.person_id
    -- inner join: encounters always carry a location in practice, so a failure to match
    -- here (the segment's location has since been soft-deleted) is a genuine anomaly --
    -- excluded from the metric rather than surfacing with a NULL facility_id
    join locations loc
        on loc.id = vd.care_site_id
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_concept_id = 9202 -- OMOP 'Outpatient Visit'
)

-- D5 wide format: value_boolean is unused by this metric. period_granularity is 'day' --
-- Tamanu tracks visit and encounter end dates only, no timestamps, for outpatient
-- encounters (BL-002).
--
-- BL-007: facility_id and location_id are emitted as Tamanu ids, untranslated. Translating
-- them to a consumer's own identifiers is a consumer-layer concern and is done there (for
-- Tupaia, in the data table).
select
    'opd_visit'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    visit_detail_start_date as period_start,
    -- BL-002: NULL while the encounter is open
    visit_end_date as period_end,
    'day'::text as period_granularity,
    -- BL-003: one visit per row, so the count contribution is always 1. Additive, so
    -- a data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    location_id,
    sex,
    -- BL-004: age in whole years at the visit. Unbanded -- an age classification is a
    -- presentation choice a deployment may set differently, so the consumer's data table
    -- bands it.
    age_years
from outpatient_visits
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
    and f.is_sensitive = False
left join "reporting"."vaccine_schedules" sv on sv.id = av.scheduled_vaccine_id
left join "reporting"."users" u on u.id = av.recorded_by_id
left join "reporting"."reference_data" rd_vil on rd_vil.id = p.village_id
left join "reporting"."reference_data" rd_reason on rd_reason.id = av.not_given_reason_id
left join administered_circumstances ac on ac.id = av.id


);
create or replace view "reporting"."ds__emergency_triage" as (
-- BL-001: one row per triage record, which is one emergency department presentation
-- BL-015: the sensitive variant differs only in which emergency dataset it reads
with presentations as (
    select * from "reporting"."ds__encounters_emergency"
),


-- BL-006: diagnoses recorded against the presentation's encounter. bases/encounter_diagnoses
-- already drops disproven and recorded-in-error certainties
encounter_diagnoses_agg as (
    select
        ed.encounter_id,
        string_agg(distinct rd.name, ', ') as diagnoses
    from "reporting"."encounter_diagnoses" ed
    join presentations p on p.encounter_id = ed.encounter_id
    join "reporting"."reference_data" rd on rd.id = ed.diagnosis_id
    group by ed.encounter_id
),

-- BL-007: medications prescribed during the presentation's encounter
encounter_medications_agg as (
    select
        ep.encounter_id,
        string_agg(distinct med.name, ', ') as medications
    from "reporting"."encounter_prescriptions" ep
    join presentations p on p.encounter_id = ep.encounter_id
    join "reporting"."prescriptions" pr on pr.id = ep.prescription_id
    join "reporting"."reference_data" med on med.id = pr.medication_id
    group by ep.encounter_id
),

presentation_details as (
    select
        p.triage_id,
        p.encounter_id,
        p.patient_id,
        p.display_id,
        p.first_name,
        p.last_name,
        p.sex,
        p.village_id,
        p.village,
        p.date_of_birth,
        -- BL-002: age as at the time of triage, not today
        date_part('year', age(p.triage_datetime, p.date_of_birth))::integer as age,
        p.facility_id,
        p.arrival_datetime,
        p.arrival_mode,
        p.triage_datetime,
        p.score,
        -- BL-003: the triage score is presented using Tamanu's category wording
        'Category ' || p.score as triage_category,
        p.chief_complaint,
        p.secondary_complaint,
        p.clinician_id,
        p.clinician,
        dx.diagnoses,
        rx.medications,
        -- BL-004: active care starts when the triage is closed
        p.closed_datetime as active_care_datetime,
        e.encounter_type,
        -- BL-009: OMOP visit concept 262 is 'Emergency Room and Inpatient Visit', which
        -- clinical__visit_occurrence assigns to an admission that passed through an
        -- emergency, triage or observation phase
        vo.visit_concept_id = 262 as is_admitted_from_ed,
        e.end_datetime as discharge_datetime,
        dis.disposition_id as discharge_disposition_id,
        disposition.name as discharge_disposition
    from presentations p
    join "reporting"."encounters" e on e.id = p.encounter_id
    left join "reporting"."clinical__visit_occurrence" vo on vo.visit_occurrence_id = p.encounter_id
    left join encounter_diagnoses_agg dx on dx.encounter_id = p.encounter_id
    left join encounter_medications_agg rx on rx.encounter_id = p.encounter_id
    left join "reporting"."discharges" dis on dis.encounter_id = p.encounter_id
    left join "reporting"."reference_data" disposition on disposition.id = dis.disposition_id
),

timings as (
    select
        pd.*,
        -- BL-005: waiting time is triage to the start of active care
        -- BL-013: a time recorded before the triage is unusable, so the duration is left empty
        case
            when pd.active_care_datetime < pd.triage_datetime then null
            else extract(epoch from (pd.active_care_datetime - pd.triage_datetime))::bigint
        end as waiting_time_seconds,
        -- BL-010: total length of stay is triage to discharge
        -- BL-013: a time recorded before the triage is unusable, so the duration is left empty
        case
            when pd.discharge_datetime < pd.triage_datetime then null
            else extract(epoch from (pd.discharge_datetime - pd.triage_datetime))::bigint
        end as length_of_stay_seconds,
        -- BL-008: target waiting time by triage category, blank where the map has no entry
        case pd.score
    when '1' then 2
    when '2' then 10
    when '3' then 30
    when '4' then 60
    when '5' then 120
end as target_wait_minutes,
        -- BL-009: admitted or discharged only. A presentation that ended in death is not a
        -- third outcome -- discharge_disposition carries that, and the two signals Tamanu
        -- offers for it (the disposition, and patients.date_of_death falling inside the
        -- encounter) do not agree well enough to derive an outcome from
        case
            when pd.is_admitted_from_ed then 'Admitted'
            when pd.discharge_datetime is not null then 'Discharged'
        end as ed_outcome
    from presentation_details pd
)

select
    t.triage_id,
    t.encounter_id,
    t.patient_id,
    t.display_id,
    t.first_name,
    t.last_name,
    t.sex,
    t.village_id,
    t.village,
    t.date_of_birth,
    t.age,
    t.facility_id,
    t.arrival_datetime,
    t.arrival_mode,
    t.triage_datetime,
    t.score,
    t.triage_category,
    t.chief_complaint,
    t.secondary_complaint,
    t.clinician_id,
    t.clinician,
    t.diagnoses,
    t.medications,
    t.active_care_datetime,
    t.waiting_time_seconds,
    t.target_wait_minutes,
    t.encounter_type,
    t.is_admitted_from_ed,
    t.ed_outcome,
    t.discharge_disposition_id,
    t.discharge_disposition,
    t.discharge_datetime,
    t.length_of_stay_seconds,
    -- BL-008: no verdict until the patient has been seen and the category has a target
    case
        when t.waiting_time_seconds is null or t.target_wait_minutes is null then null
        when t.waiting_time_seconds <= t.target_wait_minutes * 60 then 'Yes'
        else 'No'
    end as target_time_met
from timings t


);
create or replace view "reporting"."clinical__measurement" as (
-- clinical__measurement -- OMOP-lite MEASUREMENT domain. One row per clinical measurement,
-- unioning three standard sources: vitals via the Tamanu Vitals survey (BL-006), completed
-- lab-test results (BL-007), and birth anthropometry unpivoted from patient_birth_data
-- (BL-008, via int__patient_birth_measurements). Numeric results populate value_as_number;
-- categorical results keep value_source_value. FK graph wired from the encounter where one
-- exists (BL-002); *_concept_id (LOINC) deferred to the future vocab__ layer (BL-003).
-- Sources only from bases/ + intermediate (D10). Deployment-specific measurements are added
-- by per-deployment override (see spec). See spec for BL-001..BL-008.

with  __dbt__cte__int__patient_birth_measurements as (
-- int__patient_birth_measurements -- unpivots the wide patient_birth_data into one row per
-- recorded birth measurement (tall shape), for the birth-data branch of clinical__measurement.
-- Inner-joins patients (which filters deleted/test/merged patients and supplies the birth
-- date), so every row is a valid patient; birth measurements are patient-level (no encounter).
-- Values are kept as text here; the numeric cast happens in clinical__measurement.

with patient_birth_data as (
    select * from "reporting"."patient_birth_data"
),

patients as (
    select * from "reporting"."patients"
),

birth as (
    select
        pbd.patient_id,
        pbd.birth_weight,
        pbd.birth_length,
        pbd.apgar_score_one_minute,
        pbd.apgar_score_five_minutes,
        pbd.apgar_score_ten_minutes,
        pbd.gestational_age_estimate,
        -- a birth measurement is taken at birth; fall back to the registration date
        coalesce(
            (p.date_of_birth + pbd.birth_time)::timestamp,
            p.date_of_birth::timestamp,
            pbd.registration_date::timestamp
        ) as measurement_datetime
    from patient_birth_data pbd
    join patients p on p.id = pbd.patient_id
)

-- one row per recorded measure; blanks are dropped
select
    b.patient_id,
    m.measurement_source_value,
    m.measurement_source_name,
    m.value_source_value,
    b.measurement_datetime
from birth b
cross join lateral (values
    ('birth_weight',             'Birth weight',             b.birth_weight::varchar),
    ('birth_length',             'Birth length',             b.birth_length::varchar),
    ('apgar_score_one_minute',   'APGAR score (1 minute)',   b.apgar_score_one_minute::varchar),
    ('apgar_score_five_minutes', 'APGAR score (5 minutes)',  b.apgar_score_five_minutes::varchar),
    ('apgar_score_ten_minutes',  'APGAR score (10 minutes)', b.apgar_score_ten_minutes::varchar),
    ('gestational_age_estimate', 'Gestational age estimate', b.gestational_age_estimate::varchar)
) as m (measurement_source_value, measurement_source_name, value_source_value)
where m.value_source_value is not null and trim(m.value_source_value) != ''
), survey_response_answers as (
    select * from "reporting"."survey_response_answers"
),

survey_responses as (
    select * from "reporting"."survey_responses"
),

surveys as (
    select * from "reporting"."surveys"
),

program_data_elements as (
    select * from "reporting"."program_data_elements"
),

encounters as (
    select * from "reporting"."encounters"
),

lab_tests as (
    select * from "reporting"."lab_tests"
),

lab_requests as (
    select * from "reporting"."lab_requests"
),

lab_test_types as (
    select * from "reporting"."lab_test_types"
),

patient_birth_measurements as (
    select * from __dbt__cte__int__patient_birth_measurements
),

-- every recorded answer to the core Vitals survey; numeric and categorical alike (BL-006)
vitals_answers as (
    select
        sra.id,
        trim(sra.body) as body,
        sra.data_element_id,
        sr.encounter_id,
        sr.start_datetime,
        sr.submitted_by_id
    from survey_response_answers sra
    join survey_responses sr on sr.id = sra.response_id
    join surveys s on s.id = sr.survey_id and s.survey_type = 'vitals'
    where sra.body is not null and trim(sra.body) != ''
),

-- vitals branch (BL-006). ids cast to varchar so the union with labs is type-safe
vitals_measurements as (
    select
        va.id::varchar as measurement_id,
        e.patient_id::varchar as person_id,
        va.start_datetime::date as measurement_date,
        va.start_datetime as measurement_datetime,
        'vitals survey' as measurement_type_source_value,  -- provenance / union discriminator (BL-005)
        case when va.body ~ '^-?[0-9]+(\.[0-9]+)?$' then va.body::numeric end as value_as_number,
        va.body as value_source_value,
        null::varchar as unit_source_value,
        va.submitted_by_id::varchar as provider_id,
        va.encounter_id::varchar as visit_occurrence_id,
        pde.code as measurement_source_value,
        pde.name as measurement_source_name
    from vitals_answers va
    join encounters e on e.id = va.encounter_id
    left join program_data_elements pde on pde.id = va.data_element_id
),

-- lab branch: completed lab tests that have a result (BL-007)
lab_measurements as (
    select
        lt.id::varchar as measurement_id,
        e.patient_id::varchar as person_id,
        coalesce(lt.completed_datetime, lr.published_datetime, lr.requested_datetime)::date as measurement_date,
        coalesce(lt.completed_datetime, lr.published_datetime, lr.requested_datetime) as measurement_datetime,  -- completed, else published/requested (BL-004)
        'lab' as measurement_type_source_value,
        case when trim(lt.result) ~ '^-?[0-9]+(\.[0-9]+)?$' then trim(lt.result)::numeric end as value_as_number,
        trim(lt.result) as value_source_value,
        ltt.unit as unit_source_value,
        lr.requested_by_id::varchar as provider_id,
        lr.encounter_id::varchar as visit_occurrence_id,
        ltt.code as measurement_source_value,
        ltt.name as measurement_source_name
    from lab_tests lt
    join lab_requests lr on lr.id = lt.lab_request_id
    join encounters e on e.id = lr.encounter_id
    left join lab_test_types ltt on ltt.id = lt.lab_test_type_id
    where lt.result is not null and trim(lt.result) != ''
        -- drop requests that never produced a valid result even if a stale value lingers (BL-007)
        and lr.status not in ('deleted', 'sample-not-collected', 'entered-in-error')
),

-- birth anthropometry, unpivoted upstream by int__patient_birth_measurements (BL-008).
-- Patient-level: no encounter, so provider_id and visit_occurrence_id are NULL
birth_measurements as (
    select
        (bm.patient_id || '-birthdata-' || bm.measurement_source_value)::varchar as measurement_id,
        bm.patient_id::varchar as person_id,
        bm.measurement_datetime::date as measurement_date,
        bm.measurement_datetime,
        'birth data' as measurement_type_source_value,
        case when trim(bm.value_source_value) ~ '^-?[0-9]+(\.[0-9]+)?$' then trim(bm.value_source_value)::numeric end as value_as_number,
        bm.value_source_value,
        null::varchar as unit_source_value,
        null::varchar as provider_id,
        null::varchar as visit_occurrence_id,
        bm.measurement_source_value,
        bm.measurement_source_name
    from patient_birth_measurements bm
)

-- columns listed explicitly per branch so reordering one branch can't silently mis-map
select
    measurement_id,
    person_id,
    measurement_date,
    measurement_datetime,
    measurement_type_source_value,
    value_as_number,
    value_source_value,
    unit_source_value,
    provider_id,
    visit_occurrence_id,
    measurement_source_value,
    measurement_source_name
from vitals_measurements

union all

select
    measurement_id,
    person_id,
    measurement_date,
    measurement_datetime,
    measurement_type_source_value,
    value_as_number,
    value_source_value,
    unit_source_value,
    provider_id,
    visit_occurrence_id,
    measurement_source_value,
    measurement_source_name
from lab_measurements

union all

select
    measurement_id,
    person_id,
    measurement_date,
    measurement_datetime,
    measurement_type_source_value,
    value_as_number,
    value_source_value,
    unit_source_value,
    provider_id,
    visit_occurrence_id,
    measurement_source_value,
    measurement_source_name
from birth_measurements
);
create or replace view "reporting"."clinical__observation" as (
-- clinical__observation -- OMOP-lite OBSERVATION domain. One row per clinical fact that is
-- neither a measurement nor a drug exposure, unioning three standard sources:
-- program/referral-survey answers (BL-006), vaccinations not given (BL-007), and triage
-- assessments unpivoted from triages (BL-008, via int__triage_observations). The observed
-- fact is retained as source code/name; FK graph wired from the encounter (BL-002);
-- *_concept_id deferred to the future vocab__ layer (BL-003). Sources only from bases/ +
-- intermediate (D10). Deployment-specific observation sources are added by per-deployment
-- override (see spec). See spec for BL-001..BL-008.

with  __dbt__cte__int__triage_observations as (
-- int__triage_observations -- unpivots the wide triages row into one row per recorded
-- triage element (tall shape), for the triage branch of clinical__observation.
-- Elements: the acuity score, and the chief/secondary complaints (resolved to their
-- reference_data names, type = 'triageReason'). Blank/unrecorded elements are dropped.
-- Values are kept as text here; the numeric cast happens in clinical__observation.

with triages as (
    select * from "reporting"."triages"
),

reference_data as (
    select * from "reporting"."reference_data"
),

triage_elements as (
    select
        t.id as triage_id,
        t.encounter_id,
        t.clinician_id,
        -- triage_time is application-required on the triage form, so it's the canonical
        -- "when"; a null here is a data-quality issue AC-006 should surface, not paper over
        t.triage_datetime as observation_datetime,
        t.score,
        cc.name as chief_complaint,
        sc.name as secondary_complaint
    from triages t
    left join reference_data cc on cc.id = t.chief_complaint_id
    left join reference_data sc on sc.id = t.secondary_complaint_id
)

-- one row per recorded element; blanks are dropped
select
    te.triage_id,
    te.encounter_id,
    te.clinician_id,
    te.observation_datetime,
    m.observation_source_value,
    m.observation_source_name,
    m.value_source_value
from triage_elements te
cross join lateral (values
    ('triage_score',        'Triage score',        te.score),
    ('chief_complaint',     'Chief complaint',     te.chief_complaint),
    ('secondary_complaint', 'Secondary complaint', te.secondary_complaint)
) as m (observation_source_value, observation_source_name, value_source_value)
where m.value_source_value is not null and trim(m.value_source_value) != ''
), survey_response_answers as (
    select * from "reporting"."survey_response_answers"
),

survey_responses as (
    select * from "reporting"."survey_responses"
),

surveys as (
    select * from "reporting"."surveys"
),

program_data_elements as (
    select * from "reporting"."program_data_elements"
),

vaccine_administrations as (
    select * from "reporting"."vaccine_administrations"
),

vaccine_schedules as (
    select * from "reporting"."vaccine_schedules"
),

reference_data as (
    select * from "reporting"."reference_data"
),

triage_observations as (
    select * from __dbt__cte__int__triage_observations
),

encounters as (
    select * from "reporting"."encounters"
),

-- every recorded answer to a programs/referral survey; sensitive surveys included, echo /
-- non-answer question types excluded (BL-006)
survey_answers as (
    select
        sra.id,
        trim(sra.body) as body,
        s.survey_type,
        sr.encounter_id,
        sr.start_datetime,
        sr.submitted_by_id,
        pde.code,
        pde.name
    from survey_response_answers sra
    join survey_responses sr on sr.id = sra.response_id
    join surveys s on s.id = sr.survey_id and s.survey_type in ('programs', 'referral')
    join program_data_elements pde
        on pde.id = sra.data_element_id
        and pde.type not in ('PatientData', 'UserData', 'Instruction')
    where sra.body is not null and trim(sra.body) != ''
),

-- survey branch (BL-006). ids cast to varchar so the union is type-safe (BL-002)
survey_observations as (
    select
        sa.id::varchar as observation_id,
        e.patient_id::varchar as person_id,
        sa.start_datetime::date as observation_date,
        sa.start_datetime as observation_datetime,
        -- provenance / union discriminator (BL-005)
        case sa.survey_type
            when 'programs' then 'program survey'
            else 'referral survey'
        end as observation_type_source_value,
        case when sa.body ~ '^-?[0-9]+(\.[0-9]+)?$' then sa.body::numeric end as value_as_number,
        sa.body as value_source_value,
        sa.submitted_by_id::varchar as provider_id,
        sa.encounter_id::varchar as visit_occurrence_id,
        sa.code as observation_source_value,
        sa.name as observation_source_name
    from survey_answers sa
    join encounters e on e.id = sa.encounter_id
),

-- vaccination-not-given branch (BL-007): the refusal/not-done fact is the observation, so
-- rows are kept even when no reason was recorded. Vaccine identity carried like
-- clinical__drug_exposure: vaccine_name as the name, code via the scheduled vaccine
not_given_observations as (
    select
        av.id::varchar as observation_id,
        e.patient_id::varchar as person_id,
        av.datetime::date as observation_date,
        av.datetime as observation_datetime,  -- when the not-given was recorded (BL-004)
        'vaccination not given' as observation_type_source_value,
        null::numeric as value_as_number,
        coalesce(rdr.name, av.reason) as value_source_value,
        -- recorded_by_id (a real user FK) preferred; given_by is free text, so the FK test
        -- is scoped off this branch (BL-002)
        coalesce(av.recorded_by_id, av.given_by)::varchar as provider_id,
        av.encounter_id::varchar as visit_occurrence_id,
        rd.code as observation_source_value,
        av.vaccine_name as observation_source_name
    from vaccine_administrations av
    join encounters e on e.id = av.encounter_id
    left join reference_data rdr on rdr.id = av.not_given_reason_id
    left join vaccine_schedules vs on vs.id = av.scheduled_vaccine_id
    left join reference_data rd on rd.id = vs.vaccine_id
    where av.status = 'NOT_GIVEN'
),

-- triage branch, unpivoted upstream by int__triage_observations (BL-008). The synthetic
-- id is <triage_id>-<element>, unique since each triage yields each element at most once
triage_branch_observations as (
    select
        (t.triage_id || '-' || t.observation_source_value)::varchar as observation_id,
        e.patient_id::varchar as person_id,
        t.observation_datetime::date as observation_date,
        t.observation_datetime,
        'triage' as observation_type_source_value,
        case when trim(t.value_source_value) ~ '^-?[0-9]+(\.[0-9]+)?$' then trim(t.value_source_value)::numeric end as value_as_number,
        t.value_source_value,
        t.clinician_id::varchar as provider_id,
        t.encounter_id::varchar as visit_occurrence_id,
        t.observation_source_value,
        t.observation_source_name
    from triage_observations t
    join encounters e on e.id = t.encounter_id
)

-- columns listed explicitly per branch so reordering one branch can't silently mis-map
select
    observation_id,
    person_id,
    observation_date,
    observation_datetime,
    observation_type_source_value,
    value_as_number,
    value_source_value,
    provider_id,
    visit_occurrence_id,
    observation_source_value,
    observation_source_name
from survey_observations

union all

select
    observation_id,
    person_id,
    observation_date,
    observation_datetime,
    observation_type_source_value,
    value_as_number,
    value_source_value,
    provider_id,
    visit_occurrence_id,
    observation_source_value,
    observation_source_name
from not_given_observations

union all

select
    observation_id,
    person_id,
    observation_date,
    observation_datetime,
    observation_type_source_value,
    value_as_number,
    value_source_value,
    provider_id,
    visit_occurrence_id,
    observation_source_value,
    observation_source_name
from triage_branch_observations
);
create or replace view "reporting"."int__inpatient_admission" as (
-- int__inpatient_admission -- one row per inpatient admission, carrying every attribute
-- metric__inpatient_admission disaggregates by.
--
-- Shared base for metric__inpatient_admission and any inpatient metric added later.
--
-- Ephemeral, so this is inlined into each consumer and materialises nothing.
--
-- Spec: specs/dbt-model/metric__inpatient_admission.md

with visit_detail as (
    select * from "reporting"."clinical__visit_detail"
),

visit_occurrence as (
    select * from "reporting"."clinical__visit_occurrence"
),

person as (
    select * from "reporting"."clinical__person"
),

locations as (
    select * from "reporting"."locations"
),

encounters as (
    select * from "reporting"."encounters"
),

discharges as (
    select * from "reporting"."discharges"
),

reference_data as (
    select * from "reporting"."reference_data"
),

condition_occurrence as (
    select * from "reporting"."clinical__condition_occurrence"
),

-- BL-013: at most one principal diagnosis per encounter. Tamanu does not stop a second
-- is_primary row being recorded, so the earliest is taken (condition_occurrence_id breaks a
-- datetime tie) -- without this the join below would fan out and duplicate an admission.
principal_diagnoses as (
    select
        visit_occurrence_id,
        condition_source_value,
        row_number() over (
            partition by visit_occurrence_id
            order by condition_start_datetime, condition_occurrence_id
        ) as diagnosis_rank
    from condition_occurrence
    where is_primary
),

-- BL-003: the admission segment of each encounter -- the earliest history segment whose OMOP
-- visit concept is 9201/Inpatient Visit. For a direct admission this is also the encounter's
-- first segment; for an encounter that passed through an ED/triage/observation phase first
-- (visit-level concept 262) it is the later segment where the patient actually became an
-- inpatient -- anchoring on the first segment unconditionally, as int__emergency_visits does
-- for 9203, would miss every ED-then-admitted encounter.
admission_segments as (
    select
        visit_occurrence_id,
        person_id,
        visit_detail_start_datetime as admission_start__datetime,
        care_site_id,
        department_id,
        row_number() over (
            partition by visit_occurrence_id
            order by visit_detail_start_datetime, visit_detail_id
        ) as admission_rank
    from visit_detail
    where visit_detail_concept_id = 9201 -- OMOP 'Inpatient Visit'
),

-- BL-003: one row per admission, attributed to that admission segment. An encounter with no
-- segment at concept 9201 at all -- a pure ED or outpatient encounter -- has no row here.
admissions as (
    select
        -- BL-011: the encounter id is the subject. One admission segment per encounter, so
        -- this is unique across the rows emitted here.
        adm.visit_occurrence_id,
        adm.admission_start__datetime,
        -- Encounter end is discharge from hospital. NULL = encounter still open.
        vo.visit_end_datetime as visit_end__datetime,
        loc.facility_id,
        -- BL-007: the ward is the admission segment's department, carried as the Tamanu id
        -- only -- resolving it to a name is a consumer-layer concern, same convention as
        -- facility_id (BL-009). Nullable: an admission segment recorded with no department
        -- stays NULL rather than being excluded.
        adm.department_id as admission_ward_id,
        pr.gender_source_value as sex,
        -- BL-005: visit-level concept 262 ('Emergency Room and Inpatient Visit') marks an
        -- admission that had a prior ED/triage/observation phase; it exists only at visit
        -- grain.
        coalesce(vo.visit_concept_id = 262, false) as is_admitted_via_emergency,
        -- BL-012: how the patient arrived, from the encounter's referral source.
        admission_source_ref.name as admission_source_raw,
        -- BL-014: how the encounter ended.
        disposition.name as discharge_disposition_raw,
        pdx.condition_source_value as principal_diagnosis_code,
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    adm.admission_start__datetime::date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years,
        -- BL-015: total time as an inpatient -- admission to discharge from hospital. NULL
        -- while the encounter is open.
        case
            when vo.visit_end_datetime is null then null
            else extract(epoch from (
                    vo.visit_end_datetime - adm.admission_start__datetime
                ))::bigint
        end as length_of_stay__seconds
    from admission_segments adm
    join person pr
        on pr.person_id = adm.person_id
    join visit_occurrence vo
        on vo.visit_occurrence_id = adm.visit_occurrence_id
    -- BL-007: facility is the admission segment's location. Inner join, so an admission whose
    -- location does not resolve is excluded rather than attributed to a NULL facility.
    join locations loc
        on loc.id = adm.care_site_id
    -- BL-012: the referral source lives on the encounter, not on clinical__visit_occurrence.
    join encounters enc
        on enc.id = adm.visit_occurrence_id
    -- BL-012: left join -- an admission with no referral source still counts.
    left join reference_data admission_source_ref
        on admission_source_ref.id = enc.referral_source_id
    -- BL-014: left join -- an admission with no discharge record still counts. bases/discharges
    -- is `distinct on (encounter_id)`, so it holds one row per encounter and cannot fan out.
    left join discharges dis
        on dis.encounter_id = adm.visit_occurrence_id
    left join reference_data disposition
        on disposition.id = dis.disposition_id
    -- BL-013: left join -- an admission with no principal diagnosis still counts. Ranked to
    -- one row per encounter above, so this cannot fan out.
    left join principal_diagnoses pdx
        on pdx.visit_occurrence_id = adm.visit_occurrence_id
        and pdx.diagnosis_rank = 1
    -- BL-010: no facilities.is_sensitive filter, so this covers standard and sensitive
    -- facilities alike.
    where adm.admission_rank = 1
)

select
    visit_occurrence_id,
    admission_start__datetime,
    visit_end__datetime,
    facility_id,
    admission_ward_id,
    sex,
    age_years,
    is_admitted_via_emergency,
    -- BL-012: 'Not recorded' covers an admission with no referral source. Never NULL -- the
    -- data tables expose this as an array filter, and Tupaia's array filter drops NULL rows.
    coalesce(admission_source_raw, 'Not recorded') as admission_source,
    length_of_stay__seconds,
    -- BL-015: length of stay as minutes, to two decimal places -- 0.6-second resolution, finer
    -- than any reporting need, and a fixed scale so the value is stable to compare.
    round(length_of_stay__seconds / 60.0, 2) as length_of_stay__minutes,
    principal_diagnosis_code,
    -- BL-014: 'Not recorded' covers an admission with no discharge record. Never NULL, for the
    -- same reason as admission_source.
    coalesce(discharge_disposition_raw, 'Not recorded') as discharge_disposition
from admissions
);
create or replace view "reporting"."int__emergency_visits" as (
-- int__emergency_visits -- one row per emergency department attendance, carrying every
-- attribute the emergency care metrics disaggregate by.
--
-- Shared base for metric__emergency_visit and metric__emergency_stay. Both are
-- one-row-per-attendance over the same span, so the inclusion rule, the joins and the
-- derived timings live here once rather than in each metric.
--
-- Ephemeral, so this is inlined into each consumer and materialises nothing.
--
-- Specs: specs/dbt-model/metric__emergency_visit.md,
-- specs/dbt-model/metric__emergency_stay.md

with visit_detail as (
    select * from "reporting"."clinical__visit_detail"
),

visit_occurrence as (
    select * from "reporting"."clinical__visit_occurrence"
),

person as (
    select * from "reporting"."clinical__person"
),

locations as (
    select * from "reporting"."locations"
),

encounters as (
    select * from "reporting"."encounters"
),

triages as (
    select * from "reporting"."triages"
),

discharges as (
    select * from "reporting"."discharges"
),

reference_data as (
    select * from "reporting"."reference_data"
),

condition_occurrence as (
    select * from "reporting"."clinical__condition_occurrence"
),

-- BL-013: at most one principal diagnosis per encounter. Tamanu does not stop a second
-- is_primary row being recorded, so the earliest is taken (condition_occurrence_id breaks a
-- datetime tie) -- without this the join below would fan out and duplicate an attendance.
principal_diagnoses as (
    select
        visit_occurrence_id,
        condition_source_value,
        condition_source_name,
        row_number() over (
            partition by visit_occurrence_id
            order by condition_start_datetime, condition_occurrence_id
        ) as diagnosis_rank
    from condition_occurrence
    where is_primary
),

-- BL-003: the ED intake segment of each encounter -- the first history segment whose OMOP
-- visit concept is 9203/Emergency Room Visit, covering emergency, triage and observation.
ed_intake as (
    select
        visit_occurrence_id,
        visit_detail_start_datetime,
        care_site_id
    from visit_detail
    where preceding_visit_detail_id is null
        and visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
),

-- BL-018: the first time the patient's location leaves the ED. A segment boundary is not by
-- itself a departure: an encounter_type change to admission closes the intake segment while
-- the patient is still physically in the emergency department, which is the boarding case a
-- four-hour measure exists to expose. Only a change of care_site is a physical departure.
ed_location_exits as (
    select
        later.visit_occurrence_id,
        min(later.visit_detail_start_datetime) as ed_location_exit__datetime
    from visit_detail later
    join ed_intake i
        on i.visit_occurrence_id = later.visit_occurrence_id
    where later.visit_detail_start_datetime > i.visit_detail_start_datetime
        and later.care_site_id is distinct from i.care_site_id
    group by later.visit_occurrence_id
),

-- BL-003: one row per attendance, attributed to that intake segment.
attendances as (
    select
        -- BL-011: the encounter id is the subject. One intake segment per encounter, so this
        -- is unique across the rows emitted here.
        vd.visit_occurrence_id,
        vd.visit_detail_start_datetime as ed_start__datetime,
        -- BL-018: departure from the emergency department, taken as the earliest signal that
        -- the patient left: the first move to another location, or the time a booked transfer
        -- takes effect. least() ignores NULLs, so whichever exists wins and the earlier wins
        -- when both do. Falling through to the encounter end covers a discharge straight from
        -- the ED and any encounter that never moved.
        coalesce(
            least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
            vo.visit_end_datetime
        ) as ed_end__datetime,
        -- Encounter end is discharge from hospital, so for an admitted patient it is later
        -- than the ED departure. NULL = encounter still open.
        vo.visit_end_datetime as visit_end__datetime,
        loc.facility_id,
        pr.gender_source_value as sex,
        -- BL-005: visit-level concept 262 ('Emergency Room and Inpatient Visit') is the
        -- admitted episode-end status; it exists only at visit grain.
        coalesce(vo.visit_concept_id = 262, false) as is_admitted,
        -- BL-012: the triage practitioner's acuity category, '1' to '5'
        tr.score as triage_score_raw,
        -- BL-014: waiting time is triage to the start of active care, which is when the
        -- triage is closed. A time recorded before the triage is unusable.
        case
            when tr.closed_datetime < tr.triage_datetime then null
            else extract(epoch from (tr.closed_datetime - tr.triage_datetime))::bigint
        end as waiting_time__seconds,
        -- BL-015: time in the ED -- arrival to the departure resolved by BL-018. NULL only
        -- while the patient is in the ED and the encounter is still open.
        case
            when coalesce(
                    least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
                    vo.visit_end_datetime
                ) is null then null
            else extract(epoch from (
                    coalesce(
                        least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
                        vo.visit_end_datetime
                    ) - vd.visit_detail_start_datetime
                ))::bigint
        end as ed_time__seconds,
        -- BL-015: total length of stay -- arrival to discharge from hospital, so it spans the
        -- inpatient episode for an admitted patient. NULL while the encounter is open.
        case
            when vo.visit_end_datetime is null then null
            else extract(epoch from (
                    vo.visit_end_datetime - vd.visit_detail_start_datetime
                ))::bigint
        end as length_of_stay__seconds,
        -- BL-017: how the encounter ended. Encounter-grained, not ED-grained -- for an
        -- attendance that was admitted this is the eventual hospital discharge.
        disposition.name as discharge_disposition_raw,
        -- BL-013: raw code and reference-data name, ungrouped -- classifying either one (an
        -- ICD-10 chapter or any other grouping) is a presentation choice a deployment may set
        -- differently, so that happens at the deployment layer, the same division as age_years
        -- (BL-019).
        pdx.condition_source_value as principal_diagnosis_code,
        pdx.condition_source_name as principal_diagnosis,
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    vd.visit_detail_start_date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years
    from visit_detail vd
    join person pr
        on pr.person_id = vd.person_id
    join visit_occurrence vo
        on vo.visit_occurrence_id = vd.visit_occurrence_id
    -- BL-007: facility is the intake segment's location. Inner join, so an encounter whose
    -- location does not resolve is excluded rather than attributed to a NULL facility.
    join locations loc
        on loc.id = vd.care_site_id
    -- BL-018: the booked transfer, one of the two departure signals. encounters.id is the
    -- primary key, so this yields one row per attendance.
    join encounters enc
        on enc.id = vd.visit_occurrence_id
    -- BL-018: the physical departure, where one has been recorded. Grouped to one row per
    -- encounter above, so it cannot fan out.
    left join ed_location_exits x
        on x.visit_occurrence_id = vd.visit_occurrence_id
    -- BL-012: left join -- an attendance with no triage record still counts. Tamanu records
    -- at most one triage per encounter, so this does not fan out; each metric's grain test is
    -- the backstop if that ever stops holding.
    left join triages tr
        on tr.encounter_id = vd.visit_occurrence_id
    -- BL-013: left join -- an attendance with no principal diagnosis still counts. Ranked to
    -- one row per encounter above, so this cannot fan out.
    left join principal_diagnoses pdx
        on pdx.visit_occurrence_id = vd.visit_occurrence_id
        and pdx.diagnosis_rank = 1
    -- BL-017: left join -- an attendance with no discharge record still counts. bases/discharges
    -- is `distinct on (encounter_id)`, so it holds one row per encounter and cannot fan out.
    left join discharges dis
        on dis.encounter_id = vd.visit_occurrence_id
    left join reference_data disposition
        on disposition.id = dis.disposition_id
    -- BL-010: no facilities.is_sensitive filter, so this covers standard and sensitive
    -- facilities alike.
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
)

select
    visit_occurrence_id,
    ed_start__datetime,
    ed_end__datetime,
    visit_end__datetime,
    facility_id,
    sex,
    age_years,
    is_admitted,
    waiting_time__seconds,
    -- BL-014: the wait as minutes, to two decimal places -- 0.6-second resolution, finer
    -- than any reporting need, and a fixed scale so the value is stable to compare. Minutes
    -- from whole seconds is a repeating decimal, so some scale has to be chosen.
    -- NULL until the patient reaches active care.
    round(waiting_time__seconds / 60.0, 2) as waiting_time__minutes,
    ed_time__seconds,
    -- BL-015: time in the ED as minutes, to two decimal places, on the same basis as
    -- waiting_time__minutes. NULL only while the patient is in the ED with nothing booked.
    round(ed_time__seconds / 60.0, 2) as ed_time__minutes,
    length_of_stay__seconds,
    -- BL-015: total length of stay as minutes, on the same basis as the other durations
    round(length_of_stay__seconds / 60.0, 2) as length_of_stay__minutes,
    principal_diagnosis_code,
    principal_diagnosis,
    -- BL-012: 'Not recorded' covers both an attendance with no triage row and a triage row
    -- with a blank score. Never NULL -- the data tables expose these as array filters, and
    -- Tupaia's array filter drops NULL rows.
    coalesce(triage_score_raw, 'Not recorded') as triage_score,
    -- BL-017
    coalesce(discharge_disposition_raw, 'Not recorded') as discharge_disposition,
    -- BL-016: hour of the day the patient arrived, 0-23. Tamanu stores naive timestamps in
    -- the deployment's central timezone (var('timezone'), see to_user_selected_timezone), so
    -- this is already a local hour and needs no conversion. A deployment spanning timezones
    -- gets the central zone's hour, not each facility's.
    extract(hour from ed_start__datetime)::int as ed_start__hour
-- BL-019: no banding here. A four-hour split and an age classification are both presentation
-- choices a deployment may set differently, so the metrics emit the continuous value and the
-- consumer's data table bands it.
from attendances
);
create or replace view "reporting"."metric__emergency_visit" as (
-- metric__emergency_visit -- D5 metric view for the emergency care attendance
-- indicator registered in documentations/metrics/*.yml: ed_visit (MAUI-6694).
-- Spec: specs/dbt-model/metric__emergency_visit.md (BL-001..BL-016).
--
-- Per-attendance (subject) grain: one row per ED attendance, value_numeric 1, so a consumer
-- aggregates at whatever grain it needs -- any subset of the disaggregations, and any time
-- grain from minute upwards (BL-011).
--
-- period_start/period_end are timestamps bounding the attendance's stay in the ED, so a
-- consumer computes length of stay as period_end - period_start (BL-002).
--
-- The attendance base, its joins and its derived timings are shared with
-- metric__emergency_stay via int__emergency_visits.
--
-- The registry carries the definition; this model is its implementation (BL-001).

with  __dbt__cte__int__emergency_visits as (
-- int__emergency_visits -- one row per emergency department attendance, carrying every
-- attribute the emergency care metrics disaggregate by.
--
-- Shared base for metric__emergency_visit and metric__emergency_stay. Both are
-- one-row-per-attendance over the same span, so the inclusion rule, the joins and the
-- derived timings live here once rather than in each metric.
--
-- Ephemeral, so this is inlined into each consumer and materialises nothing.
--
-- Specs: specs/dbt-model/metric__emergency_visit.md,
-- specs/dbt-model/metric__emergency_stay.md

with visit_detail as (
    select * from "reporting"."clinical__visit_detail"
),

visit_occurrence as (
    select * from "reporting"."clinical__visit_occurrence"
),

person as (
    select * from "reporting"."clinical__person"
),

locations as (
    select * from "reporting"."locations"
),

encounters as (
    select * from "reporting"."encounters"
),

triages as (
    select * from "reporting"."triages"
),

discharges as (
    select * from "reporting"."discharges"
),

reference_data as (
    select * from "reporting"."reference_data"
),

condition_occurrence as (
    select * from "reporting"."clinical__condition_occurrence"
),

-- BL-013: at most one principal diagnosis per encounter. Tamanu does not stop a second
-- is_primary row being recorded, so the earliest is taken (condition_occurrence_id breaks a
-- datetime tie) -- without this the join below would fan out and duplicate an attendance.
principal_diagnoses as (
    select
        visit_occurrence_id,
        condition_source_value,
        condition_source_name,
        row_number() over (
            partition by visit_occurrence_id
            order by condition_start_datetime, condition_occurrence_id
        ) as diagnosis_rank
    from condition_occurrence
    where is_primary
),

-- BL-003: the ED intake segment of each encounter -- the first history segment whose OMOP
-- visit concept is 9203/Emergency Room Visit, covering emergency, triage and observation.
ed_intake as (
    select
        visit_occurrence_id,
        visit_detail_start_datetime,
        care_site_id
    from visit_detail
    where preceding_visit_detail_id is null
        and visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
),

-- BL-018: the first time the patient's location leaves the ED. A segment boundary is not by
-- itself a departure: an encounter_type change to admission closes the intake segment while
-- the patient is still physically in the emergency department, which is the boarding case a
-- four-hour measure exists to expose. Only a change of care_site is a physical departure.
ed_location_exits as (
    select
        later.visit_occurrence_id,
        min(later.visit_detail_start_datetime) as ed_location_exit__datetime
    from visit_detail later
    join ed_intake i
        on i.visit_occurrence_id = later.visit_occurrence_id
    where later.visit_detail_start_datetime > i.visit_detail_start_datetime
        and later.care_site_id is distinct from i.care_site_id
    group by later.visit_occurrence_id
),

-- BL-003: one row per attendance, attributed to that intake segment.
attendances as (
    select
        -- BL-011: the encounter id is the subject. One intake segment per encounter, so this
        -- is unique across the rows emitted here.
        vd.visit_occurrence_id,
        vd.visit_detail_start_datetime as ed_start__datetime,
        -- BL-018: departure from the emergency department, taken as the earliest signal that
        -- the patient left: the first move to another location, or the time a booked transfer
        -- takes effect. least() ignores NULLs, so whichever exists wins and the earlier wins
        -- when both do. Falling through to the encounter end covers a discharge straight from
        -- the ED and any encounter that never moved.
        coalesce(
            least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
            vo.visit_end_datetime
        ) as ed_end__datetime,
        -- Encounter end is discharge from hospital, so for an admitted patient it is later
        -- than the ED departure. NULL = encounter still open.
        vo.visit_end_datetime as visit_end__datetime,
        loc.facility_id,
        pr.gender_source_value as sex,
        -- BL-005: visit-level concept 262 ('Emergency Room and Inpatient Visit') is the
        -- admitted episode-end status; it exists only at visit grain.
        coalesce(vo.visit_concept_id = 262, false) as is_admitted,
        -- BL-012: the triage practitioner's acuity category, '1' to '5'
        tr.score as triage_score_raw,
        -- BL-014: waiting time is triage to the start of active care, which is when the
        -- triage is closed. A time recorded before the triage is unusable.
        case
            when tr.closed_datetime < tr.triage_datetime then null
            else extract(epoch from (tr.closed_datetime - tr.triage_datetime))::bigint
        end as waiting_time__seconds,
        -- BL-015: time in the ED -- arrival to the departure resolved by BL-018. NULL only
        -- while the patient is in the ED and the encounter is still open.
        case
            when coalesce(
                    least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
                    vo.visit_end_datetime
                ) is null then null
            else extract(epoch from (
                    coalesce(
                        least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
                        vo.visit_end_datetime
                    ) - vd.visit_detail_start_datetime
                ))::bigint
        end as ed_time__seconds,
        -- BL-015: total length of stay -- arrival to discharge from hospital, so it spans the
        -- inpatient episode for an admitted patient. NULL while the encounter is open.
        case
            when vo.visit_end_datetime is null then null
            else extract(epoch from (
                    vo.visit_end_datetime - vd.visit_detail_start_datetime
                ))::bigint
        end as length_of_stay__seconds,
        -- BL-017: how the encounter ended. Encounter-grained, not ED-grained -- for an
        -- attendance that was admitted this is the eventual hospital discharge.
        disposition.name as discharge_disposition_raw,
        -- BL-013: raw code and reference-data name, ungrouped -- classifying either one (an
        -- ICD-10 chapter or any other grouping) is a presentation choice a deployment may set
        -- differently, so that happens at the deployment layer, the same division as age_years
        -- (BL-019).
        pdx.condition_source_value as principal_diagnosis_code,
        pdx.condition_source_name as principal_diagnosis,
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    vd.visit_detail_start_date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years
    from visit_detail vd
    join person pr
        on pr.person_id = vd.person_id
    join visit_occurrence vo
        on vo.visit_occurrence_id = vd.visit_occurrence_id
    -- BL-007: facility is the intake segment's location. Inner join, so an encounter whose
    -- location does not resolve is excluded rather than attributed to a NULL facility.
    join locations loc
        on loc.id = vd.care_site_id
    -- BL-018: the booked transfer, one of the two departure signals. encounters.id is the
    -- primary key, so this yields one row per attendance.
    join encounters enc
        on enc.id = vd.visit_occurrence_id
    -- BL-018: the physical departure, where one has been recorded. Grouped to one row per
    -- encounter above, so it cannot fan out.
    left join ed_location_exits x
        on x.visit_occurrence_id = vd.visit_occurrence_id
    -- BL-012: left join -- an attendance with no triage record still counts. Tamanu records
    -- at most one triage per encounter, so this does not fan out; each metric's grain test is
    -- the backstop if that ever stops holding.
    left join triages tr
        on tr.encounter_id = vd.visit_occurrence_id
    -- BL-013: left join -- an attendance with no principal diagnosis still counts. Ranked to
    -- one row per encounter above, so this cannot fan out.
    left join principal_diagnoses pdx
        on pdx.visit_occurrence_id = vd.visit_occurrence_id
        and pdx.diagnosis_rank = 1
    -- BL-017: left join -- an attendance with no discharge record still counts. bases/discharges
    -- is `distinct on (encounter_id)`, so it holds one row per encounter and cannot fan out.
    left join discharges dis
        on dis.encounter_id = vd.visit_occurrence_id
    left join reference_data disposition
        on disposition.id = dis.disposition_id
    -- BL-010: no facilities.is_sensitive filter, so this covers standard and sensitive
    -- facilities alike.
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
)

select
    visit_occurrence_id,
    ed_start__datetime,
    ed_end__datetime,
    visit_end__datetime,
    facility_id,
    sex,
    age_years,
    is_admitted,
    waiting_time__seconds,
    -- BL-014: the wait as minutes, to two decimal places -- 0.6-second resolution, finer
    -- than any reporting need, and a fixed scale so the value is stable to compare. Minutes
    -- from whole seconds is a repeating decimal, so some scale has to be chosen.
    -- NULL until the patient reaches active care.
    round(waiting_time__seconds / 60.0, 2) as waiting_time__minutes,
    ed_time__seconds,
    -- BL-015: time in the ED as minutes, to two decimal places, on the same basis as
    -- waiting_time__minutes. NULL only while the patient is in the ED with nothing booked.
    round(ed_time__seconds / 60.0, 2) as ed_time__minutes,
    length_of_stay__seconds,
    -- BL-015: total length of stay as minutes, on the same basis as the other durations
    round(length_of_stay__seconds / 60.0, 2) as length_of_stay__minutes,
    principal_diagnosis_code,
    principal_diagnosis,
    -- BL-012: 'Not recorded' covers both an attendance with no triage row and a triage row
    -- with a blank score. Never NULL -- the data tables expose these as array filters, and
    -- Tupaia's array filter drops NULL rows.
    coalesce(triage_score_raw, 'Not recorded') as triage_score,
    -- BL-017
    coalesce(discharge_disposition_raw, 'Not recorded') as discharge_disposition,
    -- BL-016: hour of the day the patient arrived, 0-23. Tamanu stores naive timestamps in
    -- the deployment's central timezone (var('timezone'), see to_user_selected_timezone), so
    -- this is already a local hour and needs no conversion. A deployment spanning timezones
    -- gets the central zone's hour, not each facility's.
    extract(hour from ed_start__datetime)::int as ed_start__hour
-- BL-019: no banding here. A four-hour split and an age classification are both presentation
-- choices a deployment may set differently, so the metrics emit the continuous value and the
-- consumer's data table bands it.
from attendances
), ed_visits as (
    select * from __dbt__cte__int__emergency_visits
)

-- BL-005: admission outcome is a disaggregation column, so a consumer groups by it,
-- filters to it, or ignores it. The admitted count is the sum of value_numeric where
-- is_admitted is true.

-- BL-006: the model emits counts. The admission rate is
-- sum(value_numeric) filter (where is_admitted) / sum(value_numeric), formed at whatever
-- grain the consumer groups to.

-- BL-002: every attendance is emitted, including today's. A consumer needing whole periods
-- only -- a monthly trend line -- applies its own date filter.

-- D5 wide format: value_boolean is unused by this metric.
--
-- BL-009: facility is emitted as the Tamanu facility_id only. Translating it to a
-- consumer's own identifier -- a Tupaia entity code, a DHIS2 org unit -- is a
-- consumer-layer concern and is done there (for Tupaia, in the data table), not here.
select
    'ed_visit'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    -- BL-002: minute grain, arrival in the ED to discharge from hospital, so
    -- period_end - period_start is total length of stay -- spanning the inpatient episode for
    -- an admitted attendance. metric__emergency_stay measures the ED portion instead.
    -- period_end is NULL while the encounter is open.
    ed_start__datetime as period_start,
    visit_end__datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-011: one attendance per row, so the count contribution is always 1. Additive,
    -- so a data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-004: age in whole years at arrival.
    -- BL-019: unbanded -- an age classification is a presentation choice a deployment may set
    -- differently, so the consumer's data table bands it.
    age_years,
    triage_score,
    -- BL-013: raw code and reference-data name, ungrouped -- classifying either one (an
    -- ICD-10 chapter or any other grouping) is a presentation choice a deployment may set
    -- differently, so it happens at the deployment/data-table layer, the same division as
    -- age_years and age_group__who_primary_classification (BL-019). diagnosis__icd10_chapter
    -- stays defined in macros/ for a deployment to apply over principal_diagnosis_code there.
    principal_diagnosis_code,
    principal_diagnosis,
    -- BL-014: the wait to active care, in minutes
    waiting_time__minutes,
    -- BL-015: total length of stay in minutes.
    -- BL-019: unbanded, for the same reason as age.
    length_of_stay__minutes,
    -- BL-016: local hour of arrival, 0-23
    ed_start__hour,
    is_admitted
from ed_visits
);
create or replace view "reporting"."metric__inpatient_admission" as (
-- metric__inpatient_admission -- D5 metric view for the inpatient admission indicator
-- registered in documentations/metrics/*.yml: inpatient_admission.
-- Spec: specs/dbt-model/metric__inpatient_admission.md (BL-001..BL-015).
--
-- Per-admission (subject) grain: one row per hospital admission, value_numeric 1, so a
-- consumer aggregates at whatever grain it needs -- any subset of the disaggregations, and
-- any time grain from minute upwards (BL-011).
--
-- period_start/period_end bound the admission -- from becoming an inpatient to discharge
-- from hospital -- so a consumer computes length of stay as period_end - period_start
-- (BL-002). Grouping on period_start gives admissions in a period; grouping on period_end
-- gives discharges over the same rows -- there is no separate discharge metric_id.
--
-- The registry carries the definition; this model is its implementation (BL-001).

with  __dbt__cte__int__inpatient_admission as (
-- int__inpatient_admission -- one row per inpatient admission, carrying every attribute
-- metric__inpatient_admission disaggregates by.
--
-- Shared base for metric__inpatient_admission and any inpatient metric added later.
--
-- Ephemeral, so this is inlined into each consumer and materialises nothing.
--
-- Spec: specs/dbt-model/metric__inpatient_admission.md

with visit_detail as (
    select * from "reporting"."clinical__visit_detail"
),

visit_occurrence as (
    select * from "reporting"."clinical__visit_occurrence"
),

person as (
    select * from "reporting"."clinical__person"
),

locations as (
    select * from "reporting"."locations"
),

encounters as (
    select * from "reporting"."encounters"
),

discharges as (
    select * from "reporting"."discharges"
),

reference_data as (
    select * from "reporting"."reference_data"
),

condition_occurrence as (
    select * from "reporting"."clinical__condition_occurrence"
),

-- BL-013: at most one principal diagnosis per encounter. Tamanu does not stop a second
-- is_primary row being recorded, so the earliest is taken (condition_occurrence_id breaks a
-- datetime tie) -- without this the join below would fan out and duplicate an admission.
principal_diagnoses as (
    select
        visit_occurrence_id,
        condition_source_value,
        row_number() over (
            partition by visit_occurrence_id
            order by condition_start_datetime, condition_occurrence_id
        ) as diagnosis_rank
    from condition_occurrence
    where is_primary
),

-- BL-003: the admission segment of each encounter -- the earliest history segment whose OMOP
-- visit concept is 9201/Inpatient Visit. For a direct admission this is also the encounter's
-- first segment; for an encounter that passed through an ED/triage/observation phase first
-- (visit-level concept 262) it is the later segment where the patient actually became an
-- inpatient -- anchoring on the first segment unconditionally, as int__emergency_visits does
-- for 9203, would miss every ED-then-admitted encounter.
admission_segments as (
    select
        visit_occurrence_id,
        person_id,
        visit_detail_start_datetime as admission_start__datetime,
        care_site_id,
        department_id,
        row_number() over (
            partition by visit_occurrence_id
            order by visit_detail_start_datetime, visit_detail_id
        ) as admission_rank
    from visit_detail
    where visit_detail_concept_id = 9201 -- OMOP 'Inpatient Visit'
),

-- BL-003: one row per admission, attributed to that admission segment. An encounter with no
-- segment at concept 9201 at all -- a pure ED or outpatient encounter -- has no row here.
admissions as (
    select
        -- BL-011: the encounter id is the subject. One admission segment per encounter, so
        -- this is unique across the rows emitted here.
        adm.visit_occurrence_id,
        adm.admission_start__datetime,
        -- Encounter end is discharge from hospital. NULL = encounter still open.
        vo.visit_end_datetime as visit_end__datetime,
        loc.facility_id,
        -- BL-007: the ward is the admission segment's department, carried as the Tamanu id
        -- only -- resolving it to a name is a consumer-layer concern, same convention as
        -- facility_id (BL-009). Nullable: an admission segment recorded with no department
        -- stays NULL rather than being excluded.
        adm.department_id as admission_ward_id,
        pr.gender_source_value as sex,
        -- BL-005: visit-level concept 262 ('Emergency Room and Inpatient Visit') marks an
        -- admission that had a prior ED/triage/observation phase; it exists only at visit
        -- grain.
        coalesce(vo.visit_concept_id = 262, false) as is_admitted_via_emergency,
        -- BL-012: how the patient arrived, from the encounter's referral source.
        admission_source_ref.name as admission_source_raw,
        -- BL-014: how the encounter ended.
        disposition.name as discharge_disposition_raw,
        pdx.condition_source_value as principal_diagnosis_code,
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    adm.admission_start__datetime::date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years,
        -- BL-015: total time as an inpatient -- admission to discharge from hospital. NULL
        -- while the encounter is open.
        case
            when vo.visit_end_datetime is null then null
            else extract(epoch from (
                    vo.visit_end_datetime - adm.admission_start__datetime
                ))::bigint
        end as length_of_stay__seconds
    from admission_segments adm
    join person pr
        on pr.person_id = adm.person_id
    join visit_occurrence vo
        on vo.visit_occurrence_id = adm.visit_occurrence_id
    -- BL-007: facility is the admission segment's location. Inner join, so an admission whose
    -- location does not resolve is excluded rather than attributed to a NULL facility.
    join locations loc
        on loc.id = adm.care_site_id
    -- BL-012: the referral source lives on the encounter, not on clinical__visit_occurrence.
    join encounters enc
        on enc.id = adm.visit_occurrence_id
    -- BL-012: left join -- an admission with no referral source still counts.
    left join reference_data admission_source_ref
        on admission_source_ref.id = enc.referral_source_id
    -- BL-014: left join -- an admission with no discharge record still counts. bases/discharges
    -- is `distinct on (encounter_id)`, so it holds one row per encounter and cannot fan out.
    left join discharges dis
        on dis.encounter_id = adm.visit_occurrence_id
    left join reference_data disposition
        on disposition.id = dis.disposition_id
    -- BL-013: left join -- an admission with no principal diagnosis still counts. Ranked to
    -- one row per encounter above, so this cannot fan out.
    left join principal_diagnoses pdx
        on pdx.visit_occurrence_id = adm.visit_occurrence_id
        and pdx.diagnosis_rank = 1
    -- BL-010: no facilities.is_sensitive filter, so this covers standard and sensitive
    -- facilities alike.
    where adm.admission_rank = 1
)

select
    visit_occurrence_id,
    admission_start__datetime,
    visit_end__datetime,
    facility_id,
    admission_ward_id,
    sex,
    age_years,
    is_admitted_via_emergency,
    -- BL-012: 'Not recorded' covers an admission with no referral source. Never NULL -- the
    -- data tables expose this as an array filter, and Tupaia's array filter drops NULL rows.
    coalesce(admission_source_raw, 'Not recorded') as admission_source,
    length_of_stay__seconds,
    -- BL-015: length of stay as minutes, to two decimal places -- 0.6-second resolution, finer
    -- than any reporting need, and a fixed scale so the value is stable to compare.
    round(length_of_stay__seconds / 60.0, 2) as length_of_stay__minutes,
    principal_diagnosis_code,
    -- BL-014: 'Not recorded' covers an admission with no discharge record. Never NULL, for the
    -- same reason as admission_source.
    coalesce(discharge_disposition_raw, 'Not recorded') as discharge_disposition
from admissions
), inpatient_admission as (
    select * from __dbt__cte__int__inpatient_admission
)

-- BL-005: whether the admission arrived via the emergency department is a disaggregation
-- column, so a consumer groups by it, filters to it, or ignores it.

-- BL-006: the model emits counts. A rate -- e.g. the share of admissions arriving via the ED
-- -- is sum(value_numeric) filter (where is_admitted_via_emergency) / sum(value_numeric),
-- formed at whatever grain the consumer groups to.

-- BL-002: every admission is emitted, including today's. A consumer needing whole periods
-- only applies its own date filter.

-- D5 wide format: value_boolean is unused by this metric.
--
-- BL-009: facility and ward are emitted as the Tamanu ids only. Translating them to a
-- consumer's own identifier is a consumer-layer concern and is done there, not here.
select
    'inpatient_admission'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    -- BL-002: minute grain, from becoming an inpatient to discharge from hospital.
    -- period_end is NULL while the encounter is open.
    admission_start__datetime as period_start,
    visit_end__datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-011: one admission per row, so the count contribution is always 1. Additive, so a
    -- data table summing it is correct at every grain.
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-004: age in whole years at admission.
    -- Unbanded -- an age classification is a presentation choice a deployment may set
    -- differently, so the consumer's data table bands it.
    age_years,
    -- BL-007: the ward (department) the patient was admitted to, as the Tamanu id.
    admission_ward_id,
    -- BL-012
    admission_source,
    -- BL-005
    is_admitted_via_emergency,
    -- BL-013
    case
        when principal_diagnosis_code is null then 'Not recorded'
        else 

    case
        when left(upper(principal_diagnosis_code), 3) between 'A00' and 'B99' then 'I Certain infectious and parasitic diseases'
        when left(upper(principal_diagnosis_code), 3) between 'C00' and 'D48' then 'II Neoplasms'
        when left(upper(principal_diagnosis_code), 3) between 'D50' and 'D89' then 'III Diseases of the blood and blood-forming organs and certain disorders involving the immune mechanism'
        when left(upper(principal_diagnosis_code), 3) between 'E00' and 'E90' then 'IV Endocrine, nutritional and metabolic diseases'
        when left(upper(principal_diagnosis_code), 3) between 'F00' and 'F99' then 'V Mental and behavioural disorders'
        when left(upper(principal_diagnosis_code), 3) between 'G00' and 'G99' then 'VI Diseases of the nervous system'
        when left(upper(principal_diagnosis_code), 3) between 'H00' and 'H59' then 'VII Diseases of the eye and adnexa'
        when left(upper(principal_diagnosis_code), 3) between 'H60' and 'H95' then 'VIII Diseases of the ear and mastoid process'
        when left(upper(principal_diagnosis_code), 3) between 'I00' and 'I99' then 'IX Diseases of the circulatory system'
        when left(upper(principal_diagnosis_code), 3) between 'J00' and 'J99' then 'X Diseases of the respiratory system'
        when left(upper(principal_diagnosis_code), 3) between 'K00' and 'K93' then 'XI Diseases of the digestive system'
        when left(upper(principal_diagnosis_code), 3) between 'L00' and 'L99' then 'XII Diseases of the skin and subcutaneous tissue'
        when left(upper(principal_diagnosis_code), 3) between 'M00' and 'M99' then 'XIII Diseases of the musculoskeletal system and connective tissue'
        when left(upper(principal_diagnosis_code), 3) between 'N00' and 'N99' then 'XIV Diseases of the genitourinary system'
        when left(upper(principal_diagnosis_code), 3) between 'O00' and 'O99' then 'XV Pregnancy, childbirth and the puerperium'
        when left(upper(principal_diagnosis_code), 3) between 'P00' and 'P96' then 'XVI Certain conditions originating in the perinatal period'
        when left(upper(principal_diagnosis_code), 3) between 'Q00' and 'Q99' then 'XVII Congenital malformations, deformations and chromosomal abnormalities'
        when left(upper(principal_diagnosis_code), 3) between 'R00' and 'R99' then 'XVIII Symptoms, signs and abnormal clinical and laboratory findings, not elsewhere classified'
        when left(upper(principal_diagnosis_code), 3) between 'S00' and 'T98' then 'XIX Injury, poisoning and certain other consequences of external causes'
        when left(upper(principal_diagnosis_code), 3) between 'U00' and 'U99' then 'XXII Codes for special purposes'
        when left(upper(principal_diagnosis_code), 3) between 'V01' and 'Y98' then 'XX External causes of morbidity and mortality'
        when left(upper(principal_diagnosis_code), 3) between 'Z00' and 'Z99' then 'XXI Factors influencing health status and contact with health services'
        else 'Unclassified'
    end

    end as principal_diagnosis__icd10_chapter,
    -- BL-014
    discharge_disposition,
    -- BL-015: total length of stay as an inpatient, in minutes. Unbanded, for the same
    -- reason as age.
    length_of_stay__minutes
from inpatient_admission
);
create or replace view "reporting"."metric__emergency_stay" as (
-- metric__emergency_stay -- D5 metric view for the emergency care stay indicator
-- registered in documentations/metrics/*.yml: ed_stay (MAUI-6694).
-- Spec: specs/dbt-model/metric__emergency_stay.md (BL-001..BL-017).
--
-- One row per ED stay, which is one ED attendance viewed as a span rather than an arrival:
-- period_start is arrival in the ED and period_end is departure from it, so
-- period_end - period_start is time in the ED (BL-002).
--
-- Departure is departure from the **ED**, not the end of the encounter -- for a stay that
-- ended in admission, period_end is the moment of admission (BL-002).
--
-- Shares its attendance base with metric__emergency_visit via int__emergency_visits; the
-- two differ in what they disaggregate by, not in which rows they cover.
--
-- The registry carries the definition; this model is its implementation (BL-001).

with  __dbt__cte__int__emergency_visits as (
-- int__emergency_visits -- one row per emergency department attendance, carrying every
-- attribute the emergency care metrics disaggregate by.
--
-- Shared base for metric__emergency_visit and metric__emergency_stay. Both are
-- one-row-per-attendance over the same span, so the inclusion rule, the joins and the
-- derived timings live here once rather than in each metric.
--
-- Ephemeral, so this is inlined into each consumer and materialises nothing.
--
-- Specs: specs/dbt-model/metric__emergency_visit.md,
-- specs/dbt-model/metric__emergency_stay.md

with visit_detail as (
    select * from "reporting"."clinical__visit_detail"
),

visit_occurrence as (
    select * from "reporting"."clinical__visit_occurrence"
),

person as (
    select * from "reporting"."clinical__person"
),

locations as (
    select * from "reporting"."locations"
),

encounters as (
    select * from "reporting"."encounters"
),

triages as (
    select * from "reporting"."triages"
),

discharges as (
    select * from "reporting"."discharges"
),

reference_data as (
    select * from "reporting"."reference_data"
),

condition_occurrence as (
    select * from "reporting"."clinical__condition_occurrence"
),

-- BL-013: at most one principal diagnosis per encounter. Tamanu does not stop a second
-- is_primary row being recorded, so the earliest is taken (condition_occurrence_id breaks a
-- datetime tie) -- without this the join below would fan out and duplicate an attendance.
principal_diagnoses as (
    select
        visit_occurrence_id,
        condition_source_value,
        condition_source_name,
        row_number() over (
            partition by visit_occurrence_id
            order by condition_start_datetime, condition_occurrence_id
        ) as diagnosis_rank
    from condition_occurrence
    where is_primary
),

-- BL-003: the ED intake segment of each encounter -- the first history segment whose OMOP
-- visit concept is 9203/Emergency Room Visit, covering emergency, triage and observation.
ed_intake as (
    select
        visit_occurrence_id,
        visit_detail_start_datetime,
        care_site_id
    from visit_detail
    where preceding_visit_detail_id is null
        and visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
),

-- BL-018: the first time the patient's location leaves the ED. A segment boundary is not by
-- itself a departure: an encounter_type change to admission closes the intake segment while
-- the patient is still physically in the emergency department, which is the boarding case a
-- four-hour measure exists to expose. Only a change of care_site is a physical departure.
ed_location_exits as (
    select
        later.visit_occurrence_id,
        min(later.visit_detail_start_datetime) as ed_location_exit__datetime
    from visit_detail later
    join ed_intake i
        on i.visit_occurrence_id = later.visit_occurrence_id
    where later.visit_detail_start_datetime > i.visit_detail_start_datetime
        and later.care_site_id is distinct from i.care_site_id
    group by later.visit_occurrence_id
),

-- BL-003: one row per attendance, attributed to that intake segment.
attendances as (
    select
        -- BL-011: the encounter id is the subject. One intake segment per encounter, so this
        -- is unique across the rows emitted here.
        vd.visit_occurrence_id,
        vd.visit_detail_start_datetime as ed_start__datetime,
        -- BL-018: departure from the emergency department, taken as the earliest signal that
        -- the patient left: the first move to another location, or the time a booked transfer
        -- takes effect. least() ignores NULLs, so whichever exists wins and the earlier wins
        -- when both do. Falling through to the encounter end covers a discharge straight from
        -- the ED and any encounter that never moved.
        coalesce(
            least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
            vo.visit_end_datetime
        ) as ed_end__datetime,
        -- Encounter end is discharge from hospital, so for an admitted patient it is later
        -- than the ED departure. NULL = encounter still open.
        vo.visit_end_datetime as visit_end__datetime,
        loc.facility_id,
        pr.gender_source_value as sex,
        -- BL-005: visit-level concept 262 ('Emergency Room and Inpatient Visit') is the
        -- admitted episode-end status; it exists only at visit grain.
        coalesce(vo.visit_concept_id = 262, false) as is_admitted,
        -- BL-012: the triage practitioner's acuity category, '1' to '5'
        tr.score as triage_score_raw,
        -- BL-014: waiting time is triage to the start of active care, which is when the
        -- triage is closed. A time recorded before the triage is unusable.
        case
            when tr.closed_datetime < tr.triage_datetime then null
            else extract(epoch from (tr.closed_datetime - tr.triage_datetime))::bigint
        end as waiting_time__seconds,
        -- BL-015: time in the ED -- arrival to the departure resolved by BL-018. NULL only
        -- while the patient is in the ED and the encounter is still open.
        case
            when coalesce(
                    least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
                    vo.visit_end_datetime
                ) is null then null
            else extract(epoch from (
                    coalesce(
                        least(x.ed_location_exit__datetime, enc.planned_location_start_datetime),
                        vo.visit_end_datetime
                    ) - vd.visit_detail_start_datetime
                ))::bigint
        end as ed_time__seconds,
        -- BL-015: total length of stay -- arrival to discharge from hospital, so it spans the
        -- inpatient episode for an admitted patient. NULL while the encounter is open.
        case
            when vo.visit_end_datetime is null then null
            else extract(epoch from (
                    vo.visit_end_datetime - vd.visit_detail_start_datetime
                ))::bigint
        end as length_of_stay__seconds,
        -- BL-017: how the encounter ended. Encounter-grained, not ED-grained -- for an
        -- attendance that was admitted this is the eventual hospital discharge.
        disposition.name as discharge_disposition_raw,
        -- BL-013: raw code and reference-data name, ungrouped -- classifying either one (an
        -- ICD-10 chapter or any other grouping) is a presentation choice a deployment may set
        -- differently, so that happens at the deployment layer, the same division as age_years
        -- (BL-019).
        pdx.condition_source_value as principal_diagnosis_code,
        pdx.condition_source_name as principal_diagnosis,
        case
            when pr.year_of_birth is not null then
                extract(year from age(
                    vd.visit_detail_start_date,
                    make_date(pr.year_of_birth, pr.month_of_birth, pr.day_of_birth)
                ))::int
        end as age_years
    from visit_detail vd
    join person pr
        on pr.person_id = vd.person_id
    join visit_occurrence vo
        on vo.visit_occurrence_id = vd.visit_occurrence_id
    -- BL-007: facility is the intake segment's location. Inner join, so an encounter whose
    -- location does not resolve is excluded rather than attributed to a NULL facility.
    join locations loc
        on loc.id = vd.care_site_id
    -- BL-018: the booked transfer, one of the two departure signals. encounters.id is the
    -- primary key, so this yields one row per attendance.
    join encounters enc
        on enc.id = vd.visit_occurrence_id
    -- BL-018: the physical departure, where one has been recorded. Grouped to one row per
    -- encounter above, so it cannot fan out.
    left join ed_location_exits x
        on x.visit_occurrence_id = vd.visit_occurrence_id
    -- BL-012: left join -- an attendance with no triage record still counts. Tamanu records
    -- at most one triage per encounter, so this does not fan out; each metric's grain test is
    -- the backstop if that ever stops holding.
    left join triages tr
        on tr.encounter_id = vd.visit_occurrence_id
    -- BL-013: left join -- an attendance with no principal diagnosis still counts. Ranked to
    -- one row per encounter above, so this cannot fan out.
    left join principal_diagnoses pdx
        on pdx.visit_occurrence_id = vd.visit_occurrence_id
        and pdx.diagnosis_rank = 1
    -- BL-017: left join -- an attendance with no discharge record still counts. bases/discharges
    -- is `distinct on (encounter_id)`, so it holds one row per encounter and cannot fan out.
    left join discharges dis
        on dis.encounter_id = vd.visit_occurrence_id
    left join reference_data disposition
        on disposition.id = dis.disposition_id
    -- BL-010: no facilities.is_sensitive filter, so this covers standard and sensitive
    -- facilities alike.
    where vd.preceding_visit_detail_id is null
        and vd.visit_detail_concept_id = 9203 -- OMOP 'Emergency Room Visit'
)

select
    visit_occurrence_id,
    ed_start__datetime,
    ed_end__datetime,
    visit_end__datetime,
    facility_id,
    sex,
    age_years,
    is_admitted,
    waiting_time__seconds,
    -- BL-014: the wait as minutes, to two decimal places -- 0.6-second resolution, finer
    -- than any reporting need, and a fixed scale so the value is stable to compare. Minutes
    -- from whole seconds is a repeating decimal, so some scale has to be chosen.
    -- NULL until the patient reaches active care.
    round(waiting_time__seconds / 60.0, 2) as waiting_time__minutes,
    ed_time__seconds,
    -- BL-015: time in the ED as minutes, to two decimal places, on the same basis as
    -- waiting_time__minutes. NULL only while the patient is in the ED with nothing booked.
    round(ed_time__seconds / 60.0, 2) as ed_time__minutes,
    length_of_stay__seconds,
    -- BL-015: total length of stay as minutes, on the same basis as the other durations
    round(length_of_stay__seconds / 60.0, 2) as length_of_stay__minutes,
    principal_diagnosis_code,
    principal_diagnosis,
    -- BL-012: 'Not recorded' covers both an attendance with no triage row and a triage row
    -- with a blank score. Never NULL -- the data tables expose these as array filters, and
    -- Tupaia's array filter drops NULL rows.
    coalesce(triage_score_raw, 'Not recorded') as triage_score,
    -- BL-017
    coalesce(discharge_disposition_raw, 'Not recorded') as discharge_disposition,
    -- BL-016: hour of the day the patient arrived, 0-23. Tamanu stores naive timestamps in
    -- the deployment's central timezone (var('timezone'), see to_user_selected_timezone), so
    -- this is already a local hour and needs no conversion. A deployment spanning timezones
    -- gets the central zone's hour, not each facility's.
    extract(hour from ed_start__datetime)::int as ed_start__hour
-- BL-019: no banding here. A four-hour split and an age classification are both presentation
-- choices a deployment may set differently, so the metrics emit the continuous value and the
-- consumer's data table bands it.
from attendances
), ed_visits as (
    select * from __dbt__cte__int__emergency_visits
)

-- BL-006: the model emits counts. A mean or median time in the ED is
-- period_end - period_start aggregated at whatever grain the consumer groups to -- an
-- interval is not additive, so no duration column is emitted.

-- D5 wide format: value_boolean is unused by this metric.
--
-- BL-009: facility is emitted as the Tamanu facility_id only.
select
    'ed_stay'::text as metric_id,
    null::text as variant_id,
    visit_occurrence_id::varchar as subject_id,
    -- BL-002: minute grain, arrival in the ED to departure from it -- whether that departure
    -- is an internal transfer to an inpatient bed or a discharge straight from the ED.
    -- period_end is NULL while the patient is still in the ED.
    ed_start__datetime as period_start,
    ed_end__datetime as period_end,
    'minute'::text as period_granularity,
    -- BL-011: one stay per row, so the count contribution is always 1
    1::numeric as value_numeric,
    null::boolean as value_boolean,
    facility_id,
    sex,
    -- BL-004: age in whole years at arrival. Unbanded -- an age classification is a
    -- presentation choice a deployment may set differently, so the data table bands it
    -- (metric__emergency_visit.md BL-019).
    age_years,
    triage_score,
    -- BL-015: time in the ED in minutes. Unbanded, for the same reason as age.
    ed_time__minutes,
    -- BL-017: how the encounter ended. Encounter-grained, so for a stay that was admitted
    -- this is the eventual hospital discharge, not the ED departure.
    discharge_disposition
from ed_visits
);
create or replace view "reporting"."clinical__observation_period" as (
-- clinical__observation_period -- OMOP-lite OBSERVATION_PERIOD domain. One row per
-- patient with recorded clinical activity (BL-001) and bounds are the min/max event
-- dates across the five event domains (BL-002), per the OMOP EHR convention.
-- See specs/dbt-model/clinical__observation_period.md for BL-001..BL-005.

with visits as materialized (
    -- single scan of clinical__visit_occurrence -- both start and end feed
    -- event_dates below, without referencing the ref() twice
    select
        person_id,
        visit_start_date,
        visit_end_date
    from "reporting"."clinical__visit_occurrence"
),

drug_exposures as materialized (
    -- single scan of clinical__drug_exposure -- the domain carries no end-date
    -- column so the end datetime is cast to date here instead (BL-002)
    select
        person_id,
        drug_exposure_start_date,
        drug_exposure_end_datetime::date as drug_exposure_end_date
    from "reporting"."clinical__drug_exposure"
),

event_dates as (
    select
        person_id,
        visit_start_date as event_date
    from visits
    where visit_start_date is not null

    union all

    -- closed-visit ends bound the period too (BL-002) and open visits
    -- contribute only their start
    select
        person_id,
        visit_end_date as event_date
    from visits
    where visit_end_date is not null

    union all

    select
        person_id,
        condition_start_date as event_date
    from "reporting"."clinical__condition_occurrence"
    where condition_start_date is not null

    union all

    select
        person_id,
        measurement_date as event_date
    from "reporting"."clinical__measurement"
    where measurement_date is not null

    union all

    select
        person_id,
        drug_exposure_start_date as event_date
    from drug_exposures
    where drug_exposure_start_date is not null

    union all

    select
        person_id,
        drug_exposure_end_date as event_date
    from drug_exposures
    where drug_exposure_end_date is not null

    union all

    select
        person_id,
        observation_date as event_date
    from "reporting"."clinical__observation"
    where observation_date is not null
)

select
    -- one period per person: the person key is the natural period key (BL-003)
    person_id as observation_period_id,
    person_id,
    min(event_date) as observation_period_start_date,  -- BL-002
    max(event_date) as observation_period_end_date,    -- BL-002
    -- 44814724 = "Period covering healthcare encounters" (BL-004)
    44814724 as period_type_concept_id
-- no outer join to clinical__person and an event-less patient contributes no
-- rows here, so it is correctly absent from the output (BL-005)
from event_dates
group by person_id
);