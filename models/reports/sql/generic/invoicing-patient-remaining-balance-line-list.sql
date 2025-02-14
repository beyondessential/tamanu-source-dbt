select
    to_char(i.discharge_datetime, '{{ var("date_format") }}') as "{{ translate_string('discharge.dischargeDate.label','Discharged date') }}",
    i.invoice_number as "{{ translate_string('general.localisedField.invoiceDisplayId.label','Invoice number') }}",
    i.patient_name as "{{ translate_string('general.table.column.patientName','Patient name') }}",
    i.display_id as "{{ translate_string('general.localisedField.displayId.label','Patient ID') }}",
    i.nationality as "{{ translate_string('general.localisedField.nationalityId.label','Nationality') }}",
    i.total_patient_amount as "{{ translate_string('','Total patient amount') }}",
    i.remaining_patient_balance as "{{ translate_string('','Remaining balance (patient)') }}"
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
