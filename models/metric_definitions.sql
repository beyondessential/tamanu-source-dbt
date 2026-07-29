-- Canonical metric definitions registry. The data lives in metric_definitions.csv
-- and is compiled inline by get_metric_definitions() so this ships as a view in the
-- production bundle rather than a seed table. Regenerate the macro with
-- python scripts/generate_metric_definitions_macro.py after editing the CSV.
--
-- Tagged 'internal': downstream deployments consume it via ref('metric_definitions')
-- within dbt, but it is not materialised into the deployable reporting schema.
{{ config(tags=['internal']) }}
{{ get_metric_definitions() }}
