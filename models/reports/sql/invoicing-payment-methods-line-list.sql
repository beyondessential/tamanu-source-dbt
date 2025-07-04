select
    itp.date as "{{ translate_label('paymentDate') }}",
    itp.invoice_number as "{{ translate_label('invoiceNumber') }}",
    itp.patient_name as "{{ translate_label('patientName') }}",
    itp.payment_method as "{{ translate_label('paymentMethod') }}",
    itp.receipt_number as "{{ translate_label('paymentReceiptNumber') }}",
    itp.amount as "{{ translate_label('paymentAmount') }}",
    itp.received_by as "{{ translate_label('paymentReceivedBy') }}"
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
