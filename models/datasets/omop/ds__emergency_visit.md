{% docs ds__emergency_visit %}
Emergency department attendances dataset. One row per day per area with a count of ED
attendances (encounters whose first history segment has OMOP visit concept 9203/Emergency
Room Visit -- emergency, triage, or observation), disaggregated by facility, sex and
emergency visit age band. Additive count only, so it can be aggregated to any period.
{% enddocs %}

{% docs ds__emergency_visit__age_group %}
Emergency visit age band at the attendance date, per the WHO primary age classification's
range boundaries: '0-14 years', '15-24 years', '25-44 years', '45-59 years',
'60-74 years', '75+ years', or 'Unknown age' when the birth date is missing, or the
computed age at the attendance is negative or greater than 120 (implausible/bad data).
{% enddocs %}

{% docs ds__emergency_visit__total_emergency_visits %}
Count of emergency department attendances (encounters whose first history segment has OMOP
visit concept 9203/Emergency Room Visit) in the group. Attendances that were subsequently
admitted are included, since the encounter still started in the ED.
{% enddocs %}

{% docs ds__emergency_visit__tupaia_facility_id %}
Tupaia's facility id, mapped from tamanu_facility_id via the deployment's own
tupaia_facility_mapping seed. 'Not available' (never NULL, since this is the data table's
filter column) when the deployment has not configured a facility mapping, when the
facility has no mapping entry, or when tamanu_facility_id itself is NULL (the encounter
has no location).
{% enddocs %}
