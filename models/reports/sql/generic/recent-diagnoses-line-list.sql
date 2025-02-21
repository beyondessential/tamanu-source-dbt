select
    to_char(diagnosis_datetime, '{{ var("datetime_format") }}') as "{{ translate_string('', 'Date & time') }}",
    diagnosis as "{{ translate_string('general.diagnosis.label', 'Diagnosis') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label', 'First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', 'Last name') }}",
    display_id as "{{ translate_string('general.localisedField.displayId.label', 'Patient ID') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    contact_number as "{{ translate_string('', 'Contact number') }}",
    village as "{{ translate_string('general.localisedField.villageId.label', 'Village') }}",
    clinician as "{{ translate_string('', 'Clinician') }}",
    department as "{{ translate_string('general.localisedField.departmentId.label', 'Department') }}",
    certainty as "{{ translate_string('diagnosis.certainty.label', 'Certainty') }}",
    is_primary as "{{ translate_string('diagnosis.isPrimary.label', 'Is primary') }}"
from {{ ref('ds__diagnoses') }}
where
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else diagnosis_datetime::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else diagnosis_datetime::date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when{{ parameter('facilityId') }} is null then true
        else facility_id ={{ parameter('facilityId') }}
    end
    and
    case
        when{{ parameter('villageId') }} is null then true
        else village_id ={{ parameter('villageId') }}
    end
    and
    case
        when{{ parameter('clinicianId') }} is null then true
        else clinician_id ={{ parameter('clinicianId') }}
    end
    and
    case when
            coalesce(                                {{ parameter('diagnosisId') }}, {{ parameter('diagnosis2Id') }}, {{ parameter('diagnosis3Id') }}, {{ parameter('diagnosis4Id') }}, {{ parameter('diagnosis5Id') }}
            ) is null
            then true
        else diagnosis_id in (                                    {{ parameter('diagnosisId') }}, {{ parameter('diagnosis2Id') }}, {{ parameter('diagnosis3Id') }}, {{ parameter('diagnosis4Id') }}, {{ parameter('diagnosis5Id') }}
            )
    end
