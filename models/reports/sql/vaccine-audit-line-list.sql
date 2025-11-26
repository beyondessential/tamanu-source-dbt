select
    display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    first_name as "{{ translate_label_from_seed('patientFirstName') }}",
    last_name as "{{ translate_label_from_seed('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfBirth') }}",
    age as "{{ translate_label_from_seed('patientAge') }}",
    sex as "{{ translate_label_from_seed('patientSex') }}",
    village as "{{ translate_label_from_seed('patientVillage') }}",
    to_char(vaccination_date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('vaccinationDate') }}",
    vaccine_name as "{{ translate_label_from_seed('vaccineName') }}",
    vaccine_brand as "{{ translate_label_from_seed('vaccineBrand') }}",
    disease as "{{ translate_label_from_seed('vaccineDisease') }}",
    vaccine_status as "{{ translate_label_from_seed('vaccinationStatus') }}",
    vaccine_schedule as "{{ translate_label_from_seed('vaccineSchedule') }}",
    given_by as "{{ translate_label_from_seed('vaccinationGivenBy') }}",
    recorded_by as "{{ translate_label_from_seed('vaccinationRecordedBy') }}",
    modified_by as "{{ translate_label_from_seed('vaccinationModifiedBy') }}",
    to_char(updated_at, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('vaccinationModifiedDate') }}"
from {{ ref("ds__vaccinations") }}
where
    vaccine_status in ('Recorded in error', 'Historical')
    and
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else vaccination_date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else vaccination_date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('villageId') }} is null then true
        else village_id = {{ parameter('villageId') }}
    end
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else facility_id = {{ parameter('facilityId') }}
    end
    and
    case
        when {{ parameter('category') }} is null then true
        else vaccine_category = {{ parameter('category') }}
    end
    and
    case
        when {{ parameter('vaccine') }} is null then true
        else vaccine_name = {{ parameter('vaccine') }}
    end
    and
    case
        when {{ parameter('status') }} is null then true
        else vaccine_status = {{ parameter('status') }}
    end
order by vaccination_date, last_name, first_name
