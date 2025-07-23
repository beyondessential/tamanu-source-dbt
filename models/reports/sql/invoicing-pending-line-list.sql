select
    to_char(discharge_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('dischargeDate','Discharged date') }}",
    patient_name as "{{ translate_label('patientName','Patient name') }}",
    display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}"
from {{ ref('ds__invoicing_pending') }}
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else discharge_datetime::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else discharge_datetime::date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
order by discharge_datetime
