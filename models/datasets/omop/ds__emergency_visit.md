{% docs ds__emergency_visit %}
Emergency department attendances dataset. One row per day per area with a count of ED
attendances (encounters whose first history segment has OMOP visit concept 9203/Emergency
Room Visit -- emergency, triage, or observation), disaggregated by facility, sex, emergency
visit age band, and whether the attendance led to an inpatient admission. Additive count
only, so it can be aggregated to any period.
{% enddocs %}

{% docs ds__emergency_visit__location_group_id %}
UUID of the intake segment's location_group (the ED area). 'locationgroup-unknown' (not a
real FK value) when the segment's location has no location_group, or that location_group
no longer resolves; otherwise FK to bases/location_groups.
{% enddocs %}

{% docs ds__emergency_visit__location_group_name %}
Name of the intake segment's location_group (the ED area). 'Unknown' when the segment's
location has no location_group, or that location_group no longer resolves.
{% enddocs %}

{% docs ds__emergency_visit__age_group %}
Emergency visit age band at the attendance date, per the WHO primary age classification's
range boundaries: '0-14 years', '15-24 years', '25-44 years', '45-59 years',
'60-74 years', '75+ years', or 'Unknown age' when the birth date is missing, or the
computed age at the attendance is negative or greater than 120 (implausible/bad data).
{% enddocs %}

{% docs ds__emergency_visit__total_emergency_visits %}
Count of emergency department attendances (encounters whose first history segment has OMOP
visit concept 9203/Emergency Room Visit) in the group. Attendances subsequently admitted as
inpatients are included, and distinguished by is_inpatient_admission.
{% enddocs %}

{% docs ds__emergency_visit__is_inpatient_admission %}
Whether the ED attendance resulted in an inpatient admission: true when the encounter's
visit-level OMOP concept is 262 (Emergency Room and Inpatient Visit), which
clinical__visit_occurrence assigns to an admission encounter that passed through an
emergency, triage or observation phase. false for an attendance that did not become an
admission. Never NULL, since it is a filter column -- an attendance whose current
encounter_type maps to no OMOP visit concept is excluded from the dataset entirely, not
assigned false. Grouping on this gives the ED-to-admission conversion rate without a
second dataset.
{% enddocs %}

{% docs ds__emergency_visit__tupaia_facility_id %}
Tupaia's facility id, mapped from tamanu_facility_id via the deployment's own
tupaia_facility_mapping seed. 'Not available' (never NULL, since this is the data table's
filter column) when the deployment has not configured a facility mapping, or when the
facility has no mapping entry. tamanu_facility_id itself is never NULL here -- an
attendance whose location doesn't resolve is excluded from the dataset entirely.
{% enddocs %}
