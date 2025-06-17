{% set drugs = [
    {'drug': 'MEDDIS03', 'dose': 'MEDDIS04' },
    {'drug': 'MEDDIS09', 'dose': 'MEDDIS10' },
    {'drug': 'MEDDIS15', 'dose': 'MEDDIS16' },
    {'drug': 'MEDDIS21', 'dose': 'MEDDIS22' },
    {'drug': 'MEDDIS27', 'dose': 'MEDDIS28' },
    {'drug': 'MEDDIS33', 'dose': 'MEDDIS34' },
    {'drug': 'MEDDIS39', 'dose': 'MEDDIS40' },
    {'drug': 'MEDDIS45', 'dose': 'MEDDIS46' },
    {'drug': 'MEDDIS51', 'dose': 'MEDDIS52' },
    {'drug': 'MEDDIS57', 'dose': 'MEDDIS58' },
    {'drug': 'MEDDIS63', 'dose': 'MEDDIS64' },
    {'drug': 'MEDDIS69', 'dose': 'MEDDIS70' },
    {'drug': 'MEDDIS75', 'dose': 'MEDDIS76' },
    {'drug': 'MEDDIS81', 'dose': 'MEDDIS82' },
    {'drug': 'MEDDIS87', 'dose': 'MEDDIS88' }
] %}

with drugs_dispensed as (
    {% for drug in drugs %}
        select
            ppm.patient_id,
            l.facility_id,
            coalesce(ppm.MEDDIS00::timestamp, ppm.start_datetime) as datetime_dispensed,
            {{ drug.drug }} as drug,
            {{ drug.dose }} as dose
        from {{ ref("program-pharmacy-meddisp001") }} ppm
        join {{ ref("encounter")}} e on e.id = ppm.encounter_id
        join {{ ref("location")}} l on l.id = e.location_id
        where {{ drug.drug }} is not null
        {% if not loop.last %}
        union all
        {% endif %}
    {% endfor %}
)

select 
    dg.name as {{ translate_label('surveyMedicationDispensingDrug', 'Drug')}},
    count(distinct dd.patient_id) as {{ translate_label('surveyMedicationDispensingPatientCount', 'Number of Unique Patients')}},
    sum(dd.dose) as {{ translate_label('surveyMedicationDispensingDoseCount', 'Number of Doses')}}
from drugs_dispensed dd
join {{ ref('reference_data')}} dg on dg.id = dd.drug
where case
        when {{ parameter('facilityId') }} is null then true
        else dd.facility_id = {{ parameter('facilityId') }}
    end
    and
    case
        when {{ parameter('drugId') }} is null then true
        else dd.drug = {{ parameter('drugId') }}
    end 
    and
    case
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }} is null then true
        else dd.datetime_dispensed
            >= {{ parameter('fromDate', default_value='2024-01-01', data_type='timestamp') }}
    end
    and
    case
        when {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }} is null then true
        else dd.datetime_dispensed
            <= {{ parameter('toDate', default_value='2024-01-31', data_type='timestamp') }}
    end
group by dg.name