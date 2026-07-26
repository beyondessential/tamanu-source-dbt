{% docs clinical__cost %}
OMOP-lite COST domain: one row per Tamanu invoice, expressing the amount charged,
the amounts actually paid (split by patient and payer), and the insurance coverage
expected. Each row is anchored to the encounter's visit_occurrence. The canonical
billing surface for money-per-encounter, shared by billing reports, cost metrics
and cost/coverage dashboards. The payment-method breakdown (Cash, Mobile Money,
Card, Bank Transfer) is not represented — OMOP COST has no payment-instrument
dimension.
{% enddocs %}

{% docs clinical__cost__cost_id %}
Unique identifier of the cost record. Equal to the invoice identifier — one cost
record per invoice.
{% enddocs %}

{% docs clinical__cost__cost_event_id %}
Identifier of the encounter (visit_occurrence) the invoice belongs to. Links the
cost to the clinical event that incurred it.
{% enddocs %}

{% docs clinical__cost__cost_domain_id %}
OMOP domain of the event the cost is attached to. Always "Visit" — Tamanu costs are
recorded against the encounter.
{% enddocs %}

{% docs clinical__cost__invoice_status %}
Invoice lifecycle status (in_progress / finalised / cancelled), carried so consumers
can exclude cancelled invoices — which still carry a charge. A Tamanu extension; OMOP
COST has no status field.
{% enddocs %}

{% docs clinical__cost__cost_type_concept_id %}
OMOP concept indicating how the cost was derived. Reserved for a billing-system
provenance concept; currently 0 (no matching concept).
{% enddocs %}

{% docs clinical__cost__currency_concept_id %}
OMOP concept for the currency of the monetary amounts. Set per deployment; unset in
the shared model.
{% enddocs %}

{% docs clinical__cost__total_charge %}
Total amount charged on the invoice, after item-level discounts.
{% enddocs %}

{% docs clinical__cost__total_paid %}
Total amount actually received against the invoice — patient payments plus insurer
payments.
{% enddocs %}

{% docs clinical__cost__paid_by_patient %}
Amount paid by the patient, net of any refunds.
{% enddocs %}

{% docs clinical__cost__paid_by_payer %}
Amount actually paid by the insurer, net of any refunds. Distinct from the coverage
expected.
{% enddocs %}

{% docs clinical__cost__amount_allowed %}
Amount insurance is expected to cover on the invoice. An expectation, not
necessarily an amount received.
{% enddocs %}

{% docs clinical__cost__discount_amount %}
The invoice-level discount amount only. Tamanu applies discounts at two levels:
per-item discounts (already netted into total_charge) and a per-invoice discount
(this column). They are separate quantities in the app, so nothing is
double-counted; total_charge stays on the net basis.
{% enddocs %}

{% docs clinical__cost__payer_plan_period_id %}
Identifier of the insurance plan coverage period. Unset until payer plan periods are
modelled.
{% enddocs %}

{% docs clinical__cost__cost_source_value %}
Human-facing invoice number as shown in Tamanu.
{% enddocs %}
