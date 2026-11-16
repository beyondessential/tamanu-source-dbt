{% docs metric__who_dak_anc_indicators %}
D5 metric view for the WHO SMART guidelines antenatal care Digital Adaptation Kit indicators
registered in documentations/metrics/who_dak_anc.yml. One row per antenatal care contact and
definition.

| Metric | Measures |
|---|---|
| `who_dak_anc_contact` | Antenatal care contacts — the contacts the DAK's `ANC.IND.4` and `ANC.IND.5` count per pregnancy |
| `who_dak_anc_contact_samoa` | Antenatal care contacts under Samoa Ministry of Health's definition (variant `samoa_moh_2026`) |

**Two routes in, one definition.** A deployment either captures antenatal care on the
`who-dak-anc` program forms, whose questions are the DAK's own data elements, or keeps its own
antenatal forms and maps their questions to DAK data elements in its configuration. Both are read
the same way, so a contact means the same thing on every deployment.

**A contact is a woman seen on a day.** It is recorded by a contact form — the DAK's ANC
Registration form, or a local form the deployment marks as one — and dated by the form's
*Contact date*, or by when the form was filled in where that is blank. Two contact forms for the
same woman on the same day are one contact. The contact number and gestational age come from any
antenatal form filled in for her that day, and are blank when there is none.

**Samoa's definition is a separate metric.** Samoa Ministry of Health records antenatal care on
its own forms and at antenatal clinic visits, so its definition also counts a visit to a named
antenatal clinic as a contact, works out gestational age and gravida where they are not recorded,
and leaves out patients younger than 10. Its rows are `who_dak_anc_contact_samoa`, so the DAK
definition's rows stay as the DAK states them.

**Counts only.** Antenatal coverage needs an expected-pregnancies estimate Tamanu does not hold,
so the consumer forms it against its own estimate.

**Capture practice differs.** Contact counts from different deployments rest on different forms,
so compare them with care.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__metric_id %}
The registered indicator this row counts towards: `who_dak_anc_contact` for the WHO DAK definition,
or `who_dak_anc_contact_samoa` for Samoa Ministry of Health's.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__variant_id %}
Deployment variant of the definition. NULL: the WHO DAK definition. `samoa_moh_2026`: Samoa Ministry
of Health's, which also counts visits to antenatal clinics, works out gestational age and gravida
where they are not recorded, and leaves out patients younger than 10.
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
Gestational age in weeks recorded on the day of the contact, as entered. Under Samoa Ministry of
Health's definition, where none was recorded, the whole weeks since the last menstrual period, or
worked out from the expected date of delivery, and blank outside 0 to 45 weeks.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__lmp_date %}
The first day of the woman's last menstrual period, as recorded on the day of the contact.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__edd_date %}
The expected date of delivery, as recorded on the day of the contact.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__gravida %}
How many times the woman has been pregnant, including this pregnancy, as recorded on the day of
the contact. Under Samoa Ministry of Health's definition, where none was recorded, her parity plus
her miscarriages and abortions plus this pregnancy.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__miscarriages_abortions %}
The number of the woman's previous pregnancies that ended in a miscarriage or abortion, as recorded
on the day of the contact.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__parity %}
The number of the woman's previous live births and stillbirths, as recorded on the day of the
contact.
{% enddocs %}

{% docs metric__who_dak_anc_indicators__tt_dose_date %}
The date the woman received this dose of a tetanus toxoid-containing vaccine, as recorded on the day
of the contact.
{% enddocs %}
