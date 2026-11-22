-- int__sensitive_encounter_invoice_amounts -- per-invoice billing arithmetic for sensitive
-- facilities, one row per invoice. Consumed by ds__sensitive_encounter_invoices. The body is
-- the encounter_invoice_amounts() macro, shared with int__encounter_invoice_amounts.
-- Ephemeral: inlined by consumers.
{{ encounter_invoice_amounts(is_sensitive=true) }}
