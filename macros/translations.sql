{%- macro translate_label(string_id, default_column_name=null) -%}
    {%- set language = var('language') -%}
    {%- set full_string_id = 'report.reporting.' ~ string_id -%}
    
    {%- set query -%}
        select text 
        from {{ source('tamanu', 'translated_strings') }}
        where string_id = '{{ full_string_id }}' 
        and language = '{{ language }}'
    {%- endset -%}
    
    {%- set result = run_query(query) -%}
    
    {%- if execute -%}
        {%- if result.rows | length > 0 -%}
            {{- result.columns[0].values()[0] -}}
        {%- else -%}
            {{- default_column_name -}}
        {%- endif -%}
    {%- endif -%}
{%- endmacro -%}

{%- macro get_translation_prefix(prefix_key) -%}
    {%- set mapping = {
        'APPOINTMENT_STATUSES': 'appointment.property.status',
        'ATTENDANT_OF_BIRTH_LABELS': 'birth.property.attendantOfBirth',
        'ASSET_NAME_LABELS': 'asset.property.name',
        'BIRTH_DELIVERY_TYPE_LABELS': 'birth.property.birthDeliveryType',
        'BIRTH_TYPE_LABELS': 'birth.property.birthType',
        'BLOOD_LABELS': 'patient.property.blood',
        'DIAGNOSIS_CERTAINTY_LABELS': 'diagnosis.property.certainty',
        'DRUG_ROUTE_LABELS': 'medication.property.route',
        'EDUCATIONAL_ATTAINMENT_LABELS': 'patient.property.educationalAttainment',
        'ENCOUNTER_TYPE_LABELS': 'encounter.property.type',
        'IMAGING_TYPES': 'imaging.property.type',
        'IMAGING_REQUEST_STATUS_LABELS': 'imaging.property.status',
        'INJECTION_SITE_LABELS': 'vaccine.property.injectionSite',
        'INVOICE_INSURER_PAYMENT_STATUS_LABELS': 'invoice.property.insurerPaymentStatus',
        'INVOICE_ITEMS_CATEGORY_LABELS': 'invoice.property.itemCategory',
        'INVOICE_PATIENT_PAYMENT_STATUSES_LABELS': 'invoice.property.patientPaymentStatus',
        'INVOICE_STATUS_LABELS': 'invoice.property.status',
        'LAB_REQUEST_STATUS_LABELS': 'lab.property.status',
        'LOCATION_AVAILABILITY_STATUS_LABELS': 'bedManagement.property.status',
        'MANNER_OF_DEATHS': 'death.property.mannerOfDeath',
        'MARTIAL_STATUS_LABELS': 'patient.property.maritalStatus',
        'NOTE_TYPE_LABELS': 'note.property.type',
        'PATIENT_ISSUE_LABELS': 'patient.property.issue',
        'PLACE_OF_BIRTH_LABELS': 'birth.property.placeOfBirth',
        'PLACE_OF_DEATHS': 'death.property.placeOfDeath',
        'PROGRAM_REGISTRATION_STATUS_LABELS': 'programRegistry.property.registrationStatus',
        'REFERRAL_STATUS_LABELS': 'referral.property.status',
        'REPEATS_LABELS': 'medication.property.repeats',
        'REPEAT_FREQUENCY_LABELS': 'scheduling.property.repeatFrequency',
        'REPEAT_FREQUENCY_UNIT_LABELS': 'scheduling.property.repeatFrequencyUnit',
        'REPEAT_FREQUENCY_UNIT_PLURAL_LABELS': 'scheduling.property.repeatFrequencyUnitPlural',
        'REPORT_DATA_SOURCE_LABELS': 'report.property.dataSource',
        'REPORT_DB_SCHEMA_LABELS': 'report.property.schema',
        'REPORT_DEFAULT_DATE_RANGES_LABELS': 'report.property.defaultDateRange',
        'REPORT_STATUS_LABELS': 'report.property.status',
        'SEX_LABELS': 'patient.property.sex',
        'TASK_FREQUENCY_UNIT_LABELS': 'task.property.frequencyUnit',
        'TASK_DURATION_UNIT_LABELS': 'task.property.durationUnit',
        'SOCIAL_MEDIA_LABELS': 'patient.property.socialMedia',
        'TEMPLATE_TYPE_LABELS': 'template.property.type',
        'TITLE_LABELS': 'patient.property.title',
        'VACCINE_CATEGORY_LABELS': 'vaccine.property.category',
        'VACCINE_STATUS_LABELS': 'vaccine.property.status'
    } -%}
    
    {%- if prefix_key in mapping -%}
        {{- mapping[prefix_key] -}}
    {%- else -%}
        {{- '' -}}
    {%- endif -%}
{%- endmacro -%}

{%- macro translate_value(prefix_key, value) -%}
    {%- set language = var('language') -%}
    {%- set prefix = get_translation_prefix(prefix_key) -%}
    {%- set string_id = prefix ~ '.' ~ value -%}
    
    {%- set query -%}
        select text 
        from {{ source('tamanu', 'translated_strings') }}
        where string_id ilike '{{ string_id }}' 
        and language = '{{ language }}'
    {%- endset -%}
    
    {%- set result = run_query(query) -%}
    
    {%- if execute -%}
        {%- if result.rows | length > 0 -%}
            {{- result.columns[0].values()[0] -}}
        {%- else -%}
            {{- value -}}
        {%- endif -%}
    {%- endif -%}
{%- endmacro -%}

