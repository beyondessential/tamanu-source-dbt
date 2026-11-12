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
