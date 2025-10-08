select
    total_patients as {{ translate_label('patientTotal') }},
    total_patients_with_incomplete_name as {{ translate_label('patientTotalWithIncompleteName') }},
    total_patients_with_missing_dob as {{ translate_label('patientTotalWithMissingDateOfBirth') }},
    total_patients_with_invalid_dob as {{ translate_label('patientTotalWithInvalidDateOfBirth') }},
    total_patients_with_missing_location as {{ translate_label('patientTotalWithMissingLocation') }},
    total_patients_with_missing_contact as {{ translate_label('patientTotalWithMissingContact') }},
    total_patients_merged as {{ translate_label('patientTotalMerged') }}
from {{ ref("ds__usage_quality_metrics_patient_details") }}