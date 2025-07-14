select
    to_char(itp.date, '{{ var("date_format") }}') as "{{ translate_label('paymentDate','Payment date') }}",
    itp.invoice_number as "{{ translate_label('invoiceNumber','Invoice number') }}",
    itp.patient_name as "{{ translate_label('patientName','Patient name') }}",
    itp.payment_method as "{{ translate_label('paymentMethod','Method') }}",
    itp.receipt_number as "{{ translate_label('paymentReceiptNumber','Receipt number') }}",
    itp.amount as "{{ translate_label('paymentAmount','Applied payment (amount)') }}",
    itp.received_by as "{{ translate_label('paymentReceivedBy','Tamanu user name') }}"
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
order by itp.date
