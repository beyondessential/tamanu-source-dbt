select {{ dbt_utils.star(from=ref('ds__births_translated'), except=['village_id', 'birth_facility_id', 'patient_id']) }} 
from {{ ref("ds__births_translated") }}  
where  
    case  
        when {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }} is null then true  
        else TO_DATE("{{ translate_string('general.localisedField.dateOfBirth.label', var('language'), 'Date of birth') }}", 'DD/MM/YYYY') 
             >= {{ parameter('fromDate', default_value='2024-01-01', data_type='date') }}  
    end  
    and  
    case  
        when {{ parameter('toDate', default_value='2024-01-31', data_type='date') }} is null then true  
        else TO_DATE("{{ translate_string('general.localisedField.dateOfBirth.label', var('language'), 'Date of birth') }}", 'DD/MM/YYYY') 
             <= {{ parameter('toDate', default_value='2024-01-31', data_type='date') }}  
    end
    and  
    case  
        when {{ parameter('villageId') }} is null then true  
        else village_id = {{ parameter('villageId') }}  
    end
    and  
    case  
        when {{ parameter('facilityId') }} is null then true  
        else birth_facility_id = {{ parameter('facilityId') }}  
    end
