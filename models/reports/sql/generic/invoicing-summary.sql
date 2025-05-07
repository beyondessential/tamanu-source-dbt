select
    to_char(i.admission_datetime, '{{ var("date_format") }}') as "{{ translate_string('admissionDate','Admission date') }}",
    to_char(i.discharge_datetime, '{{ var("date_format") }}') as "{{ translate_string('dischargeDate','Discharged date') }}",
    i.invoice_number as "{{ translate_string('invoiceNumber','Invoice number') }}",
    i.patient_name as "{{ translate_string('patientFullName','Patient name') }}",
    i.display_id as "{{ translate_string('patientDisplayId','Patient ID') }}",
    i.social_security_number as "{{ translate_string('patientSSN','Social security number') }}",
    i.nationality as "{{ translate_string('patientNationality','Nationality') }}",
    i.insurers as "{{ translate_string('invoiceInsurers','Insurer') }}",
    i.total_invoice_amount as "{{ translate_string('invoiceTotalAmount','Total invoice amount') }}",
    i.total_insurer_amount as "{{ translate_string('invoiceInsurerAmount','Total insurer amount') }}",
    i.total_patient_discount as "{{ translate_string('invoicePatientDiscount','Total patient discount') }}",
    i.total_patient_amount as "{{ translate_string('invoicePatientAmount','Total patient amount') }}",
    i.is_deceased as "{{ translate_string('patientIsDeceased','Deceased/Active') }}",
    to_char(i.date_of_death, '{{ var("date_format") }}') as "{{ translate_string('patientDateOfDeath','Date deceased') }}"
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
