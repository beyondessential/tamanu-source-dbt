select
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}",
    first_name as "{{ translate_label('patientFirstName', 'First name') }}",
    last_name as "{{ translate_label('patientLastName', 'Last name') }}",
    date_of_birth as "{{ translate_label('patientDateOfBirth', 'Date of birth') }}",
    age as "{{ translate_label('patientAge', 'Age') }}",
    sex as "{{ translate_label('patientSex', 'Sex') }}",
    village as "{{ translate_label('patientVillage', 'Village') }}",
    billing_type as "{{ translate_label('patientBillingType', 'Billing type') }}",
    booking_start_datetime as "{{ translate_label('bookingStartDateTime', 'Booking start date and time') }}",
    booking_end_datetime as "{{ translate_label('bookingEndDateTime', 'Booking end date and time') }}",
    case
        when extract(day from age(booking_end_datetime, booking_start_datetime)) >= 1
            then extract(day from age(booking_end_datetime, booking_start_datetime)) || ' nights'
        when extract(hour from age(booking_end_datetime, booking_start_datetime)) >= 1
            then extract(hour from age(booking_end_datetime, booking_start_datetime)) || ' hours'
        else extract(minute from age(booking_end_datetime, booking_start_datetime)) || ' minutes'
    end as "{{ translate_label('bookingDuration', 'Booking duration') }}",
    location_group as "{{ translate_label('bookingLocationGroup', 'Area') }}",
    location as "{{ translate_label('bookingLocation', 'Location') }}",
    clinician as "{{ translate_label('bookingClinician', 'Clinician') }}",
    booking_type as "{{ translate_label('bookingType', 'Booking type') }}",
    booking_status as "{{ translate_label('bookingStatus', 'Booking status') }}"
from {{ ref('ds__location_bookings') }}
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
