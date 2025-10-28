{%- set columns = [
    {'expr': "fc.record_data ->> 'title'", 'name': 'title', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'marital_status'", 'name': 'marital_status', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'primary_contact_number'", 'name': 'primary_contact_number', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'secondary_contact_number'", 'name': 'secondary_contact_number', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'emergency_contact_name'", 'name': 'emergency_contact_name', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'emergency_contact_number'", 'name': 'emergency_contact_number', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'social_media'", 'name': 'social_media', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'ethnicity_id'", 'name': 'ethnicity_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'religion_id'", 'name': 'religion_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'nationality_id'", 'name': 'nationality_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'secondary_village_id'", 'name': 'secondary_village_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'country_id'", 'name': 'country_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'division_id'", 'name': 'division_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'subdivision_id'", 'name': 'subdivision_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'medical_area_id'", 'name': 'medical_area_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'nursing_zone_id'", 'name': 'nursing_zone_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'settlement_id'", 'name': 'settlement_id', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'city_town'", 'name': 'city_town', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'street_village'", 'name': 'street_village', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'country_of_birth_id'", 'name': 'country_of_birth_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'place_of_birth'", 'name': 'place_of_birth', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'birth_certificate'", 'name': 'birth_certificate', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'driving_license'", 'name': 'driving_license', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'passport'", 'name': 'passport', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'educational_level'", 'name': 'educational_level', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'occupation_id'", 'name': 'occupation_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'blood_type'", 'name': 'blood_type', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'patient_billing_type_id'", 'name': 'patient_billing_type_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'health_center_id'", 'name': 'health_center_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'insurer_id'", 'name': 'insurer_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'insurer_policy_number'", 'name': 'insurer_policy_number', 'is_direct_identifier': true},
    {'expr': "fc.record_data ->> 'mother_id'", 'name': 'mother_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'father_id'", 'name': 'father_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data ->> 'registered_by_id'", 'name': 'registered_by_id', 'is_direct_identifier': false},
    {'expr': "fc.record_data -> 'updated_at_by_field'", 'name': 'updated_by_field', 'is_direct_identifier': false},
    {'expr': "(fc.record_data ->> 'created_at')::date", 'name': 'registration_date', 'is_direct_identifier': false}
] -%}

with filtered_changes as (
    {{ base_history_from_log('patient_additional_data') }}
        and record_id != '{{ var("test_patient") }}' -- noqa: ST10
{% if dbt_utils.get_relations_by_pattern('logs', 'changes_backup') %}
    union all
    {{ base_history_from_log('patient_additional_data', 'logs__tamanu', 'changes_backup') }}
        and record_id != '{{ var("test_patient") }}' -- noqa: ST10
{% endif %}
)

select
    fc.changelog_id,
    fc.logged_at at time zone '{{ var("timezone") }}' as logged_at,
    fc.updated_by_user_id,
    fc.record_id as patient_id
    {%- for col in columns -%}
        {%- if not (is_analytics_target() and col.is_direct_identifier) -%}
            ,
            {{ col.expr }} as {{ col.name }}
        {%- endif -%}
    {%- endfor %}
from filtered_changes fc
