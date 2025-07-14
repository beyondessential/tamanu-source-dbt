select
    i.admission_datetime as "{{ translate_label('admissionDate') }}",
    i.discharge_datetime as "{{ translate_label('dischargeDate') }}",
    i.invoice_number as "{{ translate_label('invoiceNumber') }}",
    i.patient_name as "{{ translate_label('patientName') }}",
    i.display_id as "{{ translate_label('patientDisplayId') }}",
    i.social_security_number as "{{ translate_label('patientSSN') }}",
    i.nationality as "{{ translate_label('patientNationality') }}",
    i.insurers as "{{ translate_label('invoiceInsurers') }}",
    i.total_invoice_amount as "{{ translate_label('invoiceTotalAmount') }}",
    i.total_insurer_amount as "{{ translate_label('invoiceInsurerAmount') }}",
    i.total_patient_discount as "{{ translate_label('invoicePatientDiscount') }}",
    i.total_patient_amount as "{{ translate_label('invoicePatientAmount') }}",
    i.is_deceased as "{{ translate_label('patientDeceasedOrActive') }}",
    i.date_of_death as "{{ translate_label('patientDateOfDeath') }}"
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