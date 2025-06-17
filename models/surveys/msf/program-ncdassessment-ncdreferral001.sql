{{
    config(
        materialized='view',
        tags=['survey', 'msf']
    )
}}

select * from ({{ get_survey('program-ncdassessment-ncdreferral001') }})
