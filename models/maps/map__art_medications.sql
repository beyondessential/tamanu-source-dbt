-- The medications that are antiretroviral therapy (ART) -> their reference data code.
--
-- derived__episode_art reads ART supplied from the drug exposures whose medication is listed
-- here (see specs/dbt-model/derived__episode_art.md, BL-001).
--
-- Empty by default: the medications that make up ART are deployment reference data, not part of
-- a standard Tamanu catalogue. A deployment that supplies ART in Tamanu disables this model and
-- defines its own of the same name, carrying the unique and not_null tests declared here. Empty
-- here means no drug exposure is ART supply, so no deployment's output changes until it opts in.

select
    null::text as medication_code,
    null::text as medication_name
where false
