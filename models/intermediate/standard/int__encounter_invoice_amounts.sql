-- int__encounter_invoice_amounts -- per-invoice billing arithmetic for standard facilities,
-- one row per invoice. Consumed by ds__encounter_invoices and clinical__cost. The body is
-- the encounter_invoice_amounts() macro, shared with int__sensitive_encounter_invoice_amounts.
-- Ephemeral: inlined by consumers.
{{ encounter_invoice_amounts(is_sensitive=false) }}
