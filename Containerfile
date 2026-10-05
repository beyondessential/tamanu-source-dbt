# Builds a deployment's reporting schema against a restored replica. Built from
# a deployment repo's root, so the image carries that deployment's models and
# the package revision its packages.yml pins. Run by pgro as a one-shot Job.

FROM python:3.12-slim

# dbt deps fetches the package with git.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends git \
	&& rm -rf /var/lib/apt/lists/*

RUN useradd --create-home --uid 10001 build

WORKDIR /dbt

COPY --chown=build:build . .

ENV PATH="/dbt/.venv/bin:$PATH"

# The profile renders before deps runs and its env_var calls have no defaults; deps never connects.
RUN pip install --no-cache-dir uv \
	&& uv sync --frozen --no-dev \
	&& TAMANU_DL_DB_URL=localhost \
	   TAMANU_DL_DB_USER=build \
	   TAMANU_DL_DB_PASSWORD=build \
	   TAMANU_DL_DB_DATABASE=build \
	   dbt deps --profiles-dir config \
	&& chown -R build:build /dbt

USER build

ENV TAMANU_DBT_TARGET=replica

ENTRYPOINT ["python", "dbt_packages/tamanu_source_dbt/scripts/build_reporting_schema.py"]
