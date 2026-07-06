#!/usr/bin/env bash
#
# import-reports-k8s.sh
#
# Import Tamanu report definitions (and optionally a reporting schema) into a central
# server on K8s. Mechanical plumbing only; the runbook owns decisions. This is the
# macOS/Linux counterpart of import-reports-k8s.ps1 and behaves identically.
#
# The active kubectl context is switched before any cluster call so the run targets the
# intended cluster. It defaults to the demo cluster (--context demo); pass --context to
# target a different cluster.
#
# Default mode is PLAN (read-only): resolves the pod, prints the current report state,
# and shows what WOULD be applied. Nothing is written until you pass --apply. There is no
# native dry run on the importReport CLI, so this plan/apply split is the safety net.
#
#   Reports to import: every *.json file in --reports-dir.
#   Schema: optional. Pass --schema-sql to apply a reporting-schema file first (CNPG socket
#   mode: exec into the rw Postgres service over its local socket with peer auth as the
#   superuser, SET ROLE to the app role, apply in one transaction). Omit --schema-sql to
#   skip the schema step and only import reports. --schema-svc may list several services
#   (e.g. "central-db-rw,facility-1-db-rw").
#
#   Schema-only: pass --schema-only (with --schema-sql) to apply the schema and skip report
#   import entirely. --reports-dir and the central pod are not needed in this mode.
#
# EXAMPLES
#   # Schema + reports, review the plan, then re-run with --apply:
#   ./import-reports-k8s.sh --namespace tamanu-syria-demo --reports-dir ./my-reports \
#     --schema-sql ./reporting-schema-v2.54.0-msf.sql \
#     --schema-svc central-db-rw,facility-1-db-rw \
#     --workdir /app/packages/central-server
#
#   # Reports only, schema already applied:
#   ./import-reports-k8s.sh --namespace tamanu-syria-demo --reports-dir ./my-reports \
#     --workdir /app/packages/central-server --apply
#
#   # Schema only, no report import:
#   ./import-reports-k8s.sh --namespace tamanu-syria-demo \
#     --schema-sql ./reporting-schema-v2.54.0-msf.sql \
#     --schema-svc central-db-rw,facility-1-db-rw --schema-only

set -euo pipefail

usage() {
  cat <<'EOF'
import-reports-k8s.sh — import Tamanu reports (and optionally a reporting schema)
into a central server on K8s. Defaults to a read-only PLAN; nothing is written
until you pass --apply. macOS/Linux counterpart of import-reports-k8s.ps1.

Usage:
  import-reports-k8s.sh --namespace NS [options] [--apply]

Options:
  --namespace NS       (required) target K8s namespace
  --reports-dir DIR    folder of *.json reports (required unless --schema-only)
  --schema-sql FILE    reporting-schema .sql to apply first (omit to skip schema)
  --schema-svc LIST    comma-separated *-db-rw services for schema (default: central-db-rw)
  --schema-only        apply schema only, skip report import (requires --schema-sql)
  --pod NAME           override the central pod (default: resolve by --selector)
  --container NAME     container name for multi-container pods
  --selector SEL       label selector to find the central pod
  --workdir DIR        working dir in the pod for `node dist` (default: .)
  --db-svc SVC         service used for the before/after snapshot (default: central-db-rw)
  --db-name NAME       database name (default: app)
  --db-role ROLE       role the schema is applied as via SET ROLE (default: app)
  --db-container NAME  Postgres container in the CNPG pod (default: postgres)
  --context NAME       kubectl context to switch to first (default: demo)
  --apply              actually write (prompts for namespace confirmation)
  -h, --help           show this help

See scripts/import-reports/README.md for details and examples.
EOF
  exit "${1:-0}"
}

# ---- defaults (mirror the PowerShell param block) ---------------------------------
NAMESPACE=""
REPORTS_DIR=""
SCHEMA_SQL=""
POD=""
CONTAINER=""
SELECTOR="app.kubernetes.io/name=central,app.kubernetes.io/component=api-server"
WORKDIR="."
SCHEMA_SVC="central-db-rw"
DB_SVC="central-db-rw"
DB_NAME="app"
DB_ROLE="app"
DB_CONTAINER="postgres"
CONTEXT="demo"
SCHEMA_ONLY=false
APPLY=false

# ---- parse args -------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)     NAMESPACE="$2"; shift 2 ;;
    --reports-dir)   REPORTS_DIR="$2"; shift 2 ;;
    --schema-sql)    SCHEMA_SQL="$2"; shift 2 ;;
    --pod)           POD="$2"; shift 2 ;;
    --container)     CONTAINER="$2"; shift 2 ;;
    --selector)      SELECTOR="$2"; shift 2 ;;
    --workdir)       WORKDIR="$2"; shift 2 ;;
    --schema-svc)    SCHEMA_SVC="$2"; shift 2 ;;
    --db-svc)        DB_SVC="$2"; shift 2 ;;
    --db-name)       DB_NAME="$2"; shift 2 ;;
    --db-role)       DB_ROLE="$2"; shift 2 ;;
    --db-container)  DB_CONTAINER="$2"; shift 2 ;;
    --context)       CONTEXT="$2"; shift 2 ;;
    --schema-only)   SCHEMA_ONLY=true; shift ;;
    --apply)         APPLY=true; shift ;;
    -h|--help)       usage 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; usage 1 ;;
  esac
done

[[ -n "$NAMESPACE" ]] || { echo "ERROR: --namespace is required" >&2; usage 1; }

# -c only when a container was named (single-container pods do not need it)
cexec=()
[[ -n "$CONTAINER" ]] && cexec=(-c "$CONTAINER")

# ---- validate inputs --------------------------------------------------------------
if $SCHEMA_ONLY && [[ -z "$SCHEMA_SQL" ]]; then
  echo "ERROR: --schema-only requires --schema-sql (there is nothing to apply otherwise)" >&2
  exit 1
fi
if [[ -n "$SCHEMA_SQL" && ! -f "$SCHEMA_SQL" ]]; then
  echo "ERROR: schema SQL not found: $SCHEMA_SQL" >&2
  exit 1
fi

reports=()
if ! $SCHEMA_ONLY; then
  [[ -n "$REPORTS_DIR" ]] || { echo "ERROR: --reports-dir is required unless --schema-only is set" >&2; exit 1; }
  [[ -d "$REPORTS_DIR" ]] || { echo "ERROR: reports dir not found: $REPORTS_DIR" >&2; exit 1; }
  # Collect *.json sorted by name (nullglob so a no-match glob yields nothing).
  shopt -s nullglob
  while IFS= read -r f; do reports+=("$f"); done < <(
    for j in "$REPORTS_DIR"/*.json; do echo "$j"; done | LC_ALL=C sort
  )
  shopt -u nullglob
  [[ ${#reports[@]} -gt 0 ]] || { echo "ERROR: no .json files in $REPORTS_DIR" >&2; exit 1; }
fi

# ---- switch cluster context -------------------------------------------------------
# Switch the active kubectl context so every subsequent kubectl call (pod resolution,
# snapshot, schema apply, report import) runs against the intended cluster, not whatever
# context happened to be selected. Defaults to the demo cluster; override with --context.
echo ">> Switching kubectl context to '$CONTEXT' ..."
kubectl config use-context "$CONTEXT"

# ---- resolve the central pod (only needed for report import) ----------------------
if ! $SCHEMA_ONLY && [[ -z "$POD" ]]; then
  POD="$(kubectl get pods -n "$NAMESPACE" -l "$SELECTOR" --field-selector=status.phase=Running \
         -o "jsonpath={.items[0].metadata.name}")"
  if [[ -z "${POD// }" ]]; then
    echo "ERROR: could not resolve a Running central pod (pass --pod)" >&2
    exit 1
  fi
fi

# ---- helpers ----------------------------------------------------------------------
invoke_node_dist() {
  # $1 = args passed to `node dist`
  local dist_args="$1"
  # "${cexec[@]+...}" guards against an empty array under `set -u` on bash 3.2 (stock macOS).
  kubectl exec -i -n "$NAMESPACE" "$POD" "${cexec[@]+"${cexec[@]}"}" -- sh -lc "cd '$WORKDIR' && node dist $dist_args"
}

# Socket-mode psql into a CNPG rw service (peer auth as superuser, no password).
# Usage: invoke_psql_svc <svc> [--stdin-file <path>] -- <extra psql args...>
invoke_psql_svc() {
  local svc="$1"; shift
  local stdin_file=""
  if [[ "${1:-}" == "--stdin-file" ]]; then
    stdin_file="$2"; shift 2
  fi
  [[ "${1:-}" == "--" ]] && shift
  local base=(exec -i -n "$NAMESPACE" "svc/$svc" -c "$DB_CONTAINER" --
              psql -d "$DB_NAME" -v ON_ERROR_STOP=1 "$@")
  if [[ -n "$stdin_file" ]]; then
    kubectl "${base[@]}" < "$stdin_file"
  else
    kubectl "${base[@]}"
  fi
}

read -r -d '' SNAPSHOT_SQL <<'SQL' || true
SELECT rd.name, rd.db_schema,
  max(rdv.version_number) AS latest,
  max(rdv.version_number) FILTER (WHERE rdv.status='published') AS latest_published
FROM report_definitions rd
LEFT JOIN report_definition_versions rdv
  ON rdv.report_definition_id = rd.id AND rdv.deleted_at IS NULL
WHERE rd.deleted_at IS NULL
GROUP BY rd.id, rd.name, rd.db_schema
ORDER BY rd.name;
SQL

show_snapshot() {
  invoke_psql_svc "$DB_SVC" -- -P pager=off -c "$SNAPSHOT_SQL" \
    || echo "  (snapshot unavailable)"
}

# ---- PLAN -------------------------------------------------------------------------
# Split SCHEMA_SVC on commas, trim, drop empties.
svcs=()
IFS=',' read -ra _raw_svcs <<< "$SCHEMA_SVC"
for s in "${_raw_svcs[@]}"; do
  s="$(echo "$s" | tr -d '[:space:]')"
  [[ -n "$s" ]] && svcs+=("$s")
done
svcs_joined="$(IFS=', '; echo "${svcs[*]}")"

echo "=================================================================="
echo " PLAN"
echo "   kube context   : $CONTEXT"
echo "   namespace      : $NAMESPACE"
if $SCHEMA_ONLY; then
  echo "   central pod    : (skipped - schema-only run)"
else
  pod_line="   central pod    : $POD"
  [[ -n "$CONTAINER" ]] && pod_line="$pod_line  (container: $CONTAINER)"
  echo "$pod_line"
fi
if [[ -n "$SCHEMA_SQL" ]]; then
  echo "   schema SQL     : $SCHEMA_SQL"
  echo "   schema -> svc  : $svcs_joined  (db=$DB_NAME role=$DB_ROLE container=$DB_CONTAINER)"
else
  echo "   schema SQL     : (skipped - none provided)"
fi
echo "   snapshot svc   : $DB_SVC"
if $SCHEMA_ONLY; then
  echo "   reports dir    : (skipped - schema-only run)"
else
  echo "   reports dir    : $REPORTS_DIR  (${#reports[@]} *.json files)"
fi
echo "------------------------------------------------------------------"
if $SCHEMA_ONLY; then
  echo " Reports: none (schema-only run)"
else
  echo " Reports that WOULD be imported:"
  for r in "${reports[@]}"; do echo "   - $(basename "$r")"; done
fi
echo "------------------------------------------------------------------"
echo " Current report state (before):"
show_snapshot
echo "=================================================================="

if ! $APPLY; then
  echo "PLAN ONLY. Re-run with --apply to write. Nothing was changed."
  exit 0
fi

# ---- APPLY guard ------------------------------------------------------------------
echo ""
if $SCHEMA_ONLY; then
  echo "About to APPLY schema to [$svcs_joined] into '$NAMESPACE' (schema-only - no reports imported)."
elif [[ -n "$SCHEMA_SQL" ]]; then
  echo "About to APPLY schema to [$svcs_joined] and import ${#reports[@]} reports into '$NAMESPACE'."
else
  echo "About to import ${#reports[@]} reports into '$NAMESPACE' (no schema step)."
fi
echo "This writes to the live database(s) and has NO dry run."
read -r -p "Type the namespace to confirm: " confirm
[[ "$confirm" == "$NAMESPACE" ]] || { echo "Confirmation did not match. Aborting." >&2; exit 1; }

# 1) Reporting schema FIRST (if provided), on each target service, as the app role
# NOTE: the schema is streamed over the same kubectl stdin pipe that can short-write
# on the network, but unlike reports it is NOT base64-verified. --single-transaction
# + ON_ERROR_STOP=1 is the safety net: a truncated file almost certainly fails to parse
# and the whole transaction rolls back, so a short write aborts rather than partially
# applying. It does not verify the transfer itself.
if [[ -n "$SCHEMA_SQL" ]]; then
  for svc in "${svcs[@]}"; do
    echo ">> Applying reporting schema to svc/$svc as role $DB_ROLE ..."
    invoke_psql_svc "$svc" --stdin-file "$SCHEMA_SQL" -- \
      --single-transaction -c "SET ROLE $DB_ROLE" -f -
  done
  echo ">> Schema applied."
else
  echo ">> No schema file provided; skipping schema step."
fi

# 2) Import each report (skipped on a schema-only run)
if $SCHEMA_ONLY; then
  echo ">> Schema-only run; skipping report import."
else
  max_stage_attempts=3
  for r in "${reports[@]}"; do
    bn="$(basename "$r")"
    # $bn is interpolated into a remote `sh -lc "... '/tmp/$bn'"`, so reject anything
    # outside a safe charset to keep the single-quoting intact (compiled report names
    # are controlled, but a stray quote or space would break the command).
    case "$bn" in
      *[!A-Za-z0-9._-]*) echo "ERROR: unsafe report filename: $bn (allowed: A-Z a-z 0-9 . _ -)" >&2; exit 1 ;;
    esac
    echo ">> Importing $bn ..."
    # Stage via base64 (pure ASCII; immune to encoding/newline/stdin-flush truncation
    # that silently produced empty files with a raw `cat | cat >` pipe).
    # The streamed stdin pipe can occasionally short-write over the network, so retry
    # the stage+verify a few times; a transient truncation self-heals instead of
    # aborting the whole run.
    expected="$(wc -c < "$r" | tr -d '[:space:]')"
    staged=false
    for ((attempt = 1; attempt <= max_stage_attempts; attempt++)); do
      if ! base64 < "$r" | kubectl exec -i -n "$NAMESPACE" "$POD" "${cexec[@]+"${cexec[@]}"}" -- \
             sh -lc "base64 -d > '/tmp/$bn'"; then
        echo "   stage attempt $attempt/$max_stage_attempts failed (kubectl error)"
        continue
      fi
      # Verify the staged file is intact before importing (catches a truncated transfer).
      if ! size="$(kubectl exec -i -n "$NAMESPACE" "$POD" "${cexec[@]+"${cexec[@]}"}" -- \
                   sh -lc "wc -c < '/tmp/$bn'")"; then
        echo "   verify attempt $attempt/$max_stage_attempts failed (kubectl error)"
        continue
      fi
      size="$(echo "$size" | tr -d '[:space:]')"
      if [[ "$size" == "$expected" ]]; then staged=true; break; fi
      echo "   staged $bn is $size bytes, expected $expected (attempt $attempt/$max_stage_attempts); retrying"
    done
    if ! $staged; then
      echo "ERROR: failed to stage $bn intact after $max_stage_attempts attempts (expected $expected bytes). Aborting." >&2
      exit 1
    fi
    invoke_node_dist "importReport -f '/tmp/$bn' -v"
    # Remove the staged temp file so nothing is left behind in the pod (best-effort).
    kubectl exec -i -n "$NAMESPACE" "$POD" "${cexec[@]+"${cexec[@]}"}" -- \
      sh -lc "rm -f '/tmp/$bn'" || echo "   (could not remove /tmp/$bn)"
  done
fi

# 3) After snapshot
echo "------------------------------------------------------------------"
echo " Current report state (after):"
show_snapshot
echo "=================================================================="
echo "DONE. Verify per the runbook (active versions + spot-check a report runs)."
