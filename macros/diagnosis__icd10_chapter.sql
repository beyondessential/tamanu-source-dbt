{% macro diagnosis__icd10_chapter(code_column) %}
{#
    WHO ICD-10 chapter for a diagnosis code, labelled "<chapter number> <chapter title>"
    using the Roman numeral ICD-10 itself uses (e.g. 'X Diseases of the respiratory
    system').

    Source: WHO ICD-10 (2019 edition) chapter code ranges,
    https://icd.who.int/browse10/2019/en

    Named diagnosis__<grouping>: the concept before the `__`, the grouping after it, so a
    deployment preferring a different one adds diagnosis__icd10_block or
    diagnosis__dhims2_group alongside rather than redefining this. Groupings are not
    comparable with each other, which is why the name carries which one produced the value
    -- the same convention as age_group__who_primary_classification.

    Matching is on the first three characters of the code, upper-cased. ICD-10 codes are
    letter + two zero-padded digits, optionally followed by '.' and further detail, so a
    three-character prefix sorts correctly within a letter block and a plain text `between`
    is enough -- no integer cast, which would raise on dirty reference data.

    Parameters:
    - code_column: SQL expression yielding an ICD-10 code (Tamanu reference_data.code).

    Returns: CASE expression producing the chapter label, or 'Unclassified' when the code
    is null, malformed, or falls in one of ICD-10's unassigned gaps (D49, E91-E99,
    H96-H99, K94-K99, P97-P99, Y99). 'Unclassified' means "a code was recorded but does not
    resolve to a chapter" -- a *missing* diagnosis is the caller's concern, not this macro's.
#}
    case
        when left(upper({{ code_column }}), 3) between 'A00' and 'B99' then 'I Certain infectious and parasitic diseases'
        when left(upper({{ code_column }}), 3) between 'C00' and 'D48' then 'II Neoplasms'
        when left(upper({{ code_column }}), 3) between 'D50' and 'D89' then 'III Diseases of the blood and blood-forming organs and certain disorders involving the immune mechanism'
        when left(upper({{ code_column }}), 3) between 'E00' and 'E90' then 'IV Endocrine, nutritional and metabolic diseases'
        when left(upper({{ code_column }}), 3) between 'F00' and 'F99' then 'V Mental and behavioural disorders'
        when left(upper({{ code_column }}), 3) between 'G00' and 'G99' then 'VI Diseases of the nervous system'
        when left(upper({{ code_column }}), 3) between 'H00' and 'H59' then 'VII Diseases of the eye and adnexa'
        when left(upper({{ code_column }}), 3) between 'H60' and 'H95' then 'VIII Diseases of the ear and mastoid process'
        when left(upper({{ code_column }}), 3) between 'I00' and 'I99' then 'IX Diseases of the circulatory system'
        when left(upper({{ code_column }}), 3) between 'J00' and 'J99' then 'X Diseases of the respiratory system'
        when left(upper({{ code_column }}), 3) between 'K00' and 'K93' then 'XI Diseases of the digestive system'
        when left(upper({{ code_column }}), 3) between 'L00' and 'L99' then 'XII Diseases of the skin and subcutaneous tissue'
        when left(upper({{ code_column }}), 3) between 'M00' and 'M99' then 'XIII Diseases of the musculoskeletal system and connective tissue'
        when left(upper({{ code_column }}), 3) between 'N00' and 'N99' then 'XIV Diseases of the genitourinary system'
        when left(upper({{ code_column }}), 3) between 'O00' and 'O99' then 'XV Pregnancy, childbirth and the puerperium'
        when left(upper({{ code_column }}), 3) between 'P00' and 'P96' then 'XVI Certain conditions originating in the perinatal period'
        when left(upper({{ code_column }}), 3) between 'Q00' and 'Q99' then 'XVII Congenital malformations, deformations and chromosomal abnormalities'
        when left(upper({{ code_column }}), 3) between 'R00' and 'R99' then 'XVIII Symptoms, signs and abnormal clinical and laboratory findings, not elsewhere classified'
        when left(upper({{ code_column }}), 3) between 'S00' and 'T98' then 'XIX Injury, poisoning and certain other consequences of external causes'
        when left(upper({{ code_column }}), 3) between 'U00' and 'U99' then 'XXII Codes for special purposes'
        when left(upper({{ code_column }}), 3) between 'V01' and 'Y98' then 'XX External causes of morbidity and mortality'
        when left(upper({{ code_column }}), 3) between 'Z00' and 'Z99' then 'XXI Factors influencing health status and contact with health services'
        else 'Unclassified'
    end
{% endmacro %}
