-- Lab test types that encode their own result -> the result they encode.
--
-- Point-of-care rapid tests are recorded by choosing a result-bearing test type rather than by
-- entering a result: the reactive and non-reactive readings are two distinct lab_test_types, and
-- lab_tests.result is often left blank because the type already carries the answer. Without this
-- map, clinical__measurement's non-blank-result rule (BL-007) discards those readings entirely.
--
-- Universal mapping: these test types ship with Tamanu, so it lives in tamanu-source-dbt.
-- View-over-values rather than a seed so it ships in the compiled production bundle. A deployment
-- whose catalogue carries additional result-bearing types overrides this model by name.
--
-- is_positive is the reading itself, not an interpretation of it: a reactive screening result is
-- recorded here as reactive, and what that means for a given indicator is the consumer's business.

select
    lab_test_type_id,
    encoded_result,
    is_positive
from (
    values
        -- SD Duo combined HIV / syphilis point-of-care test
        ('labTestType-SDDuoHIVReactive',            'Reactive',     true),
        ('labTestType-SDDuoHIVNonReactive',         'Non-reactive', false),
        ('labTestType-SDDuoSyphilisReactive',       'Reactive',     true),
        ('labTestType-SDDuoSyphilisNonReactive',    'Non-reactive', false),
        -- HIV rapid diagnostic tests
        ('labTestType-HIVRDTInstiPositive',              'Positive', true),
        ('labTestType-HIVRDTInstiNegative',              'Negative', false),
        ('labTestType-HIVRDTUniGoldPreliminaryPositive', 'Positive', true),
        ('labTestType-HIVRDTUniGoldNegative',            'Negative', false),
        -- Determine hepatitis B surface antigen
        ('labTestType-DetermineHepatitisBSurfaceAntigenPositive', 'Positive', true),
        ('labTestType-DetermineHepatitisBSurfaceAntigenNegative', 'Negative', false)
) as t (lab_test_type_id, encoded_result, is_positive)
