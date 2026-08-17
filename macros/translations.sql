{%- macro translate_label(string_id, language=var("language", "default")) -%}
    {%- set full_string_id = 'report.reporting.' ~ string_id -%}
    {%- set translations = get_translations() -%}

    {%- if full_string_id in translations -%}
        {%- set lang_dict = translations[full_string_id] -%}
        {{- lang_dict.get(language, lang_dict.get('default', string_id)) -}}
    {%- elif string_id in translations -%}
        {%- set lang_dict = translations[string_id] -%}
        {{- lang_dict.get(language, lang_dict.get('default', string_id)) -}}
    {%- else -%}
        {{- string_id -}}
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

{%- macro translate_value(prefix_key, value, language=var("language", "default")) -%}
    {%- set translations = get_translations() -%}
    {%- set prefix = get_translation_prefix(prefix_key) -%}
    {%- set string_id = prefix ~ '.' ~ value -%}

    {%- if string_id in translations -%}
        {%- set lang_dict = translations[string_id] -%}
        {{- lang_dict.get(language, lang_dict.get('default', value)) -}}
    {%- else -%}
        {{- value -}}
    {%- endif -%}
{%- endmacro -%}

{%- macro translate_column_value(prefix_key, column_name, language=var("language", "default")) -%}
    {%- set translations = get_translations() -%}
    {%- set prefix = get_translation_prefix(prefix_key) -%}
    {#- a namespace is required here: a plain `set` inside the loop does not escape it -#}
    {%- set ns = namespace(has_translations=false) -%}
    {%- for string_id, lang_dict in translations.items() -%}
        {%- if string_id.startswith(prefix ~ '.') -%}
            {%- set ns.has_translations = true -%}
            {%- break -%}
        {%- endif -%}
    {%- endfor -%}
    {%- if ns.has_translations -%}
    case
    {%- for string_id, lang_dict in translations.items() -%}
        {%- if string_id.startswith(prefix ~ '.') -%}
            {%- set value = string_id.replace(prefix ~ '.', '') -%}
            {#- the tag below must not strip trailing whitespace, or the when clauses run into each other -#}
            {%- set translated_text = lang_dict.get(language, lang_dict.get('default', value)).replace("'", "''") %}
        when {{ column_name }} = '{{ value }}' then '{{ translated_text }}'
        {%- endif -%}
    {%- endfor %}
        else {{ column_name }}
    end
    {%- else -%}
    {{ column_name }}
    {%- endif -%}
{%- endmacro -%}
