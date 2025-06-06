{{
    config(
        materialized='view',
        tags=['survey', 'demoland']
    )
}}

select * from ({{ get_survey('program-disabilitydatacollection-wgss') }})
