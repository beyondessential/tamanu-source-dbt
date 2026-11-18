{% docs ref__location %}
OMOP LOCATION: one row per location patients are grouped under, with the name and id of
the village, subdivision, division and country it covers. By default a location is a
village, with its subdivision, division and country from the reference-data hierarchy. A
deployment may group patients by other places, such as the division and subdivision
recorded on their registration details.
{% enddocs %}

{% docs ref__location__location_id %}
Unique identifier for the location. By default, the village's id.
{% enddocs %}

{% docs ref__location__location_source_value %}
The location's code. By default, the village's code in Tamanu reference data.
{% enddocs %}

{% docs ref__location__city %}
Name of the village. Blank when the location is not a single village.
{% enddocs %}

{% docs ref__location__county %}
Name of the subdivision. Blank when the location has none.
{% enddocs %}

{% docs ref__location__state %}
Name of the division. Blank when the location has none.
{% enddocs %}

{% docs ref__location__country_source_value %}
Name of the country. Blank when none is known.
{% enddocs %}

{% docs ref__location__village_id %}
Tamanu reference-data id of the village.
{% enddocs %}

{% docs ref__location__subdivision_id %}
Tamanu reference-data id of the subdivision.
{% enddocs %}

{% docs ref__location__division_id %}
Tamanu reference-data id of the division.
{% enddocs %}

{% docs ref__location__country_id %}
Tamanu reference-data id of the country.
{% enddocs %}
