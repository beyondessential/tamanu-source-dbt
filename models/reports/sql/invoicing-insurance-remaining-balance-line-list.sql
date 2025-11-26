select
    i.patient_name as "{{ translate_label_from_seed('patientName') }}",
    i.display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    i.social_security_number as "{{ translate_label_from_seed('patientSSN') }}",
    i.invoice_number as "{{ translate_label_from_seed('invoiceNumber') }}",
    to_char(i.admission_datetime::date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('admissionDate') }}",
    to_char(i.discharge_datetime::date, '{{ var("date_format") }}') as "{{ translate_label_from_seed('dischargeDate') }}",
    i.insurer_id as "{{ translate_label_from_seed('insurerId') }}",
    i.insurance_policy_number as "{{ translate_label_from_seed('patientInsurancePolicyNumber') }}",
    i.insurer_name as "{{ translate_label_from_seed('insurerName') }}",
    i.total_invoice_amount as "{{ translate_label_from_seed('invoiceTotalAmount') }}",
    i.insurer_total_amount as "{{ translate_label_from_seed('invoiceInsurerTotal') }}",
    i.remaining_insurer_balance as "{{ translate_label_from_seed('invoiceRemainingInsurerBalance') }}"
from {{ ref("ds__invoicing_summary_insurer") }} i
where i.remaining_insurer_balance > 0
    and case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is not null
            then i.discharge_datetime >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
        else true
    end
    and case
        when {{ parameter('toDate', default_value='2024-12-31', data_type='date') }} is not null
            then i.discharge_datetime <= {{ parameter('toDate', default_value='2024-12-31', data_type='date') }}
        else true
    end
    and case
        when {{ parameter('insurerId', default_value=null, data_type='text') }} is not null
            then i.insurer_id = {{ parameter('insurerId', default_value=null, data_type='text') }}
        else true
    end
order by i.discharge_datetime, i.patient_name
