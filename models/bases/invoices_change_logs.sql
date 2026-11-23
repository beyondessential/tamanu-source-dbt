{{ incremental_from_logs(
    key='invoice_id',
    table='invoices',
    key_type='uuid'
) }}
{{ invoices_change_logs_base(network=none) }}
