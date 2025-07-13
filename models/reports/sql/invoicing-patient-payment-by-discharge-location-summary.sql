select
    i.discharge_datetime as "{{ translate_label('dischargeDate','Discharged date') }}",
    i.invoice_number as "{{ translate_label('invoiceNumber','Invoice number') }}",
    i.patient_name as "{{ translate_label('patientName','Patient name') }}",
    i.discharge_area as "{{ translate_label('dischargeLocationGroup','Area (at time of discharge)') }}",
    i.total_invoice_amount as "{{ translate_label('invoiceTotalAmount','Total invoice amount') }}",
    i.total_insurer_amount as "{{ translate_label('invoiceInsurerAmount','Total insurer amount') }}",
    i.total_patient_discount as "{{ translate_label('invoicePatientDiscount','Total patient discount') }}",
    i.total_patient_amount as "{{ translate_label('invoicePatientAmount','Total patient amount') }}"
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