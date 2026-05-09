select
    to_char({{ to_user_selected_timezone('diagnosis_datetime') }}, '{{ var("datetime_format") }}') as "{{ translate_label('diagnosisDateTime') }}",
    diagnosis as "{{ translate_label('diagnoses') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    display_id as "{{ translate_label('patientDisplayId') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    contact_number as "{{ translate_label('patientPrimaryContactNumber') }}",
    village as "{{ translate_label('patientVillage') }}",
    clinician as "{{ translate_label('encounterClinician') }}",
    department as "{{ translate_label('department') }}",
    certainty as "{{ translate_label('diagnosisCertainty') }}",
    is_primary as "{{ translate_label('diagnosisIsPrimary') }}"
from {{ ref('ds__diagnoses') }}
where
    {{ to_user_selected_timezone('diagnosis_datetime') }}
        >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    and
    {{ to_user_selected_timezone('diagnosis_datetime') }}
        <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
    and
    case
        when {{ parameter('villageId') }} is null then true
        else village_id = {{ parameter('villageId') }}
    end
    and
    case
        when {{ parameter('clinicianId') }} is null then true
        else clinician_id = {{ parameter('clinicianId') }}
    end
    and
    case when
            coalesce({{ parameter('diagnosisId') }}, {{ parameter('diagnosis2Id') }}, {{ parameter('diagnosis3Id') }}, {{ parameter('diagnosis4Id') }}, {{ parameter('diagnosis5Id') }}) is null
            then true
        else diagnosis_id in (
                {{ parameter('diagnosisId') }},
                {{ parameter('diagnosis2Id') }},
                {{ parameter('diagnosis3Id') }},
                {{ parameter('diagnosis4Id') }},
                {{ parameter('diagnosis5Id') }}
            )
    end
order by diagnosis_datetime desc
