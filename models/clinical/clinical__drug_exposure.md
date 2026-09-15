{% docs clinical__drug_exposure %}
OMOP-lite DRUG_EXPOSURE domain: one row per drug exposure, unioning medication prescriptions
(the clinical intent to treat), vaccine administrations (status GIVEN only), and pharmacy
dispenses (the physical hand-over of stock). Carries the Tamanu drug/vaccine as the source
value with person/visit/provider foreign keys. drug_concept_id (RxNorm/CVX) is deferred to
the future vocab__ layer. Deployment-specific drug sources are added by per-deployment
override.
{% enddocs %}

{% docs clinical__drug_exposure__drug_exposure_id %}
Unique identifier for the drug exposure; the OMOP drug_exposure_id (the prescriptions,
administered_vaccines, or medication_dispenses id, depending on branch).
{% enddocs %}

{% docs clinical__drug_exposure__drug_exposure_start_date %}
Date component of the drug exposure start datetime.
{% enddocs %}

{% docs clinical__drug_exposure__drug_exposure_start_datetime %}
Timestamp at which the exposure began — the prescription's start date (falling back to its
date), the vaccination's date, or the dispense's dispensed-at time.
{% enddocs %}

{% docs clinical__drug_exposure__drug_exposure_end_datetime %}
Timestamp at which the exposure ended — the prescription's end date. Vaccinations and
dispenses are point events, so their end equals their start.
{% enddocs %}

{% docs clinical__drug_exposure__drug_exposure_type_source_value %}
Provenance of the exposure: 'prescription' (medication prescribed), 'vaccination' (vaccine
given), or 'dispense' (medication physically dispensed). Deployment-specific sources carry
their own values when added by override.
{% enddocs %}

{% docs clinical__drug_exposure__quantity %}
Quantity associated with the exposure — the prescription's quantity to dispense, or the
dispense's dispensed quantity. NULL for vaccinations.
{% enddocs %}

{% docs clinical__drug_exposure__refills %}
Number of repeats authorised on the prescription. NULL for vaccination and dispense rows.
{% enddocs %}

{% docs clinical__drug_exposure__route_source_value %}
Administration route as recorded in Tamanu — the prescription's route, the vaccination's
injection site, or (for a dispense) the originating prescription's route.
{% enddocs %}

{% docs clinical__drug_exposure__stop_reason %}
Reason the prescription was discontinued, when it was. NULL for vaccination and dispense
rows, and for prescriptions that were not discontinued.
{% enddocs %}

{% docs clinical__drug_exposure__provider_id %}
The user associated with the exposure — the prescriber, or the dispensing pharmacist. For
vaccinations, the user who recorded the administration (recorded_by_id) when captured, else
the free-text given_by name (which may not reference a Tamanu user, so isn't FK-checked for
this branch). FK to ref__provider for prescription and dispense rows.
{% enddocs %}

{% docs clinical__drug_exposure__visit_occurrence_id %}
The encounter the exposure was recorded on; the OMOP visit_occurrence_id. FK to
clinical__visit_occurrence.
{% enddocs %}

{% docs clinical__drug_exposure__drug_source_value %}
The Tamanu drug/vaccine code — reference_data.code for prescriptions and dispenses, or (for
vaccinations) the code resolved via the scheduled vaccine when the dose is scheduled; NULL
for ad hoc/catch-up doses with no schedule.
{% enddocs %}

{% docs clinical__drug_exposure__drug_source_name %}
The drug/vaccine's readable name, denormalised alongside the code. Always populated for
vaccinations (the row's own vaccine_name) regardless of whether drug_source_value resolved.
{% enddocs %}
