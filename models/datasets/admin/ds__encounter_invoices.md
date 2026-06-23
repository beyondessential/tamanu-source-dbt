{% docs ds__encounter_invoices %}
Invoice financials resolved per invoice, mirroring Tamanu's in-app calculations
(price-list selection, item discounts, insurance coverage, invoice-level
discount, and net patient payments). One row per invoice, carrying a status so
consumers can filter (for example, exclude cancelled) and aggregate per
encounter. Facility-agnostic — any facility or sensitivity scoping is applied by
the consumer.
{% enddocs %}

{% docs ds__encounter_invoices__invoice_datetime %}
Timestamp the invoice was raised.
{% enddocs %}

{% docs ds__encounter_invoices__invoice_finalised_datetime %}
Timestamp of the most recent transition into finalised status, in
deployment-local time. NULL until the invoice is finalised.
{% enddocs %}

{% docs ds__encounter_invoices__invoice_total %}
Sum of the discounted item totals on the invoice (unit price, then item-level
discount, times quantity). NULL when the invoice has no items.
{% enddocs %}

{% docs ds__encounter_invoices__insurance_coverage %}
Total insurance coverage on the invoice's insurable items, rounded to 2 decimal
places. Uses snapshotted finalised coverage when present, otherwise live plan
coverage; per-item coverage is capped at the discounted total.
{% enddocs %}

{% docs ds__encounter_invoices__invoice_discount %}
Invoice-level discount amount, the discount percentage applied to the patient
subtotal (invoice total less insurance coverage), rounded to 2 decimal places.
{% enddocs %}

{% docs ds__encounter_invoices__patient_payment %}
Net patient payment on the invoice: patient payments less refunds. Insurer
payments are excluded.
{% enddocs %}

{% docs ds__encounter_invoices__products_no_category %}
Comma-separated list of products on the invoice that have no category, ordered
by item date.
{% enddocs %}
