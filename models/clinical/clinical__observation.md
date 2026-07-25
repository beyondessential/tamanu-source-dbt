{% docs clinical__observation %}
OMOP-lite OBSERVATION domain: one row per clinical fact that is neither a measurement nor a
drug exposure, unioning program/referral-survey answers, vaccinations not given, and triage
assessments. Carries the Tamanu observed fact as the source value with person/visit/provider
foreign keys. observation_concept_id is deferred to the future vocab__ layer.
Deployment-specific observation sources are added by per-deployment override.
{% enddocs %}

{% docs clinical__observation__observation_id %}
Unique identifier for the observation; the OMOP observation_id (the survey_response_answers
or administered_vaccines id, or a synthetic <triage_id>-<element> id for triage rows).
{% enddocs %}

{% docs clinical__observation__observation_date %}
Date component of the observation datetime.
{% enddocs %}

{% docs clinical__observation__observation_datetime %}
Timestamp at which the observation was recorded — the survey response start time, the
vaccination-not-given time, or the triage time (the application-required triage moment).
{% enddocs %}

{% docs clinical__observation__observation_type_source_value %}
Provenance of the observation: 'program survey' or 'referral survey' (survey answer),
'vaccination not given' (a recorded refusal/not-done), or 'triage' (a triage element).
Deployment-specific sources carry their own values when added by override.
{% enddocs %}

{% docs clinical__observation__value_as_number %}
The observed value as a number, when it is numeric (e.g. a numeric survey answer, the triage
score). NULL for non-numeric values and for vaccination-not-given rows.
{% enddocs %}

{% docs clinical__observation__value_source_value %}
The recorded value as entered in Tamanu, retained verbatim — the survey answer, the
not-given reason, or the triage element's value. NULL only for a vaccination-not-given row
where no reason was recorded; the refusal itself is still the observation.
{% enddocs %}

{% docs clinical__observation__provider_id %}
The user associated with the observation — the survey submitter, the triage clinician, or
(for a not-given vaccination) the user who recorded it (recorded_by_id; not the free-text
given_by, which may not reference a Tamanu user). FK to ref__provider for survey/triage rows.
{% enddocs %}

{% docs clinical__observation__visit_occurrence_id %}
The encounter the observation was recorded on; the OMOP visit_occurrence_id. FK to
clinical__visit_occurrence.
{% enddocs %}

{% docs clinical__observation__observation_source_value %}
The Tamanu observed thing's code — the survey data element's code, the vaccine code
(resolved via the scheduled vaccine, NULL if not scheduled), or the triage element key
(triage_score, chief_complaint, secondary_complaint).
{% enddocs %}

{% docs clinical__observation__observation_source_name %}
The observed thing's readable name, denormalised alongside the code.
{% enddocs %}
