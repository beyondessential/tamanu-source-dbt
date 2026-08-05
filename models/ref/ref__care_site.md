{% docs ref__care_site %}
OMOP CARE_SITE wrapper over Tamanu care units. Heterogeneous: one row per department
(the organizational care unit, care_site_type = 'department') and one row per
location_group (the physical ward/area, care_site_type = 'ward'), each denormalised with
its parent facility. Wards (location_group) are the care site on both
clinical__visit_occurrence and clinical__visit_detail.
{% enddocs %}

{% docs ref__care_site__care_site_id %}
Unique identifier for the care site (a Tamanu department id or location_group id); the
OMOP care_site_id.
{% enddocs %}

{% docs ref__care_site__care_site_type %}
Which Tamanu entity this care site represents: 'department' (organizational unit) or
'ward' (physical location_group). Lets consumers pick the grain they need.
{% enddocs %}

{% docs ref__care_site__care_site_name %}
Full readable name of the care site (department name or ward name).
{% enddocs %}

{% docs ref__care_site__care_site_source_value %}
The care site's source code in Tamanu (department code or location_group code).
{% enddocs %}

{% docs ref__care_site__place_of_service_source_value %}
The parent facility's type, retained as the OMOP place-of-service source value. NULL when
the care site has no facility. No place_of_service_concept_id is emitted — OMOP's Place of
Service vocabulary has no standard concepts.
{% enddocs %}

{% docs ref__care_site__facility_id %}
UUID of the parent facility this care site belongs to. NULL when unset.
{% enddocs %}

{% docs ref__care_site__facility_name %}
Name of the parent facility this care site belongs to. NULL when the facility is unset
or has been removed.
{% enddocs %}
