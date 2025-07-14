select
    discharge_datetime as "{{ translate_label('dischargeDate') }}",
    patient_name as "{{ translate_label('patientName') }}",
    display_id as "{{ translate_label('patientDisplayId') }}"
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
