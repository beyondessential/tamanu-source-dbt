{% docs ref__location %}
OMOP LOCATION wrapper over Tamanu geographic reference data: one row per village,
denormalised so each village also carries the names of its subdivision, division, and
country resolved by walking the reference-data hierarchy. Gives clinical models a
stable, OMOP-named join target for patient geography.
{% enddocs %}

{% docs ref__location__location_id %}
Unique identifier for the village; the OMOP location_id.
{% enddocs %}

{% docs ref__location__location_source_value %}
The village's source code in Tamanu reference data.
{% enddocs %}

{% docs ref__location__city %}
Name of the village.
{% enddocs %}

{% docs ref__location__county %}
Name of the village's subdivision-level ancestor. NULL when there is no subdivision
above it.
{% enddocs %}

{% docs ref__location__state %}
Name of the village's division-level ancestor. NULL when there is no division above it.
{% enddocs %}

{% docs ref__location__country_source_value %}
Name of the village's country-level ancestor. NULL when there is no country above it.
{% enddocs %}
