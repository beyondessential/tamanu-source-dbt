select
    to_char(i.discharge_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('dischargeDate') }}",
    i.invoice_number as "{{ translate_label_from_seed('invoiceNumber') }}",
    i.patient_name as "{{ translate_label_from_seed('patientName') }}",
    i.display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    i.nationality as "{{ translate_label_from_seed('patientNationality') }}",
    i.total_patient_amount as "{{ translate_label_from_seed('invoicePatientAmount') }}",
    i.remaining_patient_balance as "{{ translate_label_from_seed('invoiceRemainingPatientBalance') }}"
from {{ ref("ds__invoicing") }} i
where i.status = 'finalised'
    and case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else i.discharge_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else i.discharge_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
order by i.discharge_datetime
