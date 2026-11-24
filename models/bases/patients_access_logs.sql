{{ incremental_from_table(
    key='id',
    table='accesses',
    source='logs__tamanu'
) }}
{{ patients_access_logs_base(network=none) }}
