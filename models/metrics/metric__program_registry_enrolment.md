{% docs metric__program_registry_enrolment %}
D5 metric view for the program registry enrolment indicator registered in
documentations/metrics/*.yml: program_registry_enrolment. One row per patient enrolment in a
program registry -- per-enrolment (subject) grain, so a consumer aggregates at whatever grain
it needs.

A program registry is how Tamanu follows a patient through a long-running care programme --
HIV, TB, an NCD register -- so an enrolment is the patient's membership of that programme, not
a visit to it. Every registry the deployment configures is emitted, keyed by `registry_code`:
one data table over this model serves all of them, and a consumer that wants one programme
filters to its code.

Aggregate by summing `value_numeric` (always 1) over any subset of the disaggregations --
registry, clinical status, registration status, currently-at, registering facility, sex, age.
Nothing is pre-aggregated, so no dimension has to be collapsed to get a total.

**Enrolments open on a date** are those whose `period_start` has passed and whose `period_end`
is null or later. **Exits** are rows with a `period_end`. The exited share at any grain is
`sum(value_numeric) filter (where period_end is not null) / sum(value_numeric)`, which is what
makes retention answerable without a second metric.

**A cascade is a group-by, not a column.** `clinical_status_code` carries the registry's own
status list -- "Diagnosed, not on ART", "On ART", "Lost to follow up" -- and no metric can
enumerate the statuses of a registry it has never seen. Grouping by it gives the cascade;
filtering to one position gives that position's count.

Sourced from `clinical__episode`, which resolves the enrolment and its boundaries, so the
metric and the OMOP episode cannot disagree about when a patient was enrolled.
{% enddocs %}

{% docs metric__program_registry_enrolment__period_start %}
Datetime the patient was enrolled in the registry, at minute grain.
{% enddocs %}

{% docs metric__program_registry_enrolment__period_end %}
Datetime the enrolment ended, at minute grain.

NULL means the enrolment is open, which is the state most enrolments are in -- so a count of
open enrolments is a count of NULLs here, not an absence of data. See `clinical__episode` for
how the boundary is resolved: a deactivation where one was recorded, otherwise the logged
transition to inactive.
{% enddocs %}

{% docs metric__program_registry_enrolment__value_numeric %}
Always 1: one enrolment per row. Summing it counts enrolments at any grain.
{% enddocs %}

{% docs metric__program_registry_enrolment__registry_code %}
Code of the program registry the patient is enrolled in, as configured in Tamanu.

The code rather than the name, because it is the stable identifier a data table, a report or a
dashboard can be written against -- a registry can be renamed.
{% enddocs %}

{% docs metric__program_registry_enrolment__registry_name %}
Display name of the program registry, for a consumer that labels a series with it.
{% enddocs %}

{% docs metric__program_registry_enrolment__clinical_status_code %}
Code of the patient's current clinical status in the registry -- their position in the
programme's cascade.

One status per patient at a time: the registry holds the current one, and
`int__registration_status_history` holds the passage through them. NULL where the deployment
has not set a status for the enrolment.
{% enddocs %}

{% docs metric__program_registry_enrolment__clinical_status %}
Display name of the current clinical status, for a consumer that labels a series with it.
{% enddocs %}

{% docs metric__program_registry_enrolment__registration_status %}
Whether the registration is `active` or `inactive`. An inactive registration is one the
service has closed; `period_end` carries when.
{% enddocs %}

{% docs metric__program_registry_enrolment__episode_end_source %}
Which rule resolved `period_end`: `deactivation` where a deactivation was recorded on the
registration, `status change` where the boundary came from the logged transition to inactive.

NULL on an open enrolment, and also on a closed one whose change predates the change log's
coverage floor -- that enrolment reads as open, because nothing records when it closed.
{% enddocs %}

{% docs metric__program_registry_enrolment__currently_at_type %}
Whether the registry follows patients by `facility` or by `village`, as it is configured. NULL
where the registry configures neither.
{% enddocs %}

{% docs metric__program_registry_enrolment__currently_at_id %}
Id of the facility or village the patient is currently being followed at, per
`currently_at_type`.

The Tamanu id only. Translating it to a consumer's own identifier -- a Tupaia entity code, a
DHIS2 org unit -- is a consumer-layer concern and is done there, not here.
{% enddocs %}

{% docs program_registry__metric_id %}
Constant 'program_registry_enrolment' -- the id this metric is registered under in
documentations/metrics/*.yml.
{% enddocs %}

{% docs program_registry__variant_id %}
NULL -- this is the standard definition, with no deployment-specific variant. A deployment
that needs a different definition registers a variant_of row in its own metric_definitions
extension and sets this column accordingly.
{% enddocs %}

{% docs program_registry__subject_id %}
The enrolment's episode id (clinical__episode.episode_id), matching the registry's
subject_grain of 'episode'. Tamanu calls the same row a patient program registration.

It is a composite of the patient id and the registry id, so it is unique within the metric by
construction -- a patient can hold one registration per registry -- and a distinct count of
subject_id within one registry_code is a patient count.
{% enddocs %}

{% docs program_registry__period_granularity %}
Constant 'minute' -- period_start and period_end are timestamps resolved to the minute.
{% enddocs %}

{% docs program_registry__value_boolean %}
NULL -- unused by this metric.
{% enddocs %}

{% docs program_registry__age_years %}
Age in whole years at enrolment, from the patient's birth date.

Not banded. An age classification is a presentation choice -- WHO primary bands, the DAK's
0-14/15+ split, a national HMIS grouping -- and deployments differ, so the metric emits the
number and the data table bands it. That keeps one metric usable under every banding rather
than one column per classification.
{% enddocs %}
