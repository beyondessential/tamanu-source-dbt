{% macro diagnosis__icd10_obstetric_block(code_column) %}
{#
    WHO ICD-10 Chapter XV blocks -- Pregnancy, childbirth and the puerperium, O00-O99 --
    labelled "<code range> <block title>" (e.g. 'O60-O75 Complications of labour and
    delivery').

    Source: WHO ICD-10 (2019 edition) Chapter XV block ranges,
    https://icd.who.int/browse10/2019/en

    For obstetric casemix: the level at which a maternity service's presentations separate
    into hypertensive disorders, complications of labour, complications of the puerperium and
    the rest. Chapter granularity resolves that population to a single value, so the block is
    the first level that distinguishes anything.

    Ranges follow WHO ICD-10, where O09, O17-O19, O49-O59, O76-O79 and O93 are unassigned
    gaps -- the blocks are not contiguous. ICD-10-CM both draws three blocks differently
    (O60-O77, O80-O82, O94-O9A) and assigns O09 (Supervision of high risk pregnancy), so a
    CM-derived reference set yields codes that land in a WHO gap. Take ranges from a WHO or
    WHO-derived tabular list when extending this.

    A code outside O00-O99 returns 'Non-obstetric', which keeps the non-obstetric
    presentations a maternity service does see as their own readable group, distinct from
    codes that failed to resolve at all.

    Named diagnosis__<grouping> so the value carries which grouping produced it -- groupings
    are not comparable with each other. Scoped to chapter XV; a general block macro covers
    every chapter's ~130 blocks and is its own piece of work.

    Matching is on the first three characters of the code, upper-cased -- see
    diagnosis__icd10_chapter for why a plain text `between` is enough and an integer cast
    would be worse.

    Parameters:
    - code_column: SQL expression yielding an ICD-10 code (Tamanu reference_data.code).

    Returns: CASE expression producing the block label; 'Non-obstetric' for a code outside
    O00-O99; 'Unclassified' when the code is null, falls in one of chapter XV's unassigned
    gaps (O09, O17-O19, O49-O59, O76-O79, O93), or is malformed in a way that leaves its
    three-character prefix outside A00-Z99.

    A malformed code whose prefix still looks alphabetic -- 'OBS', 'XYZ' -- satisfies the
    A00-Z99 branch and returns 'Non-obstetric'. diagnosis__icd10_chapter has the same
    behaviour, so requiring the two characters after the letter to be digits is a change to
    make in both at once rather than here alone.
#}
    case
        when left(upper({{ code_column }}), 3) between 'O00' and 'O08' then 'O00-O08 Pregnancy with abortive outcome'
        when left(upper({{ code_column }}), 3) between 'O10' and 'O16' then 'O10-O16 Oedema, proteinuria and hypertensive disorders in pregnancy, childbirth and the puerperium'
        when left(upper({{ code_column }}), 3) between 'O20' and 'O29' then 'O20-O29 Other maternal disorders predominantly related to pregnancy'
        when left(upper({{ code_column }}), 3) between 'O30' and 'O48' then 'O30-O48 Maternal care related to the fetus and amniotic cavity and possible delivery problems'
        when left(upper({{ code_column }}), 3) between 'O60' and 'O75' then 'O60-O75 Complications of labour and delivery'
        when left(upper({{ code_column }}), 3) between 'O80' and 'O84' then 'O80-O84 Delivery'
        when left(upper({{ code_column }}), 3) between 'O85' and 'O92' then 'O85-O92 Complications predominantly related to the puerperium'
        when left(upper({{ code_column }}), 3) between 'O94' and 'O99' then 'O94-O99 Other obstetric conditions, not elsewhere classified'
        -- must stay above the A00-Z99 branch: an O code in a chapter XV gap resolves to no
        -- block, and is unclassified rather than non-obstetric
        when left(upper({{ code_column }}), 3) between 'O00' and 'O99' then 'Unclassified'
        when left(upper({{ code_column }}), 3) between 'A00' and 'Z99' then 'Non-obstetric'
        else 'Unclassified'
    end
{% endmacro %}
