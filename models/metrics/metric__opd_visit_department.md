{% docs metric__opd_visit_department %}
D5 metric view for the outpatient visit-by-department indicator registered in
documentations/metrics/*.yml: opd_visit_department. One row per **segment** of an outpatient
visit -- deliberately not one row per visit like its sibling `metric__outpatient_visit`.

Companion to `metric__outpatient_visit`, not a replacement: that metric resolves department off
the visit's first (intake) segment only, so a pure department transfer with no encounter_type
change -- moving into or out of Dental partway through an otherwise ordinary outpatient visit,
say -- never shows up in it. This metric exists to answer "did this visit ever touch department
X, and how long did it spend there", which needs every segment the visit's history recorded, not
just its first.

An outpatient visit is, as in `metric__outpatient_visit`, an encounter whose first history
segment carries OMOP visit concept 9202/Outpatient Visit. Every 9202-concept segment of that
visit -- however many a transfer produced -- is emitted as its own row, carrying that segment's
own department, clinician and duration; every other column (facility, location, sex, admission
outcome, admitting clinician, whether the discharge was system-generated) is the same value on
every row for a given visit, copied unchanged from the visit's own intake segment. A segment
after the visit transitions to a different concept -- an inpatient admission, most commonly --
is excluded: that segment belongs to a different episode, not to this outpatient visit's own
department history, the same boundary `opd_time__minutes` already draws.

subject_id is **not** unique in this metric -- it repeats once per segment. Summing
value_numeric or segment_time__minutes with no department scope is meaningless: a visit that
touched three departments contributes three rows to that unscoped sum. Valid once a consumer
scopes to exactly one department (Tupaia's `scope` mechanism, a fixed WHERE condition, is the
intended way) and counts/sums distinct subject_id from there -- see specs/dbt-model for BL-001,
which spells out why this departs from `metric__outpatient_visit`'s own "count(distinct
subject_id) and sum(value_numeric) agree" guarantee.

See specs/dbt-model/metric__opd_visit_department.md for BL-001..BL-005.
{% enddocs %}

{% docs metric__opd_visit_department__metric_id %}
The registered indicator identifier: always 'opd_visit_department'. Joins to the canonical
registry in documentations/metrics/*.yml, which carries its definition, source and rationale.
{% enddocs %}

{% docs metric__opd_visit_department__variant_id %}
NULL -- this is the standard definition, with no deployment-specific variant.
{% enddocs %}

{% docs metric__opd_visit_department__subject_id %}
The OMOP visit occurrence id of the outpatient visit, matching `metric__outpatient_visit`'s own
subject_id for the same visit -- the two metrics can be correlated by this column.

**Not unique within this metric** (BL-001): it repeats once per segment the visit's history
recorded, which is the entire reason this metric exists over `metric__outpatient_visit`'s
one-row-per-visit grain. `count(distinct subject_id)`, not `sum(value_numeric)`, is how a
consumer counts visits from this metric -- and even that is only meaningful once scoped to one
department, since an unscoped count still double-counts a visit that touched several.
{% enddocs %}

{% docs metric__opd_visit_department__segment_id %}
Identifier of the visit segment this row describes. Unique within this metric: one row per
segment, and the way to tell apart two segments of the same visit.
{% enddocs %}

{% docs metric__opd_visit_department__period_start %}
Calendar day this segment started -- not the visit's own intake date. Segments of one visit
that start on the same day share a period_start.
{% enddocs %}

{% docs metric__opd_visit_department__period_end %}
Calendar day this segment ended -- the next segment's start, or the encounter end for the
visit's final segment if it's closed. NULL while the segment (and therefore the visit) is
still open.
{% enddocs %}

{% docs metric__opd_visit_department__period_granularity %}
Constant 'day' -- period_start is a date, not a timestamp.
{% enddocs %}

{% docs metric__opd_visit_department__value_numeric %}
Always 1 -- one segment per row. See the model's own top-level doc (and BL-001) for why summing
this with no department scope does not give a visit count.
{% enddocs %}

{% docs metric__opd_visit_department__value_boolean %}
NULL -- unused by this metric.
{% enddocs %}

{% docs metric__opd_visit_department__clinician_id %}
Tamanu `users.id` of the clinician recorded on **this segment** -- not the visit's intake
clinician. A visit transferred into a department carries whoever saw the patient during that
specific segment here, which `metric__outpatient_visit__clinician_id` (intake-only) cannot
express.

Nullable -- a segment recorded with no clinician keeps the row rather than dropping it.
{% enddocs %}

{% docs metric__opd_visit_department__clinician_name %}
Display name of this segment's own clinician, from `ref__provider`. 'Not recorded' where the
segment carries no clinician or the user record has since been deleted -- never NULL, the same
reasoning as `metric__outpatient_visit__clinician_name`.
{% enddocs %}

{% docs metric__opd_visit_department__segment_time__minutes %}
Time in **this segment** in minutes, to two decimal places -- from this segment's own start to
its own end (the next segment's start, or the encounter end for a closed visit's final
segment).

Not the same quantity as `metric__outpatient_visit__opd_time__minutes`, which spans the whole
outpatient episode from intake to departure. Summing this column across every segment of a
visit reproduces that same total; summing it after scoping to one department gives time spent
in that department specifically -- including a visit that left and came back, since segments are
contiguous with no gaps and their durations simply add.

NULL while the segment is open, not zero -- excluded from a mean's denominator the same way
`opd_time__minutes` is.
{% enddocs %}

{% docs metric__opd_visit_department__department %}
This segment's own department (e.g. Dental), resolved to a name via `departments`.

'Not recorded' where the segment carries no department. Never NULL, the same reasoning as
`metric__outpatient_visit__department`.

Can repeat for the same subject_id across non-adjacent segments -- a visit that leaves and
re-enters the same department produces one row per segment, not one row per distinct
department. See BL-001: deduplicating that down to "did this visit ever touch department X" is
a consumer-layer concern.
{% enddocs %}
