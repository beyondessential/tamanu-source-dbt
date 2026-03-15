select
    display_id as "{{ translate_label('patientDisplayId') }}",
    first_name as "{{ translate_label('patientFirstName') }}",
    last_name as "{{ translate_label('patientLastName') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_label('patientDateOfBirth') }}",
    age as "{{ translate_label('patientAge') }}",
    sex as "{{ translate_label('patientSex') }}",
    village as "{{ translate_label('patientVillage') }}",
    billing_type as "{{ translate_label('patientBillingType') }}",
    to_char(booking_start_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('bookingStartDateTime') }}",
    to_char(booking_end_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('bookingEndDateTime') }}",
    case
        when extract(day from age(booking_end_datetime, booking_start_datetime)) >= 1
            then extract(day from age(booking_end_datetime, booking_start_datetime)) || ' nights'
        when extract(hour from age(booking_end_datetime, booking_start_datetime)) >= 1
            then extract(hour from age(booking_end_datetime, booking_start_datetime)) || ' hours'
        else extract(minute from age(booking_end_datetime, booking_start_datetime)) || ' minutes'
    end as "{{ translate_label('bookingDuration') }}",
    location_group as "{{ translate_label('bookingLocationGroup') }}",
    location as "{{ translate_label('bookingLocation') }}",
    clinician as "{{ translate_label('bookingClinician') }}",
    booking_type as "{{ translate_label('bookingType') }}",
    booking_status as "{{ translate_label('bookingStatus') }}"
from {{ ref('ds__sensitive_location_bookings') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else booking_start_datetime >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else booking_end_datetime <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('locationGroupId') }} is null then true
        else location_group_id = {{ parameter('locationGroupId') }}
    end
    and
    case
        when {{ parameter('bookingStatus') }} is null then true
        else booking_status = {{ parameter('bookingStatus') }}
    end
    and
    case
        when {{ parameter('clinicianId') }} is null then true
        else clinician_id = {{ parameter('clinicianId') }}
    end
    and
    case
        when {{ parameter('bookingTypeId') }} is null then true
        else booking_type_id = {{ parameter('bookingTypeId') }}
    end
order by booking_start_datetime
