select
    to_char(i.discharge_datetime, '{{ var("date_format") }}') as "{{ translate_string('discharge.dischargeDate.label','Discharged date') }}",
    i.invoice_number as "{{ translate_string('general.localisedField.invoiceDisplayId.label','Invoice number') }}",
    i.patient_name as "{{ translate_string('general.table.column.patientName','Patient name') }}",
    i.discharge_area as "{{ translate_string('','Area (at time of discharge)') }}",
    i.total_invoice_amount as "{{ translate_string('','Total invoice amount') }}",
    i.total_insurer_amount as "{{ translate_string('','Total insurer amount') }}",
    i.total_patient_discount as "{{ translate_string('','Total patient discount') }}",
    i.total_patient_amount as "{{ translate_string('','Total patient amount') }}"
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
