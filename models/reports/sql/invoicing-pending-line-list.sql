select
    ip.discharge_datetime as "{{ translate_label('dischargeDate') }}",
    ip.patient_name as "{{ translate_label('patientName') }}",
    ip.display_id as "{{ translate_label('patientDisplayId') }}"
from {{ ref('ds__invoicing_pending') }} ip
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else ip.discharge_datetime::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else ip.discharge_datetime::date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
