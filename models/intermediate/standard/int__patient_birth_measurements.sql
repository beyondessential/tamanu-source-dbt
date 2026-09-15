-- int__patient_birth_measurements -- unpivots the wide patient_birth_data into one row per
-- recorded birth measurement (tall shape), for the birth-data branch of clinical__measurement.
-- Inner-joins patients (which filters deleted/test/merged patients and supplies the birth
-- date), so every row is a valid patient; birth measurements are patient-level (no encounter).
-- Values are kept as text here; the numeric cast happens in clinical__measurement.

with patient_birth_data as (
    select * from {{ ref('patient_birth_data') }}
),

patients as (
    select * from {{ ref('patients') }}
),

birth as (
    select
        pbd.patient_id,
        pbd.birth_weight,
        pbd.birth_length,
        pbd.apgar_score_one_minute,
        pbd.apgar_score_five_minutes,
        pbd.apgar_score_ten_minutes,
        pbd.gestational_age_estimate,
        -- a birth measurement is taken at birth; fall back to the registration date
        coalesce(
            (p.date_of_birth + pbd.birth_time)::timestamp,
            p.date_of_birth::timestamp,
            pbd.registration_date::timestamp
        ) as measurement_datetime
    from patient_birth_data pbd
    join patients p on p.id = pbd.patient_id
)

-- one row per recorded measure; blanks are dropped
select
    b.patient_id,
    m.measurement_source_value,
    m.measurement_source_name,
    m.value_source_value,
    b.measurement_datetime
from birth b
cross join lateral (values
    ('birth_weight',             'Birth weight',             b.birth_weight::varchar),
    ('birth_length',             'Birth length',             b.birth_length::varchar),
    ('apgar_score_one_minute',   'APGAR score (1 minute)',   b.apgar_score_one_minute::varchar),
    ('apgar_score_five_minutes', 'APGAR score (5 minutes)',  b.apgar_score_five_minutes::varchar),
    ('apgar_score_ten_minutes',  'APGAR score (10 minutes)', b.apgar_score_ten_minutes::varchar),
    ('gestational_age_estimate', 'Gestational age estimate', b.gestational_age_estimate::varchar)
) as m (measurement_source_value, measurement_source_name, value_source_value)
where m.value_source_value is not null and trim(m.value_source_value) != ''
