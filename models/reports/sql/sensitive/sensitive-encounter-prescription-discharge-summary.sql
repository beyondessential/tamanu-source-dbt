-- BL-001: Source rows are prescriptions from ds__sensitive_encounter_prescriptions marked as
-- selected for pharmacy discharge -- the pre-dispensing-module proxy for "sent to / dispensed
-- by pharmacy", used by deployments that have not gone live on the pharmacy dispensing module.
-- BL-002: No cutoff date -- unlike msf-medication-dispensed-summary-historical, this report is
-- an ongoing report for deployments that have never migrated to the dispensing module, not a
-- one-time bridge to a migration date.
-- BL-009: Facility scope is the sensitive-facility partition of ds__sensitive_encounter_prescriptions.
select
    ep.medication as "{{ translate_label('prescriptionMedication') }}",
    ep.medication_code as "{{ translate_label('prescriptionMedicationCode') }}",
    sum(ep.quantity) as "{{ translate_label('prescriptionQuantity') }}"
from {{ ref('ds__sensitive_encounter_prescriptions') }} ep
where
    ep.is_selected_for_discharge = true
    and
    case
        when {{ parameter('facilityId') }} is null then true
        else ep.facility_id = {{ parameter('facilityId') }}
    end
    and
    case
        when {{ parameter('medicationId') }} is null then true
        else ep.medication_id = {{ parameter('medicationId') }}
    end
    and
    {{ to_user_selected_timezone('ep.datetime') }}
    >= {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }}
    and
    {{ to_user_selected_timezone('ep.datetime') }}
    <= {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }}
group by ep.medication_id, ep.medication, ep.medication_code
