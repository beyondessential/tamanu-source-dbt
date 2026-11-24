{{ incremental_from_table(
    key='encounter_id',
    table='discharges'
) }}
{{ discharges_base(network=none) }}
