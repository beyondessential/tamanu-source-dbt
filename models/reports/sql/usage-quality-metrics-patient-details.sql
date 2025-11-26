select
    total_patients as "{{ translate_label_from_seed('patientTotal') }}",
    total_patients_with_incomplete_name as "{{ translate_label_from_seed('patientTotalWithIncompleteName') }}",
    total_patients_with_missing_dob as "{{ translate_label_from_seed('patientTotalWithMissingDateOfBirth') }}",
    total_patients_with_invalid_dob as "{{ translate_label_from_seed('patientTotalWithInvalidDateOfBirth') }}",
    total_patients_with_missing_location as "{{ translate_label_from_seed('patientTotalWithMissingLocation') }}",
    total_patients_with_missing_contact as "{{ translate_label_from_seed('patientTotalWithMissingContact') }}",
    total_patients_merged as "{{ translate_label_from_seed('patientTotalMerged') }}"
from {{ ref("ds__usage_quality_metrics_patient_details") }}