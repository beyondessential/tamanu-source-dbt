{{ incremental_from_table(
    key='id',
    table='invoice_items',
    indexes=[['invoice_id'], ['source_record_type', 'source_record_id']]
) }}
{{ invoice_items_base(network=none) }}
