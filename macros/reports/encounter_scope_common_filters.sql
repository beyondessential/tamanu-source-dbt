{% macro encounter_scope_common_filters() %}
{#-
    The optional-id filters that every encounter-scoped report applies identically:
    facility, patient billing type, and supervising clinician. A null parameter
    disables that filter.

    Emitted as predicate text for encounters_in_scope()'s `extra_predicates`, so it
    obeys the same alias contract -- it references `e` and `f` only.

    Report-only. It calls parameter(), so it must never be reached from a dataset
    macro; see the note in encounters_in_scope().

    Date ranges and report-specific flags are deliberately NOT here. They genuinely
    differ between callers: encounter_summary filters on a caller-chosen date_field,
    while encounter_invoice_audit filters on start_datetime and carries
    includeOpenEncounters.
-#}
(
case
    when {{ parameter('facilityId') }} is null then true
    else f.id = {{ parameter('facilityId') }}
end
and case
    when {{ parameter('patientBillingTypeId') }} is null then true
    else e.patient_billing_type_id = {{ parameter('patientBillingTypeId') }}
end
and case
    when {{ parameter('supervisingClinicianId') }} is null then true
    else e.clinician_id = {{ parameter('supervisingClinicianId') }}
end
)
{% endmacro %}
