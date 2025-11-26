select
    to_char(itp.date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('paymentDate') }}",
    itp.invoice_number as "{{ translate_label_from_seed('invoiceNumber') }}",
    itp.patient_name as "{{ translate_label_from_seed('patientName') }}",
    itp.payment_method as "{{ translate_label_from_seed('paymentMethod') }}",
    itp.receipt_number as "{{ translate_label_from_seed('paymentReceiptNumber') }}",
    itp.amount as "{{ translate_label_from_seed('paymentAmount') }}",
    itp.received_by as "{{ translate_label_from_seed('paymentReceivedBy') }}"
from {{ ref("ds__invoicing_transactions_patient") }} itp
where case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else itp.date
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else itp.date
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
    and case when {{ parameter('methodId') }} is not null then itp.payment_method_id = {{ parameter('methodId') }} else true end
order by itp.date
