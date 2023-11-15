{% docs table__appointments %}
Table of appointments related to the Vaccination modal.
{% enddocs %}

{% docs appointments__id %}
Tamanu identifier for administered vaccines recorded.
{% enddocs %}

{% docs appointments__batch %}
Batch identifier of administered vaccines recorded.
{% enddocs %}

{% docs appointments__status %}
Status of administered vaccines recorded. 

The `RECORDED_IN_ERROR` status is assigned to vaccines initially recorded
as `GIVEN` that are then deleted.

The `HISTORICAL` status is assigned to vaccines initially recorded as 
`NOT_GIVEN` that are then recorded as `GIVEN`. This `HISTORICAL` status 
keeps a record that the vaccine was marked as `NOT_GIVEN` but hides this
record from the frontend to avoid confusion or conflict with the `GIVEN`
record.

{% enddocs %}

{% docs appointments__reason %}
Reason for administered vaccine's `NOT_GIVEN` status. This is a free text field.
{% enddocs %}

{% docs appointments__injection_site %}
Injection site of the administered vaccine recorded.
{% enddocs %}

{% docs appointments__consent %}
Consent of the administered vaccine recorded
{% enddocs %}

{% docs appointments__given_elsewhere %}
Checks if the vaccine was given elsewhere.
{% enddocs %}

{% docs appointments__vaccine_name %}
Vaccine name.
{% enddocs %}

{% docs appointments__vaccine_brand %}
Vaccine brand.
{% enddocs %}

{% docs appointments__disease %}
Disease the vaccine addresses.
{% enddocs %}

{% docs appointments__consent_given_by %}
Free text field recording consent given by.
{% enddocs %}
