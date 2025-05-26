select
    ip.discharge_datetime as "{{ translate_label('dischargeDate','Discharged date') }}",
    ip.patient_name as "{{ translate_label('patientName','Patient name') }}",
    ip.display_id as "{{ translate_label('patientDisplayId', 'Patient ID') }}"
from {{ ref('ds__invoicing_pending') }} ip
where i.id is null
    and e.deleted_at is null
    and e.end_date is not null
    and p.id != 'h1627394-3778-4c31-a510-9fcb88efdbf3'
    and case when :fromDate is null then true else e.end_date >= :fromDate end
    and case when :toDate is null then true else e.end_date <= :toDate end
