#!/bin/bash
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

cd "$CLAUDE_PROJECT_DIR"

VENV_DIR="$CLAUDE_PROJECT_DIR/.venv"

# Create venv with Python 3.12 if it doesn't exist
if [ ! -d "$VENV_DIR" ]; then
  uv venv --python python3.12 "$VENV_DIR"
fi

# Install Python dependencies into the venv
# --group dev installs pytest (defined as a dependency-group, not an extras)
uv pip install -e . --group dev --python "$VENV_DIR/bin/python"

# Activate venv for subsequent commands
export PATH="$VENV_DIR/bin:$PATH"

# Persist venv activation for the session
echo "export PATH=\"$VENV_DIR/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"

# Set placeholder DB env vars so sqlfluff can template SQL without a real DB connection.
# Users should override these with real credentials in .env for dbt test/run.
{
  echo "export DBT_PROFILES_DIR=\"$CLAUDE_PROJECT_DIR/config\""
  echo "export TAMANU_DEMO_DB_URL=localhost"
  echo "export TAMANU_DEMO_DB_PORT=5432"
  echo "export TAMANU_DEMO_DB_USER=user"
  echo "export TAMANU_DEMO_DB_PASSWORD=password"
  echo "export TAMANU_DEMO_DB_DATABASE=tamanu"
  echo "export TAMANU_RL_DB_URL=localhost"
  echo "export TAMANU_RL_DB_PORT=5432"
  echo "export TAMANU_RL_DB_USER=user"
  echo "export TAMANU_RL_DB_PASSWORD=password"
  echo "export TAMANU_RL_DB_DATABASE=tamanu"
} >> "$CLAUDE_ENV_FILE"

export DBT_PROFILES_DIR="$CLAUDE_PROJECT_DIR/config"
export TAMANU_DEMO_DB_URL=localhost
export TAMANU_DEMO_DB_PORT=5432
export TAMANU_DEMO_DB_USER=user
export TAMANU_DEMO_DB_PASSWORD=password
export TAMANU_DEMO_DB_DATABASE=tamanu
export TAMANU_RL_DB_URL=localhost
export TAMANU_RL_DB_PORT=5432
export TAMANU_RL_DB_USER=user
export TAMANU_RL_DB_PASSWORD=password
export TAMANU_RL_DB_DATABASE=tamanu

# Install dbt packages (requires network access to hub.getdbt.com)
dbt deps --profiles-dir config || echo "Warning: dbt deps failed — sqlfluff linting will not work until dbt deps succeeds"
