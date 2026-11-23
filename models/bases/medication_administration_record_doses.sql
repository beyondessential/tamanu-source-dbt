-- See specs/dbt-model/ds__prescription_administrations.md for BL-010.
{{ incremental_from_table(
    key='id',
    table='medication_administration_record_doses'
) }}
{{ medication_administration_record_doses_base(network=none) }}
