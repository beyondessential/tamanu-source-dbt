select
    display_id as "{{ translate_string('general.localisedField.displayId.label', 'Patient ID') }}",
    first_name as "{{ translate_string('general.localisedField.firstName.label', 'First name') }}",
    last_name as "{{ translate_string('general.localisedField.lastName.label', 'Last name') }}",
    to_char(date_of_birth, '{{ var("date_format") }}') as "{{ translate_string('general.localisedField.dateOfBirth.label', 'Date of birth') }}",
    age as "{{ translate_string('general.localisedField.Age', 'Age') }}",
    sex as "{{ translate_string('general.localisedField.sex.label', 'Sex') }}",
    village as "{{ translate_string('general.localisedField.villageId.label','Village') }}",
    billing_type as "{{ translate_string('general.localisedField.patientBillingTypeId.label', 'Patient type') }}",
    to_char(booking_start_datetime, '{{ var("datetime_format") }}') as "{{ translate_string('', 'Booking date and time') }}",
    to_char(booking_end_datetime, '{{ var("datetime_format") }}') as "{{ translate_string('', 'Booking end date and time') }}",
    case
        when extract(day from age(booking_end_datetime, booking_start_datetime)) >= 1
            then extract(day from age(booking_end_datetime, booking_start_datetime)) || ' nights'
        when extract(hour from age(booking_end_datetime, booking_start_datetime)) >= 1
            then extract(hour from age(booking_end_datetime, booking_start_datetime)) || ' hours'
        else extract(minute from age(booking_end_datetime, booking_start_datetime)) || ' minutes'
    end as "{{ translate_string('', 'Booking duration') }}",
    location_group as "{{ translate_string('general.localisedField.area.label', 'Area') }}",
    location as "{{ translate_string('general.localisedField.locationId.label', 'Location') }}",
    clinician as "{{ translate_string('general.localisedField.clinician.label', 'Clinician') }}",
    booking_type as "{{ translate_string('', 'Booking type') }}",
    booking_status as "{{ translate_string('', 'Booking status') }}"
from {{ ref('ds__location_bookings') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else booking_start_datetime >={{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else booking_end_datetime <={{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and
    case
        when {{ parameter('locationGroupId') }} is null then true
        else location_group_id ={{ parameter('locationGroupId') }}
    end
    and
    case
        when {{ parameter('bookingStatus') }} is null then true
        else booking_status ={{ parameter('bookingStatus') }}
    end
    and
    case
        when {{ parameter('clinicianId') }} is null then true
        else clinician_id ={{ parameter('clinicianId') }}
    end
