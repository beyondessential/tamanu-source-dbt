{% docs ref__provider %}
OMOP PROVIDER wrapper over Tamanu users: one row per user (clinician/examiner), giving
clinical models a stable, OMOP-named FK target for provider_id. A thin projection over
bases/users — specialty, care site, and demographics are intentionally not emitted.
{% enddocs %}

{% docs ref__provider__provider_id %}
Unique identifier for the user; the OMOP provider_id.
{% enddocs %}

{% docs ref__provider__provider_name %}
The user's full display name.
{% enddocs %}

{% docs ref__provider__provider_source_value %}
The user's Tamanu display identifier (business identifier).
{% enddocs %}

{% docs ref__provider__role %}
The Tamanu account role (e.g. practitioner, admin). Single-valued; carried to distinguish
clinical from non-clinical users. Not the clinical specialty (designations are a
many-to-many and are not modelled here).
{% enddocs %}
