select
    to_char(i.admission_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('admissionDate') }}",
    to_char(i.discharge_datetime, '{{ var("datetime_format") }}') as "{{ translate_label_from_seed('dischargeDate') }}",
    i.invoice_number as "{{ translate_label_from_seed('invoiceNumber') }}",
    i.patient_name as "{{ translate_label_from_seed('patientName') }}",
    i.display_id as "{{ translate_label_from_seed('patientDisplayId') }}",
    i.social_security_number as "{{ translate_label_from_seed('patientSSN') }}",
    i.nationality as "{{ translate_label_from_seed('patientNationality') }}",
    i.insurers as "{{ translate_label_from_seed('invoiceInsurers') }}",
    i.total_invoice_amount as "{{ translate_label_from_seed('invoiceTotalAmount') }}",
    i.total_insurer_amount as "{{ translate_label_from_seed('invoiceInsurerAmount') }}",
    i.total_patient_discount as "{{ translate_label_from_seed('invoicePatientDiscount') }}",
    i.total_patient_amount as "{{ translate_label_from_seed('invoicePatientAmount') }}",
    i.is_deceased as "{{ translate_label_from_seed('patientDeceasedOrActive') }}",
    to_char(i.date_of_death, '{{ var("date_format") }}') as "{{ translate_label_from_seed('patientDateOfDeath') }}"
from {{ ref("ds__invoicing") }} i
where i.status = 'finalised'
    and case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true
        else i.discharge_datetime
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true
        else i.discharge_datetime
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}
    end
order by i.discharge_datetime
