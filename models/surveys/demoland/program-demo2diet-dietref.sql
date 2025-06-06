{{
    config(
        materialized='view',
        tags=['survey', 'demoland']
    )
}}

select * from ({{ get_survey('program-demo2diet-dietref') }})
