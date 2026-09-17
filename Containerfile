# Builds a deployment's reporting schema against a restored replica.
#
# Built from a deployment repo's root, so the image carries that deployment's
# models, its config and the package version its packages.yml pins. Everything
# the build needs is fetched here: at run time the container reaches the
# replica it is given and the callback it posts to, and nothing else.
#
# Run by pgro as a one-shot Job. It takes the database, version, deployment and
# callback from the environment, and its whole output is one POST of SQL.

FROM python:3.12-slim

# git is what `dbt deps` fetches the package with, since packages.yml names it
# by repository and revision.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends git \
	&& rm -rf /var/lib/apt/lists/*

# A build reads the replica and writes nothing to it, and carries a callback
# token in its environment, so it has no reason to run as root.
RUN useradd --create-home --uid 10001 build

WORKDIR /dbt

COPY --chown=build:build . .

# The deployment's own uv.lock, so an image built today and one built next
# month carry the same dbt. A deployment repo is a dbt project rather than a
# Python package, so its dependencies are synced and it is not itself built.
ENV PATH="/dbt/.venv/bin:$PATH"

# `dbt deps` vendors the package that packages.yml pins, which is where the
# build's own scripts and the standard models come from.
#
# The profile is rendered before deps runs and its env_var calls carry no
# defaults, so the placeholders below stand in for a connection deps never
# opens.
RUN pip install --no-cache-dir uv \
	&& uv sync --frozen --no-dev \
	&& TAMANU_DL_DB_URL=localhost \
	   TAMANU_DL_DB_USER=build \
	   TAMANU_DL_DB_PASSWORD=build \
	   TAMANU_DL_DB_DATABASE=build \
	   dbt deps --profiles-dir config \
	&& chown -R build:build /dbt

USER build

# The replica pgro hands the build, named by the profile's `replica` target.
ENV TAMANU_DBT_TARGET=replica

ENTRYPOINT ["python", "dbt_packages/tamanu_source_dbt/scripts/build_reporting_schema.py"]
