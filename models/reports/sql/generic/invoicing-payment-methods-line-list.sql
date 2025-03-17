select
    to_char(itp.date, '{{ var("date_format") }}') as "{{ translate_string('','Payment date') }}",
    itp.invoice_number as "{{ translate_string('general.localisedField.invoiceDisplayId.label','Invoice number') }}",
    itp.patient_name as "{{ translate_string('general.table.column.patientName','Patient name') }}",
    itp.payment_method as "{{ translate_string('','Method') }}",
    itp.receipt_number as "{{ translate_string('general.localisedField.receiptNumber.label','Receipt number') }}",
    itp.amount as "{{ translate_string('','Applied payment (amount)') }}",
    itp.recieved_by as "{{ translate_string('','Tamanu User Name') }}"
from {{ ref("ds__invoicing_transactions_patient") }} itp
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else itp.date::date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else itp.date::date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and case when {{ parameter('methodId') }} is not null then itp.payment_method_id = {{ parameter('methodId') }} else true end
