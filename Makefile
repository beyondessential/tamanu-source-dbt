# The sensitive models are opt-in for a deployment (has_sensitive_facility, default false), but
# this repo always tests them. The template passes DBT_TEST_EXCLUDE to `dbt test` and lets a repo
# set it before the include; tamanu-source-dbt excludes nothing, so it carries the var instead.
DBT_TEST_EXCLUDE := --vars '{has_sensitive_facility: true}'

include .maui/templates/dbt.mk

# The helper-script unit tests need no database or credentials, so they always run.
check::
	@uv run pytest scripts/tests -q

check::
	@if [ -n "$(ENV_FILE)" ]; then \
		uv run $(ENV_FILE) python scripts/validate_report_configs.py; \
		uv run $(ENV_FILE) python scripts/check_translations.py; \
	else \
		echo "check: skipping validate_report_configs.py / check_translations.py -- no .env configured"; \
	fi
