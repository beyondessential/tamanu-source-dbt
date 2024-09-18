CREATE SCHEMA IF NOT EXISTS reporting;

ALTER DEFAULT PRIVILEGES IN SCHEMA reporting GRANT SELECT ON TABLES TO tamanu_reporting;

CREATE OR REPLACE VIEW "reporting"."appointments" AS (
SELECT
    id,
    start_time AS start_datetime,
    end_time AS end_datetime,
    patient_id,
    clinician_id,
    location_id,
    location_group_id,
    type,
    status
FROM "public"."appointments"
WHERE deleted_at IS NULL
    AND patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3');

CREATE OR REPLACE VIEW "reporting"."departments" AS (
SELECT
    id,
    code,
    name,
    facility_id,
    visibility_status
FROM "public"."departments"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."discharges" AS (
SELECT
    id,
    note,
    encounter_id,
    discharger_id AS discharged_by_id,
    disposition_id
FROM "public"."discharges"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."encounters" AS (
SELECT
    id,
    start_date AS start_datetime,
    CASE WHEN end_date < start_date THEN start_date
         ELSE end_date
    END AS end_datetime,
    encounter_type,
    reason_for_encounter,
    device_id,
    patient_id,
    department_id
    location_id,
    examiner_id AS clinician_id,
    patient_billing_type_id,
    referral_source_id,
    planned_location_id,
    planned_location_start_time AS planned_location_start_datetime
FROM "public"."encounters"
WHERE deleted_at IS NULL
    AND patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3');

CREATE OR REPLACE VIEW "reporting"."encounter_diagnoses" AS (
SELECT
    id,
    date AS datetime,
    is_primary,
    certainty,
    encounter_id,
    diagnosis_id,
    clinician_id AS diagnosed_by_id
FROM "public"."encounter_diagnoses"
WHERE deleted_at IS NULL
    AND certainty NOT IN ('disproven', 'error'));

CREATE OR REPLACE VIEW "reporting"."encounter_diets" AS (
SELECT
    id,
    encounter_id,
    diet_id
FROM "public"."encounter_diets"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."encounter_medications" AS (
SELECT
    id,
    date AS start_datetime,
    end_date AS end_datetime,
    prescription,
    note,
    indication,
    route,
    qty_morning,
    qty_lunch,
    qty_evening,
    qty_night,
    encounter_id,
    medication_id,
    prescriber_id AS prescribed_by_id,
    quantity,
    repeats,
    is_discharge AS is_discharged,
    discontinued AS is_discontinued,
    discontinued_date,
    discontinuing_reason,
    discontinuing_clinician_id AS discontinued_by_id
FROM "public"."encounter_medications"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."facilities" AS (
SELECT
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
    visibility_status
FROM "public"."facilities"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."imaging_area_external_codes" AS (
SELECT
    id,
    area_id,
    code,
    description,
    visibility_status
FROM "public"."imaging_area_external_codes"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."imaging_requests" AS (
SELECT
    id,
    display_id,
    requested_date AS datetime,
    status,
    priority,
    imaging_type,
    encounter_id,
    requested_by_id,
    location_group_id,
    reason_for_cancellation
FROM "public"."imaging_requests"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."imaging_request_areas" AS (
SELECT
    id,
    imaging_request_id,
    area_id
FROM "public"."imaging_request_areas"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."imaging_results" AS (
SELECT
    id,
    completed_at AS datetime,
    description,
    imaging_request_id,
    external_code,
    completed_by_id,
    visibility_status
FROM "public"."imaging_results"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."invoices" AS (
SELECT
    id,
    display_id,
    date AS datetime,
    status,
    patient_payment_status,
    insurer_payment_status,
    encounter_id
FROM "public"."invoices"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."invoice_discounts" AS (
SELECT
    id,
    applied_time AS datetime,
    invoice_id,
    percentage,
    reason,
    is_manual,
    applied_by_user_id AS applied_by_id
FROM "public"."invoice_discounts"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."invoice_insurers" AS (
SELECT
    id,
    invoice_id,
    insurer_id,
    percentage
FROM "public"."invoice_insurers"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."invoice_insurer_payments" AS (
SELECT
    id,
    invoice_payment_id,
    insurer_id,
    status,
    reason
FROM "public"."invoice_insurer_payments"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."invoice_items" AS (
SELECT
    id,
    invoice_id,
    order_date AS date,
    product_id,
    product_code,
    note,
    product_discountable,
    quantity,
    product_price,
    ordered_by_user_id AS ordered_by_id,
    source_id
FROM "public"."invoice_items"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."invoice_item_discounts" AS (
SELECT
    id,
    invoice_item_id,
    percentage,
    reason
FROM "public"."invoice_item_discounts"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."invoice_patient_payments" AS (
SELECT
    id,
    invoice_payment_id,
    method_id
FROM "public"."invoice_patient_payments"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."invoice_payments" AS (
SELECT
    id,
    invoice_id,
    date,
    receipt_number,
    amount
FROM "public"."invoice_payments"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."invoice_products" AS (
SELECT
    id,
    name,
    price,
    discountable,
    visibility_status
FROM "public"."invoice_products"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."lab_requests" AS (
SELECT
    id,
    display_id,
    status,
    requested_date AS requested_datetime,
    lab_test_priority_id,
    lab_test_category_id,
    lab_test_panel_request_id,
    lab_test_laboratory_id,
    requested_by_id,
    specimen_attached AS is_specimen_collected,
    specimen_type_id,
    lab_sample_site_id,
    sample_time AS collected_datetime,
    collected_by_id,
    reason_for_cancellation,
    published_date,
    senaite_id,
    encounter_id,
    department_id
FROM "public"."lab_requests"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."lab_tests" AS (
SELECT
    id,
    date,
    status,
    result,
    lab_request_id,
    lab_test_type_id,
    lab_test_method_id,
    laboratory_officer,
    completed_date AS completed_datetime,
    verification
FROM "public"."lab_tests"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."lab_test_panels" AS (
SELECT
    id,
    code,
    external_code,
    name,
    category_id,
    visibility_status
FROM "public"."lab_test_panels"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."lab_test_panel_lab_test_types" AS (
SELECT
    id,
    lab_test_panel_id,
    lab_test_type_id
FROM "public"."lab_test_panel_lab_test_types"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."lab_test_panel_requests" AS (
SELECT
    id,
    lab_test_panel_id,
    encounter_id
FROM "public"."lab_test_panel_requests"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."lab_test_types" AS (
SELECT
    id,
    code,
    name,
    unit,
    male_min,
    male_max,
    female_min,
    female_max,
    range_text
    result_type,
    options,
    lab_test_category_id,
    visibility_status
FROM "public"."lab_test_types"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."locations" AS (
SELECT
    id,
    code,
    name,
    max_occupancy,
    location_group_id,
    facility_id,
    visibility_status
FROM "public"."locations"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."location_groups" AS (
SELECT
    id,
    code,
    name,
    visibility_status
FROM "public"."location_groups"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."notes" AS (
SELECT
    id,
    date AS datetime,
    content,
    note_type,
    record_type,
    record_id,
    author_id AS authored_by_id,
    on_behalf_of_id,
    revised_by_id AS updated_note_id,
    visibility_status
FROM "public"."notes"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."patients" AS (
SELECT
    id,
    display_id,
    first_name,
    middle_name,
    last_name,
    cultural_name,
    email,
    sex,
    date_of_birth,
    date_of_death,
    village_id
FROM "public"."patients"
WHERE deleted_at IS NULL
    AND id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
    AND visibility_status != 'merged');

CREATE OR REPLACE VIEW "reporting"."patient_additional_data" AS (
SELECT
    id,
    title,
    marital_status,
    primary_contact_number,
    secondary_contact_number,
    street_village,
    birth_certificate,
    country_of_birth_id,
    driving_license,
    passport,
    blood_type,
    ethnicity_id,
    nationality_id,
    occupation_id,
    religion_id,
    patient_billing_type_id,
    mother_id,
    father_id,
    registered_by_id
FROM "public"."patient_additional_data"
WHERE deleted_at IS NULL
    AND id != 'h1627394-3778-4c31-a510-9fcb88efdbf3');

CREATE OR REPLACE VIEW "reporting"."patient_birth_data" AS (
SELECT
    id,
    RIGHT(time_of_birth, 8) AS birth_time,
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
    birth_facility_id
FROM "public"."patient_birth_data"
WHERE deleted_at IS NULL
    AND id != 'h1627394-3778-4c31-a510-9fcb88efdbf3');

CREATE OR REPLACE VIEW "reporting"."patient_conditions" AS (
SELECT
    id,
    recorded_date AS recorded_datetime,
    note,
    condition_id,
    patient_id,
    examiner_id AS recorded_by_id,
    resolved AS is_resolved,
    resolution_date AS resolved_datetime,
    resolution_practitioner_id AS resolved_by_id,
    resolution_note
FROM "public"."patient_conditions"
WHERE deleted_at IS NULL
    AND patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3');

CREATE OR REPLACE VIEW "reporting"."patient_death_contributing_causes" AS (
SELECT
    id,
    time_after_onset AS mins_after_onset,
    patient_death_data_id,
    condition_id
FROM "public"."contributing_death_causes"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."patient_death_data" AS (
SELECT
    id,
    manner,
    recent_surgery AS had_recent_surgery,
    last_surgery_date,
    last_surgery_reason_id,
    external_cause_date,
    external_cause_location,
    external_cause_notes,
    was_pregnant,
    pregnancy_contributed,
    fetal_or_infant AS was_fetal_or_infant,
    stillborn AS was_stillborn,
    birth_weight,
    within_day_of_birth AS was_within_day_of_birth,
    hours_survived_since_birth,
    carrier_age,
    carrier_pregnancy_weeks,
    carrier_existing_condition_id,
    outside_health_facility AS was_outside_health_facility,
    primary_cause_time_after_onset,
    primary_cause_condition_id,
    antecedent_cause1_time_after_onset,
    antecedent_cause1_condition_id,
    antecedent_cause2_time_after_onset,
    antecedent_cause2_condition_id,
    antecedent_cause3_time_after_onset,
    antecedent_cause3_condition_id,
    patient_id,
    clinician_id AS recorded_by_id,
    facility_id,
    is_final,
    visibility_status
FROM "public"."patient_death_data"
WHERE deleted_at IS NULL
    AND patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3');

CREATE OR REPLACE VIEW "reporting"."patient_program_registrations" AS (
SELECT
    id,
    date AS datetime,
    registration_status,
    patient_id,
    program_registry_id,
    clinical_status_id,
    clinician_id AS registered_by_id,
    registering_facility_id,
    facility_id,
    village_id,
    is_most_recent
FROM "public"."patient_program_registrations"
WHERE deleted_at IS NULL
    AND patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3');

CREATE OR REPLACE VIEW "reporting"."patient_program_registration_conditions" AS (
SELECT
    id,
    date AS datetime,
    program_registry_condition_id,
    patient_id,
    program_registry_id,
    clinician_id AS recorded_by_id,
    deletion_date AS deleted_datetime,
    deletion_clinician_id AS deleted_by_id
FROM "public"."patient_program_registration_conditions"
WHERE deleted_at IS NULL
    AND patient_id != 'h1627394-3778-4c31-a510-9fcb88efdbf3');

CREATE OR REPLACE VIEW "reporting"."procedures" AS (
SELECT
    id,
    start_time AS start_datetime,
    end_time AS end_datetime,
    completed AS is_completed,
    note,
    completed_note,
    encounter_id,
    location_id,
    procedure_type_id,
    anaesthetic_id,
    physician_id AS clinician_id,
    assistant_id,
    anaesthetist_id
FROM "public"."procedures"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."programs" AS (
SELECT
    id,
    code,
    name
FROM "public"."programs"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."program_data_elements" AS (
SELECT
    id,
    code,
    name,
    type,
    indicator,
    default_text,
    default_options,
    visualisation_config
FROM "public"."program_data_elements"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."program_registries" AS (
SELECT
    id,
    code,
    name,
    currently_at_type,
    visibility_status,
    program_id
FROM "public"."program_registries"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."program_registry_clinical_statuses" AS (
SELECT
    id,
    code,
    name,
    color,
    visibility_status,
    program_registry_id
FROM "public"."program_registry_clinical_statuses"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."program_registry_conditions" AS (
SELECT
    id,
    code,
    name,
    visibility_status,
    program_registry_id
FROM "public"."program_registry_conditions"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."reference_data" AS (
SELECT
    id,
    code,
    name,
    type,
    visibility_status
FROM "public"."reference_data"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."referrals" AS (
SELECT
    id,
    status,
    referred_facility,
    initiating_encounter_id,
    completing_encounter_id,
    survey_response_id
FROM "public"."referrals"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."surveys" AS (
SELECT
    id,
    code,
    name,
    survey_type,
    is_sensitive,
    notifiable AS is_notifiable,
    notify_email_addresses,
    program_id,
    visibility_status
FROM "public"."surveys"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."survey_responses" AS (
SELECT
    id,
    start_time AS start_datetime,
    end_time AS end_datetime,
    result_text,
    notified AS is_notified,
    survey_id,
    encounter_id,
    user_id AS submitted_by_id
FROM "public"."survey_responses"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."survey_response_answers" AS (
SELECT
    id,
    name,
    body,
    response_id,
    data_element_id
FROM "public"."survey_response_answers"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."survey_screen_components" AS (
SELECT
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
FROM "public"."survey_screen_components"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."triages" AS (
SELECT
    id,
    arrival_time AS arrival_datetime,
    triage_time AS triage_datetime,
    closed_time AS closed_datetime,
    score,
    encounter_id,
    practitioner_id AS clinician_id,
    chief_complaint_id,
    secondary_complaint_id
FROM "public"."triages"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."users" AS (
SELECT
    id,
    display_id,
    display_name,
    email,
    phone_number,
    role,
    visibility_status
FROM "public"."users"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."vaccine_administrations" AS (
SELECT
    id,
    date AS datetime,
    encounter_id,
    location_id,
    department_id,
    scheduled_vaccine_id,
    status,
    reason,
    not_given_reason_id,
    batch,
    vaccine_name,
    vaccine_brand,
    disease,
    consent AS is_consented,
    consent_given_by,
    injection_site,
    given_by,
    given_elsewhere AS is_given_elsewhere,
    circumstance_ids,
    recorder_id
FROM "public"."administered_vaccines"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."vaccine_schedules" AS (
SELECT
    id,
    category,
    vaccine_id,
    label,
    dose_label,
    index,
    weeks_from_birth_due,
    weeks_from_last_vaccination_due,
    visibility_status
FROM "public"."scheduled_vaccines"
WHERE deleted_at IS NULL);

CREATE OR REPLACE VIEW "reporting"."ds__patient_vaccination__upcoming" AS (
SELECT
    patient_id,
    scheduled_vaccine_id AS vaccine_schedules_id,
    vaccine_category,
    vaccine_id,
    due_date,
    days_till_due,
    status
FROM "public"."upcoming_vaccinations");

CREATE OR REPLACE VIEW "reporting"."encounter_logs" AS (
SELECT
    eh.id,
    CASE WHEN eh.date < e.start_datetime THEN e.start_datetime
         ELSE eh.date
    END AS start_datetime,
    COALESCE(LEAD(eh.date) OVER (PARTITION BY eh.encounter_id ORDER BY eh.date), e.end_datetime) AS end_datetime,
    eh.encounter_id,
    eh.department_id,
    eh.location_id,
    eh.examiner_id,
    eh.encounter_type,
    eh.actor_id AS updated_by,
    eh.change_type
FROM "public"."encounter_history" eh
JOIN "tamanu_sync"."juliana_reporting"."encounters" e ON e.id = eh.encounter_id
WHERE eh.deleted_at IS NULL);
