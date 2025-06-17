select
    to_char(i.discharge_datetime, '{{ var("date_format") }}') as "{{ translate_string('dischargeDate','Discharged date') }}",
    i.invoice_number as "{{ translate_string('invoiceNumber','Invoice number') }}",
    i.patient_name as "{{ translate_string('patientName','Patient name') }}",
    i.discharge_area as "{{ translate_string('dischargeArea','Area (at time of discharge)') }}",
    i.total_invoice_amount as "{{ translate_string('totalInvoiceAmount','Total invoice amount') }}",
    i.total_insurer_amount as "{{ translate_string('totalInsurerAmount','Total insurer amount') }}",
    i.total_patient_discount as "{{ translate_string('totalPatientDiscount','Total patient discount') }}",
    i.total_patient_amount as "{{ translate_string('totalPatientAmount','Total patient amount') }}"
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
