{% docs metric__billing %}
D5 metric view for the patient billing indicators registered in
documentations/metrics/billing.yml.

Seven metrics have one row per non-cancelled invoice, dated to the invoice: the invoice count,
invoice total, insurance coverage, invoice discount, patient total, patient paid to date and
patient balance. The eighth, invoice_patient_payment, has one row per patient payment or refund,
dated to the day it was made, with refunds negative.

Sum value_numeric for one metric_id at a time, over any subset of the disaggregations and any
time grain. Never sum across metric_ids. Coverage and collection rates are ratios of sums, for
example invoice_insurance_coverage over invoice_total.

The two time bases reconcile. The outstanding patient balance at the end of a month is the
running sum of invoice_patient_total less the running sum of invoice_patient_payment, both up to
that month.

See specs/dbt-model/metric__billing.md.
{% enddocs %}

{% docs metric__billing__metric_id %}
The billing indicator the row measures. Filter to one metric_id before summing.
{% enddocs %}

{% docs metric__billing__variant_id %}
Empty. This is the standard definition, with no deployment-specific variant.
{% enddocs %}

{% docs metric__billing__subject_id %}
The invoice the row describes, or for invoice_patient_payment, the payment.
{% enddocs %}

{% docs metric__billing__period_start %}
When the row is dated: the invoice's date and time for invoice metrics, or the payment date for
invoice_patient_payment.
{% enddocs %}

{% docs metric__billing__period_granularity %}
How precise period_start is: minute for invoice metrics, day for payments.
{% enddocs %}

{% docs metric__billing__value_numeric %}
The count or amount. Amounts are in the deployment's billing currency. A patient balance is
negative when the invoice is overpaid, and a refund is a negative payment.
{% enddocs %}

{% docs metric__billing__invoice_status %}
The invoice's status: in progress or finalised. Cancelled invoices are not included.
{% enddocs %}

{% docs metric__billing__encounter_type %}
The Tamanu encounter type of the invoice's encounter, for example clinic, emergency, admission
or surveyResponse.
{% enddocs %}
