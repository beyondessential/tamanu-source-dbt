{{ incremental_from_logs(
    key='discharge_id',
    table='discharges'
) }}
{{ discharges_change_logs_base(network=none) }}
