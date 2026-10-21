{% docs metric__who_dak_anc_indicators %}
D5 metric view for the WHO SMART guidelines antenatal care Digital Adaptation Kit indicators
registered in documentations/metrics/who_dak_anc.yml. One row per antenatal care contact.

| Metric | Measures |
|---|---|
| `who_dak_anc_contact` | Antenatal care contacts — the contacts the DAK's `ANC.IND.4` and `ANC.IND.5` count per pregnancy |

**Two routes in, one definition.** A deployment either captures antenatal care on the
`who-dak-anc` program forms, whose questions are the DAK's own data elements, or keeps its own
antenatal forms and maps their questions to DAK data elements in its configuration. Both are read
the same way, so a contact means the same thing on every deployment.

**A contact is a woman seen on a day.** It is recorded by a contact form — the DAK's ANC
Registration form, or a local form the deployment marks as one — and dated by the form's
*Contact date*, or by when the form was filled in where that is blank. Two contact forms for the
same woman on the same day are one contact. The contact number and gestational age come from any
antenatal form filled in for her that day.

**Counts only.** Antenatal coverage needs an expected-pregnancies estimate Tamanu does not hold,
so the consumer forms it against its own estimate.

**Capture practice differs.** Contact counts from different deployments rest on different forms,
so compare them with care.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__metric_id %}
The registered indicator this row counts towards. Always `who_dak_anc_contact`.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__variant_id %}
Deployment variant of the definition. NULL: this is the standard definition.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__subject_id %}
Identifies the contact: the woman and the contact day.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__period_start %}
The day of the contact.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__period_end %}
The day of the contact. Equal to period_start, since a contact is a point event.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__period_granularity %}
Always `day`.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__value_numeric %}
Always 1, so summing it counts contacts.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__value_boolean %}
Not used. NULL.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__facility_id %}
The facility where the contact was recorded. NULL where the contact's encounter has no
location.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__person_id %}
The pregnant woman.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__age_years %}
The woman's age in whole years on the day of the contact. Not banded: the dashboard groups it
into its own age bands.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__contact_number %}
The ANC contact number recorded for this contact, as entered. NULL where none was recorded.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__gestational_age_weeks %}
Gestational age in weeks recorded on the day of the contact, as entered. NULL where none was
recorded.
{% enddocs %}
