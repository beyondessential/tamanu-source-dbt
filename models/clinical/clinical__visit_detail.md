{% docs clinical__visit_detail %}
OMOP-lite VISIT_DETAIL domain: one row per encounter segment — a contiguous
department/location/encounter_type phase within a single encounter, unfolded from the
encounter_history timeline. Sits below clinical__visit_occurrence (one segment ...many
per visit) and is keyed to its parent by visit_occurrence_id.
{% enddocs %}

{% docs clinical__visit_detail__visit_detail_id %}
Unique identifier for the encounter segment; the OMOP visit_detail_id. The
encounter_history event that opens the segment, or the encounter id for a synthesized
whole-visit segment.
{% enddocs %}

{% docs clinical__visit_detail__visit_occurrence_id %}
The parent encounter; the OMOP visit_occurrence_id. FK to
clinical__visit_occurrence.visit_occurrence_id.
{% enddocs %}

{% docs clinical__visit_detail__visit_detail_concept_id %}
OMOP standard Visit concept for this segment's encounter_type (9201 Inpatient Visit,
9202 Outpatient Visit, 9203 Emergency Room Visit). NULL when the type has no matching
concept. Per-segment, so an ER phase and a later inpatient phase of one encounter carry
9203 and 9201 respectively.
{% enddocs %}

{% docs clinical__visit_detail__visit_detail_start_date %}
Date component of the segment start datetime.
{% enddocs %}

{% docs clinical__visit_detail__visit_detail_start_datetime %}
Timestamp at which the segment began (the encounter_history event datetime, or the
encounter start for a synthesized segment).
{% enddocs %}

{% docs clinical__visit_detail__visit_detail_end_date %}
Date component of the segment end datetime. NULL for the final segment of an open encounter.
{% enddocs %}

{% docs clinical__visit_detail__visit_detail_end_datetime %}
Timestamp at which the segment ended: the next segment's start, or the encounter end
datetime for the final segment. NULL for the final segment of an open encounter.
{% enddocs %}

{% docs clinical__visit_detail__care_site_id %}
UUID of the area (location_group) the segment took place in — the physical care site. FK
to ref__care_site.care_site_id (area-type rows). NULL when the segment's location has no
location_group, which is common in Tamanu.
{% enddocs %}

{% docs clinical__visit_detail__department_id %}
UUID of the department (organizational care unit) responsible for the segment. Carried as
an attribute; not itself a visit-level care site (see clinical__visit_occurrence and
clinical__visit_detail care_site_id, which key on area instead). FK to
ref__care_site.care_site_id (department-type rows).
{% enddocs %}

{% docs clinical__visit_detail__location_id %}
UUID of the room/bed (Tamanu location) the segment took place in — finer than the area
care site. Carried as a raw UUID; there is no ref__ wrapper for Tamanu locations yet.
{% enddocs %}

{% docs clinical__visit_detail__visit_detail_source_value %}
The segment's raw Tamanu encounter_type value, retained alongside the concept shadow.
{% enddocs %}

{% docs clinical__visit_detail__preceding_visit_detail_id %}
The visit_detail_id of the prior segment in the same encounter; NULL for the first
segment. Gives OMOP's intra-visit ordering.
{% enddocs %}
