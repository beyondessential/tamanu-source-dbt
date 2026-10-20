{% docs ds__invoice_products %}
Invoice products pivoted with their prices and charging type across all price lists and insurance coverage across all insurance plans. One row per product.
{% enddocs %}

{% docs ds__invoice_products__available_facilities %}
Comma-separated list of facility names where this product is available. NULL means the product is available at all facilities.
{% enddocs %}

{% docs ds__invoice_products__available_facility_ids %}
JSON array of facility ids where this product is available, taken from the originating reference data, lab test panel or lab test type. NULL or an empty array means the product is available at all facilities.
{% enddocs %}
