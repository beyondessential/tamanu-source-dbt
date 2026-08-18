{% macro diagnosis__icd10_obstetric_block(code_column) %}
{#
    WHO ICD-10 Chapter XV block for a diagnosis code, labelled "<code range> <block title>"
    (e.g. 'O60-O75 Complications of labour and delivery'). Chapter XV is Pregnancy,
    childbirth and the puerperium, O00-O99.

    Source: WHO ICD-10 (2019 edition) Chapter XV block ranges,
    https://icd.who.int/browse10/2019/en

    WHO ICD-10, *not* ICD-10-CM. The US clinical modification draws three of these blocks
    differently -- O60-O77, O80-O82 and O94-O9A where WHO has O60-O75, O80-O84 and O94-O99 --
    so under WHO a code in O76-O79 or O93 sits in an unassigned gap rather than inside a
    block. Take the ranges below from a WHO or WHO-derived tabular list, not from a CM one.

    For an obstetric service diagnosis__icd10_chapter answers nothing: essentially every
    presentation is chapter XV, so a chart of it is a single row. This is the level below it,
    and the level at which obstetric casemix becomes readable -- hypertensive disorders
    against complications of labour against puerperal complications.

    Deliberately not named diagnosis__icd10_block, which the diagnosis__icd10_chapter
    docstring anticipates for the general case. This covers one chapter's blocks; a general
    block macro spans roughly 130 blocks across every chapter and is a separate piece of work.
    Named diagnosis__<grouping> on the same convention, so the value carries which grouping
    produced it -- groupings are not comparable with each other.

    A code outside O00-O99 returns 'Non-obstetric' rather than 'Unclassified'. A maternity
    service does see non-obstetric presentations, and folding them in with malformed codes
    would hide a real and clinically interesting group behind a data-quality label.

    Matching is on the first three characters of the code, upper-cased -- see
    diagnosis__icd10_chapter for why a plain text `between` is enough and an integer cast
    would be worse.

    Parameters:
    - code_column: SQL expression yielding an ICD-10 code (Tamanu reference_data.code).

    Returns: CASE expression producing the block label; 'Non-obstetric' for a code outside
    O00-O99; 'Unclassified' when the code is null, malformed, or falls in one of chapter XV's
    unassigned gaps (O49-O59, O76-O79, O93).
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
