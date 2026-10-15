{% docs lab_test_types__is_sensitive_reporting_note %}
The lab requests and lab tests line list reports do not consult this flag: they partition
standard vs. sensitive by the encounter's facility only (whether it belongs to a sensitive
network). Kept here rather than in `models/sources/`, which each Tamanu upgrade regenerates.
{% enddocs %}
