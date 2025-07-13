select
    i.discharge_datetime as "{{ translate_label('dischargeDate','Discharged date') }}",
    i.invoice_number as "{{ translate_label('invoiceNumber','Invoice number') }}",
    i.patient_name as "{{ translate_label('patientName','Patient name') }}",
    i.display_id as "{{ translate_label('patientDisplayId','Patient ID') }}",
    i.nationality as "{{ translate_label('patientNationality','Nationality') }}",
    i.total_patient_amount as "{{ translate_label('invoicePatientAmount','Total patient amount') }}",
    i.remaining_patient_balance as "{{ translate_label('invoiceRemainingPatientBalance','Remaining balance (patient)') }}"
from {{ ref("ds__invoicing") }} i
where i.status = 'finalised'
    and case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else i.discharge_datetime::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else i.discharge_datetime::date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
order by discharge_datetime
