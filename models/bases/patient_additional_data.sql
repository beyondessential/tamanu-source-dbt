select
    patient_id
    {%- set columns = [
        {'expr': 'title', 'name': 'title', 'is_direct_identifier': false},
        {'expr': 'marital_status', 'name': 'marital_status', 'is_direct_identifier': false},
        {'expr': 'primary_contact_number', 'name': 'primary_contact_number', 'is_direct_identifier': true},
        {'expr': 'secondary_contact_number', 'name': 'secondary_contact_number', 'is_direct_identifier': true},
        {'expr': 'emergency_contact_name', 'name': 'emergency_contact_name', 'is_direct_identifier': true},
        {'expr': 'emergency_contact_number', 'name': 'emergency_contact_number', 'is_direct_identifier': true},
        {'expr': 'social_media', 'name': 'social_media', 'is_direct_identifier': true},
        {'expr': 'ethnicity_id', 'name': 'ethnicity_id', 'is_direct_identifier': false},
        {'expr': 'religion_id', 'name': 'religion_id', 'is_direct_identifier': false},
        {'expr': 'nationality_id', 'name': 'nationality_id', 'is_direct_identifier': false},
        {'expr': 'secondary_village_id', 'name': 'secondary_village_id', 'is_direct_identifier': false},
        {'expr': 'country_id', 'name': 'country_id', 'is_direct_identifier': false},
        {'expr': 'division_id', 'name': 'division_id', 'is_direct_identifier': false},
        {'expr': 'subdivision_id', 'name': 'subdivision_id', 'is_direct_identifier': false},
        {'expr': 'medical_area_id', 'name': 'medical_area_id', 'is_direct_identifier': false},
        {'expr': 'nursing_zone_id', 'name': 'nursing_zone_id', 'is_direct_identifier': false},
        {'expr': 'settlement_id', 'name': 'settlement_id', 'is_direct_identifier': true},
        {'expr': 'city_town', 'name': 'city_town', 'is_direct_identifier': true},
        {'expr': 'street_village', 'name': 'street_village', 'is_direct_identifier': true},
        {'expr': 'country_of_birth_id', 'name': 'country_of_birth_id', 'is_direct_identifier': false},
        {'expr': 'place_of_birth', 'name': 'place_of_birth', 'is_direct_identifier': false},
        {'expr': 'birth_certificate', 'name': 'birth_certificate', 'is_direct_identifier': true},
        {'expr': 'driving_license', 'name': 'driving_license', 'is_direct_identifier': true},
        {'expr': 'passport', 'name': 'passport', 'is_direct_identifier': true},
        {'expr': 'educational_level', 'name': 'educational_level', 'is_direct_identifier': false},
        {'expr': 'occupation_id', 'name': 'occupation_id', 'is_direct_identifier': false},
        {'expr': 'blood_type', 'name': 'blood_type', 'is_direct_identifier': false},
        {'expr': 'patient_billing_type_id', 'name': 'patient_billing_type_id', 'is_direct_identifier': false},
        {'expr': 'health_center_id', 'name': 'health_center_id', 'is_direct_identifier': false},
        {'expr': 'insurer_id', 'name': 'insurer_id', 'is_direct_identifier': false},
        {'expr': 'insurer_policy_number', 'name': 'insurer_policy_number', 'is_direct_identifier': true},
        {'expr': 'mother_id', 'name': 'mother_id', 'is_direct_identifier': false},
        {'expr': 'father_id', 'name': 'father_id', 'is_direct_identifier': false},
        {'expr': 'registered_by_id', 'name': 'registered_by_id', 'is_direct_identifier': false},
        {'expr': 'updated_at_by_field', 'name': 'updated_by_field', 'is_direct_identifier': false},
        {'expr': 'created_at::date', 'name': 'registration_date', 'is_direct_identifier': false}
    ] -%}
    {%- for col in columns -%}
        {%- if not (is_analytics_target() and col.is_direct_identifier) -%}
            ,
            {{ col.expr }} as {{ col.name }}
        {%- endif -%}
    {%- endfor %}
from {{ resolve_input_model('patient_additional_data') }}
where deleted_at is null
    and id != '{{ var("test_patient") }}'
