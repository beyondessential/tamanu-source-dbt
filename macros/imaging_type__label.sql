{% macro imaging_type__label(imaging_type_column) %}
{#
    Readable label for a raw Tamanu imaging_type value (e.g. 'xRay' -> 'X-Ray').

    Named imaging_type__label: the concept before the `__`, the labelling scheme after it,
    the same convention as diagnosis__icd10_chapter and age_group__who_primary_classification
    -- a deployment wanting a different label set (e.g. translated) adds
    imaging_type__<scheme> alongside rather than redefining this.

    There is no reference-data lookup for imaging_type the way procedure_type_id has one --
    it is a fixed application-level enum -- so this is a literal mapping, not a join.

    Parameters:
    - imaging_type_column: SQL expression yielding a raw imaging_requests.imaging_type value.

    Returns: CASE expression producing the readable label, or the raw value unchanged where
    it is not one of the fifteen recognised values (never NULL unless the input itself is).
#}
    case
        when {{ imaging_type_column }} = 'xRay' then 'X-Ray'
        when {{ imaging_type_column }} = 'ctScan' then 'CT Scan'
        when {{ imaging_type_column }} = 'ultrasound' then 'Ultrasound'
        when {{ imaging_type_column }} = 'mri' then 'MRI'
        when {{ imaging_type_column }} = 'ecg' then 'ECG'
        when {{ imaging_type_column }} = 'holterMonitor' then 'Holter Monitor'
        when {{ imaging_type_column }} = 'echocardiogram' then 'Echocardiogram'
        when {{ imaging_type_column }} = 'mammogram' then 'Mammogram'
        when {{ imaging_type_column }} = 'endoscopy' then 'Endoscopy'
        when {{ imaging_type_column }} = 'fluroscopy' then 'Fluroscopy'
        when {{ imaging_type_column }} = 'angiogram' then 'Angiogram'
        when {{ imaging_type_column }} = 'colonoscopy' then 'Colonoscopy'
        when {{ imaging_type_column }} = 'vascularStudy' then 'Vascular Study'
        when {{ imaging_type_column }} = 'stressTest' then 'Stress Test'
        else {{ imaging_type_column }}
    end
{% endmacro %}
