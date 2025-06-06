select
    diagnosis_datetime::date as "{{ translate_label('reportingDate', 'Date') }}",
    facility as "{{ translate_label('facility', 'Facility') }}",
    legal_status as "{{ translate_label('patientLegalStatus', 'Legal status') }}",
    age_category as "{{ translate_label('patientAgeCategory', 'Age category') }}",
    appointment_type as "{{ translate_label('appointmentType', 'Appointment type') }}",
    diagnosis as "{{ translate_label('diagnoses', 'Diagnoses') }}",
    count(distinct patient_id) as "{{ translate_label('patientTotalCount', 'Total patients') }}"
from {{ ref('ds__diagnoses_msf') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else diagnosis_datetime::date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else diagnosis_datetime::date <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and case
        when {{ parameter('facilityId', default_value='null', data_type='text') }} is null
            then true
        else facility_id::text = {{ parameter('facilityId', default_value='null', data_type='text') }}
    end
    and case
        when {{ parameter('legalStatus', default_value='null', data_type='text') }} is null
            then true
        else legal_status = {{ parameter('legalStatus', default_value='null', data_type='text') }}
    end
    and case
        when {{ parameter('ageCategory', default_value='null', data_type='text') }} is null
            then true
        else age_group = {{ parameter('ageCategory', default_value='null', data_type='text') }}
    end
    and case
        when {{ parameter('diagnosisId', default_value='null', data_type='text') }} is null
            then true
        else diagnosis_id::text = {{ parameter('diagnosisId', default_value='null', data_type='text') }}
    end
    and case
        when {{ parameter('appointmentTypeId', default_value='null', data_type='text') }} is null
            then true
        else appointment_type_id::text = {{ parameter('appointmentTypeId', default_value='null', data_type='text') }}
    end
group by 
    diagnosis_datetime::date,
    facility,
    legal_status,
    age_category,
    appointment_type,
    diagnosis
