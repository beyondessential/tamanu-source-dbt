{% docs base__facilities %}
Standard facilities: every facility that belongs to no sensitive network. Standard datasets and
reports read this model and leave out data recorded at a sensitive facility.

Sensitive facilities are in `sensitive_facilities`. The two models together hold every facility,
and no facility is in both.
{% enddocs %}

{% docs base__sensitive_facilities %}
Sensitive facilities: every facility that belongs to a sensitive network. Only sensitive datasets
and reports read this model.

Standard facilities are in `facilities`. The two models together hold every facility, and no
facility is in both.
{% enddocs %}
