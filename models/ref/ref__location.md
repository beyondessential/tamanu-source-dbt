{% docs ref__location %}
OMOP LOCATION for patient addresses: one row per combination of village, subdivision and
division that patients live at, with the name and id of each level, and of the country above
them. A level the patient's registration details record is taken as recorded; a level left
blank is filled from the village's place in the reference-data hierarchy.
{% enddocs %}

{% docs ref__location__location_id %}
Identifier for the address: the village, subdivision and division ids joined by underscores,
with unknown in place of a level that is not known.
{% enddocs %}

{% docs ref__location__location_source_value %}
The address identifier as built from Tamanu's reference-data ids. Equal to location_id.
{% enddocs %}

{% docs ref__location__city %}
Name of the village. Blank when the address has no village.
{% enddocs %}

{% docs ref__location__county %}
Name of the subdivision. Blank when the address has no subdivision.
{% enddocs %}

{% docs ref__location__state %}
Name of the division. Blank when the address has no division.
{% enddocs %}

{% docs ref__location__country_source_value %}
Name of the country above the address's division, subdivision or village. Blank when none is
known.
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
