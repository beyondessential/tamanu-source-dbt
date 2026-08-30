{% docs ds__encounter_invoice_items %}
One row per invoice item (billed line): the resolved unit price, item-level
discount/adjustment, discounted line total and per-item insurance coverage. This is the
line-level companion to `ds__encounter_invoices` (which holds the per-invoice totals). It
is a Tamanu billing construct — there is no "invoice item" in OMOP — so it lives in the
`ds__` layer, not `clinical__`. Line figures reconcile to the invoice totals by
construction (both derive from the shared `int__encounter_invoice_item_amounts`). Payments
are recorded at the invoice level, not the item level, so this dataset carries charges and
coverage only; net payments live on `ds__encounter_invoices`.
{% enddocs %}

{% docs ds__encounter_invoice_items__invoice_item_id %}
Primary key — the invoice item (`invoice_items.id`).
{% enddocs %}

{% docs ds__encounter_invoice_items__invoice_id %}
The invoice this line belongs to.
{% enddocs %}

{% docs ds__encounter_invoice_items__encounter_id %}
The encounter the invoice belongs to.
{% enddocs %}

{% docs ds__encounter_invoice_items__invoice_status %}
Invoice lifecycle status (`in_progress` / `finalised` / `cancelled`), carried so consumers
can exclude cancelled invoices, whose lines still carry charges.
{% enddocs %}

{% docs ds__encounter_invoice_items__item_date %}
The line's order/service date.
{% enddocs %}

{% docs ds__encounter_invoice_items__product_id %}
The invoice product billed on this line.
{% enddocs %}

{% docs ds__encounter_invoice_items__product_name %}
Product name — the finalised `product_name_final`, falling back to the live
`invoice_products.name` for in-progress invoices.
{% enddocs %}

{% docs ds__encounter_invoice_items__category %}
Product category; null for uncategorised products.
{% enddocs %}

{% docs ds__encounter_invoice_items__quantity %}
Line quantity.
{% enddocs %}

{% docs ds__encounter_invoice_items__unit_price %}
Resolved unit price — `price_final`, else the manual entry price, else the matched
price-list price, else 0.
{% enddocs %}

{% docs ds__encounter_invoice_items__item_adjustment %}
Signed item adjustment: `discounted_total − unit_price × quantity`. Negative for a
discount, positive for a markup, 0 when neither — mirroring the app's item adjustment.
{% enddocs %}

{% docs ds__encounter_invoice_items__discounted_total %}
Line total after the item-level discount (`unit_price × quantity`, adjusted). May be
negative if a flat discount exceeds the line total, mirroring the app.
{% enddocs %}

{% docs ds__encounter_invoice_items__insurance_coverage %}
Per-item insurance coverage, capped at the line's discounted total. Null/0 when the line
is not insured. Sums to the invoice's `insurance_coverage` on `ds__encounter_invoices`.
{% enddocs %}

{% docs ds__encounter_invoice_items__source_record_type %}
The Tamanu model of the clinical record that generated this line (`Prescription`,
`LabTest`, `Procedure`, `ImagingRequestArea`); null for manually-added products.
{% enddocs %}

{% docs ds__encounter_invoice_items__source_record_id %}
Foreign key into the `source_record_type` table — the specific clinical record behind
this line.
{% enddocs %}
