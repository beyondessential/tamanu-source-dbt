select
    to_char(i.discharge_datetime, '{{ var("datetime_format") }}') as "{{ translate_label('dischargeDate') }}",
    i.invoice_number as "{{ translate_label('invoiceNumber') }}",
    i.patient_name as "{{ translate_label('patientName') }}",
    i.display_id as "{{ translate_label('patientDisplayId') }}",
    i.nationality as "{{ translate_label('patientNationality') }}",
    i.total_patient_amount as "{{ translate_label('invoicePatientAmount') }}",
    i.remaining_patient_balance as "{{ translate_label('invoiceRemainingPatientBalance') }}"
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
