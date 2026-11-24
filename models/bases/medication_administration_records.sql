-- See specs/dbt-model/ds__prescription_administrations.md for BL-001..BL-002.
{{ incremental_from_table(
    key='id',
    table='medication_administration_records'
) }}
{{ medication_administration_records_base(network=none) }}
