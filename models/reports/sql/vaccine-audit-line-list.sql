select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    vaccination_date as "{{ translate_label('vaccinationDate') }}",
    vaccine_name as "{{ translate_label('vaccineName') }}",
    vaccine_brand as "{{ translate_label('vaccineBrand') }}",
    disease as "{{ translate_label('vaccineDisease') }}",
    vaccine_status as "{{ translate_label('vaccinationStatus') }}",
    vaccine_schedule as "{{ translate_label('vaccineSchedule') }}",
    given_by as "{{ translate_label('vaccinationGivenBy') }}",
    recorded_by as "{{ translate_label('vaccinationRecordedBy') }}",
    modified_by as "{{ translate_label('vaccinationModifiedBy') }}",
    modification_datetime as "{{ translate_label('vaccinationModifiedDate') }}"
from {{ ref("ds__vaccinations") }}
where
    vaccine_status in ('Recorded in error', 'Historical')
    and
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else vaccination_date::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else vaccination_date::date
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
