select
    md.medication as "{{ translate_label('encounterPrescriptionMedication') }}",
    md.medication_code as "{{ translate_label('encounterPrescriptionMedicationCode') }}",
    sum(md.quantity) as "{{ translate_label('encounterPrescriptionQuantity') }}"
from {{ ref('ds__sensitive_medication_dispenses') }} md
where
    case
        when {{ parameter('facilityId') }} is null then true
        else md.facility_id = {{ parameter('facilityId') }}
    end
    and
    -- BL-003 (see specs/reports/medication-dispensed-summary.md): multi-select over all drugs. Nothing selected means every one.
    -- BL-004: the form sends an empty selection as [], which expands to nothing, so the list goes
    -- through an array constructor: array[]::text[] is valid where coalesce() and in () are not.
    (
        cardinality(array_remove(array[{{ parameter('medicationId') }}]::text[], null)) = 0
        or md.medication_id = any(array[{{ parameter('medicationId') }}]::text[])
    )
    and
    {{ to_user_selected_timezone('md.dispensed_at') }}
    >= {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }}
    and
    {{ to_user_selected_timezone('md.dispensed_at') }}
    <= {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }}
group by md.medication_id, md.medication, md.medication_code
