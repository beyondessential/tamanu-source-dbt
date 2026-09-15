-- Canonical metric definitions registry. The definitions are authored in
-- documentations/metrics/*.yml and compiled inline by get_metric_definitions(), so this ships
-- as a view in the production bundle rather than a seed table. dbt cannot read a YAML file, so
-- the macro is the bridge: regenerate and commit it with
-- python scripts/generate_metric_definitions_macro.py after editing the registry.
-- CI fails on drift between the two.
--
-- Tagged 'internal': downstream deployments consume it via ref('metric_definitions')
-- within dbt, but it is not materialised into the deployable reporting schema.
{{ config(tags=['internal']) }}
{{ get_metric_definitions() }}
