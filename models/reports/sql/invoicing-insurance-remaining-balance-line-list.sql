select
    i.patient_name as "{{ translate_label('patientName','Patient name') }}",
    i.display_id as "{{ translate_label('patientDisplayId','Patient ID') }}",
    i.social_security_number as "{{ translate_label('patientSocialSecurityNumber','Social security number') }}",
    i.invoice_number as "{{ translate_label('invoiceNumber','Invoice number') }}",
    i.admission_datetime::date as "{{ translate_label('admissionDate','Admission date') }}",
    i.discharge_datetime::date as "{{ translate_label('dischargeDate','Discharged date') }}",
    i.insurer_id as "{{ translate_label('insurerId','Insurer ID') }}",
    i.insurance_policy_number as "{{ translate_label('patientInsurancePolicyNumber','Insurance policy number') }}",
    i.insurer_name as "{{ translate_label('insurerName','Name of insurer') }}",
    i.total_invoice_amount as "{{ translate_label('invoiceTotalAmount','Total invoice amount') }}",
    i.insurer_total_amount as "{{ translate_label('invoiceInsurerTotal','Insurer total') }}",
    i.remaining_insurer_balance as "{{ translate_label('invoiceRemainingInsurerBalance','Remaining balance (insurer payments)') }}"
from {{ ref("ds__invoicing_transactions_insurer") }} i
where i.remaining_insurer_balance > 0
    and case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is not null
            then i.discharge_datetime::date >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
        else true
    end
    and case
        when {{ parameter('toDate', default_value='2024-12-31', data_type='date') }} is not null
            then i.discharge_datetime::date <= {{ parameter('toDate', default_value='2024-12-31', data_type='date') }}
        else true
    end
    and case
        when {{ parameter('insurerId', default_value=null, data_type='text') }} is not null
            then i.insurer_id = {{ parameter('insurerId', default_value=null, data_type='text') }}
        else true
    end
order by i.discharge_datetime, i.patient_name
