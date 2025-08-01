select
    to_char(diagnosis_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('diagnosisDateTime', 'Date & time') }}",
    diagnosis as "{{ translate_label('diagnoses', 'Diagnoses') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    contact_number as "{{ translate_label('patientPrimaryContactNumber', 'Primary contact number') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    clinician as "{{ translate_label('encounterClinician', 'Clinician') }}",
    department as "{{ translate_label('department', 'Department') }}",
    certainty as "{{ translate_label('diagnosisCertainty', 'Certainty') }}",
    is_primary as "{{ translate_label('diagnosisIsPrimary', 'Is primary') }}"
from {{ ref('ds__diagnoses') }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else diagnosis_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else diagnosis_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
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
