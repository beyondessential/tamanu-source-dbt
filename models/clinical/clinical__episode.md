{% docs clinical__episode %}
OMOP-lite EPISODE domain: one row per patient enrolment in a program registry — the
programme a patient is being followed under, the clinical status they currently hold in
it, and where they are currently managed. An enrolment spans encounters rather than
sitting inside one, which makes this the clinical layer's longitudinal subject.

OMOP categorises EPISODE as a derived element because episodes are usually inferred from
occurrences. These are asserted: one row per source record, nothing computed. An episode
that has to be assembled — an ART regimen line collapsed from consecutive same-regimen
answers — belongs in `derived__` instead, parented to a row here.
{% enddocs %}

{% docs clinical__episode__episode_id %}
Unique identifier of the episode. The Tamanu registration id, itself a deterministic
composite of the patient and registry ids, so it is unique without a remap to an OMOP
integer id.
{% enddocs %}

{% docs clinical__episode__person_id %}
The enrolled patient. Foreign key to `clinical__person.person_id`.
{% enddocs %}

{% docs clinical__episode__episode_concept_id %}
Standard concept for the kind of episode. NULL — deferred to the future `vocab__` layer.
{% enddocs %}

{% docs clinical__episode__episode_object_concept_id %}
Standard concept for what the episode is about — for an enrolment, the programme's
condition. NULL — deferred to the future `vocab__` layer.
{% enddocs %}

{% docs clinical__episode__episode_start_date %}
Date the patient was enrolled.
{% enddocs %}

{% docs clinical__episode__episode_start_datetime %}
Datetime the patient was enrolled. Always non-null.
{% enddocs %}

{% docs clinical__episode__episode_end_date %}
Date the enrolment ended, NULL while it is open.
{% enddocs %}

{% docs clinical__episode__episode_end_datetime %}
Datetime the enrolment ended, NULL while it is open.

Taken from the deactivation datetime when one is recorded. Where the registration is
inactive without one, it is the earliest logged transition to inactive, recovered from the
change log — the registration table is updated in place and holds no history of its own.

A registration marked inactive whose transition predates the change log's coverage floor
(Tamanu 2.33.0) has neither, and reads as open. `episode_end_source` distinguishes the
cases.
{% enddocs %}

{% docs clinical__episode__episode_end_source %}
Which rule closed the episode: `deactivation` where a deactivation datetime was recorded,
`status change` where the end came from the logged transition to inactive, NULL while the
episode is open.

Two episodes ending on the same date are not equivalent — one was deactivated explicitly,
the other inferred — and a retention denominator that cannot tell them apart is reporting
two different things as one.
{% enddocs %}

{% docs clinical__episode__episode_type_source_value %}
Provenance of the episode, and the discriminator for a future second source. Constant
`program registry` here.
{% enddocs %}

{% docs clinical__episode__episode_source_value %}
Code of the program registry the patient is enrolled in.
{% enddocs %}

{% docs clinical__episode__episode_source_name %}
Name of the program registry the patient is enrolled in.
{% enddocs %}

{% docs clinical__episode__program_registry_id %}
The program registry the patient is enrolled in. `episode_source_value` carries its code and
`episode_source_name` its name; this is the key itself, for a consumer joining back to the
registry's own configuration.
{% enddocs %}

{% docs clinical__episode__program_id %}
The program the registry belongs to.
{% enddocs %}

{% docs clinical__episode__episode_parent_id %}
Parent episode, for a nested episode such as a treatment line under a disease episode.
NULL — one enrolment per patient per registry, so there is no parent. Present for schema
conformance, and populated by any future `derived__episode_*` child.
{% enddocs %}

{% docs clinical__episode__episode_number %}
Sequence of this episode among its siblings under a parent. NULL — nothing to sequence.
{% enddocs %}

{% docs clinical__episode__registration_status %}
Whether the enrolment is `active` or `inactive`. Enrolments recorded in error are
excluded from the model entirely.
{% enddocs %}

{% docs clinical__episode__clinical_status_id %}
Key of the clinical status the patient currently holds in this registry, NULL where no status
has been set. `clinical_status_source_value` and `clinical_status_source_name` carry its code
and name.
{% enddocs %}

{% docs clinical__episode__clinical_status_source_value %}
Code of the clinical status the patient currently holds in this registry — for an HIV
registry, one of the cascade positions such as on ART or lost to follow up. NULL where no
status has been set.

This is current state only. A status the patient passed through is visible in
`int__registration_status_history`.
{% enddocs %}

{% docs clinical__episode__clinical_status_source_name %}
Name of the clinical status the patient currently holds.
{% enddocs %}

{% docs clinical__episode__currently_at_type %}
Whether the registry tracks where a patient is currently managed by `facility` or by
`village`, from the registry's own configuration.
{% enddocs %}

{% docs clinical__episode__currently_at_id %}
The facility or village the patient is currently managed at, whichever
`currently_at_type` names. The other column on the source record is ignored even when
populated, since only the configured one is maintained.
{% enddocs %}

{% docs clinical__episode__currently_at_name %}
Name of the facility or village the patient is currently managed at.
{% enddocs %}

{% docs clinical__episode__care_site_id %}
Facility the patient was enrolled at. Foreign key to `ref__care_site.care_site_id`, resolving
to a `care_site_type = 'facility'` row.

Coarser than the care site on a visit, which is a location: an enrolment is registered at a
facility and never at a room. `ref__care_site` carries a row per facility for this reason, so
the clinical layer keeps one care-site join target across every grain.
{% enddocs %}

{% docs clinical__episode__provider_id %}
Clinician who enrolled the patient. Foreign key to `ref__provider.provider_id`.
{% enddocs %}

{% docs clinical__episode__deactivated_datetime %}
Datetime the patient was removed from the registry, as recorded on the registration.

This is the source fact, not the episode boundary: `episode_end_datetime` falls back to the
logged transition to inactive where no deactivation was recorded, and stays NULL on an active
registration even where a stale deactivation stamp survives a reactivation.
{% enddocs %}

{% docs clinical__episode__deactivated_by_provider_id %}
Clinician who removed the patient from the registry, NULL while the enrolment is open.
{% enddocs %}
