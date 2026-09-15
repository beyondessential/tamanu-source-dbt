{% docs clinical__observation_period %}
OMOP-lite OBSERVATION_PERIOD domain: one continuous span per patient during which
clinical events are expected to be captured — bounded by the patient's earliest and
latest recorded activity across visits, conditions, measurements, drug exposures,
and observations. Absence of a record inside the span can be read as absence of the
event; outside it, nothing can be inferred.
{% enddocs %}

{% docs clinical__observation_period__observation_period_id %}
Unique identifier of the observation period. Equals the patient identifier — each
patient has a single period.
{% enddocs %}

{% docs clinical__observation_period__person_id %}
Reference to the patient the observation period belongs to.
{% enddocs %}

{% docs clinical__observation_period__observation_period_start_date %}
Date of the patient's earliest recorded clinical event, across all event domains.
{% enddocs %}

{% docs clinical__observation_period__observation_period_end_date %}
Date of the patient's latest recorded clinical event, across all event domains
(including visit and drug-exposure end dates).
{% enddocs %}

{% docs clinical__observation_period__period_type_concept_id %}
OMOP type concept for how the period was derived. Always 44814724 ("Period covering
healthcare encounters") — periods are inferred from recorded EHR activity.
{% enddocs %}
