-- Lab test types that carry their result in the type itself -> the result they encode.
--
-- A point-of-care rapid test is recorded by choosing a result-bearing test type rather than by
-- entering a result, so lab_tests.result is often blank while the reading sits in the type.
-- clinical__measurement joins this map so those readings are not discarded (BL-009).
--
-- Empty by default: the test types that behave this way are deployment reference data, not part
-- of a standard Tamanu catalogue. A deployment that records point-of-care tests disables this
-- model and defines its own of the same name, unique on lab_test_type_id so the join in
-- clinical__measurement stays one-to-one. Empty here means the join is a no-op, so no
-- deployment's output changes until it opts in.

select
    null::text    as lab_test_type_id,
    null::text    as encoded_result,
    null::boolean as is_positive
where false
