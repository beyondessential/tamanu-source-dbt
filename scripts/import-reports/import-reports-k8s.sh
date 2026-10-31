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
# Every run starts with a read-only PLAN: resolves the pod, prints the current report
# state, and shows what WOULD be applied. It then asks you to type the namespace to apply;
# press Enter instead to stop with nothing changed. --plan-only prints the plan and exits
# without asking. There is no native dry run on the importReport CLI, so this
# plan-then-confirm step is the safety net.
#
#   Bundle: --bundle points at a compiled bundle folder (e.g. compiled/v2.66.0). Its *.json
#   files are imported and its single reporting-schema-*.sql is applied first.
#   --reports-dir and --schema-sql override either half; --no-schema skips the schema step.
#
#   Reports to import: every *.json file in --reports-dir (or --bundle).
#   Schema: optional. The reporting-schema file is applied first (CNPG socket mode: exec
#   into the rw Postgres service over its local socket with peer auth as the superuser,
#   SET ROLE to the app role, apply in one transaction). The schema goes to every *-db-rw
#   service in the namespace (central plus each facility), discovered automatically; pass
#   --schema-svc (e.g. "central-db-rw,facility-1-db-rw") to target specific services instead.
#
#   Schema-only: pass --schema-sql without --reports-dir or --bundle to apply the schema and
#   skip report import entirely. The central pod is not needed in this mode.
#
# EXAMPLES
#   # Schema + reports from a compiled bundle; review the plan, then type the namespace:
#   ./import-reports-k8s.sh tamanu-syria-demo --bundle ../../compiled/v2.66.0
#
#   # Reports only, schema already applied:
#   ./import-reports-k8s.sh tamanu-syria-demo --bundle ../../compiled/v2.66.0 --no-schema
#
#   # Schema only, no report import:
#   ./import-reports-k8s.sh tamanu-syria-demo --schema-sql ./reporting-schema-v2.54.0-msf.sql
#
#   # Separate reports folder and schema file, plan only:
#   ./import-reports-k8s.sh tamanu-syria-demo --reports-dir ./my-reports \
#     --schema-sql ./reporting-schema-v2.54.0-msf.sql --plan-only

set -euo pipefail

usage() {
  cat <<'EOF'
import-reports-k8s.sh — import Tamanu reports (and optionally a reporting schema)
into a central server on K8s. Prints a read-only PLAN, then asks you to type the
namespace before writing anything. macOS/Linux counterpart of import-reports-k8s.ps1.

Usage:
  import-reports-k8s.sh NS [options]
  import-reports-k8s.sh --namespace NS [options]

Options:
  --namespace NS       (required; or pass NS as the first argument) target K8s namespace
  --bundle DIR         compiled bundle folder: imports its *.json and applies its reporting-schema-*.sql
  --reports-dir DIR    folder of *.json reports (overrides the bundle's)
  --schema-sql FILE    reporting-schema .sql to apply first (overrides the bundle's);
                       without --reports-dir/--bundle this is a schema-only run
  --no-schema          skip the schema step (e.g. --bundle with the schema already applied)
  --schema-svc LIST    comma-separated *-db-rw services for schema (default: all *-db-rw in the namespace)
  --pod NAME           override the central pod (default: resolve by --selector)
  --container NAME     container name for multi-container pods
  --selector SEL       label selector to find the central pod
  --workdir DIR        working dir in the pod for the central-server CLI (default: /app/packages/central-server)
  --db-svc SVC         service used for the before/after snapshot (default: central-db-rw)
  --db-name NAME       database name (default: app)
  --db-role ROLE       role the schema is applied as via SET ROLE (default: app)
  --db-container NAME  Postgres container in the CNPG pod (default: postgres)
  --context NAME       kubectl context to switch to first (default: demo)
  --plan-only          print the plan and exit without the apply prompt
  -h, --help           show this help

See scripts/import-reports/README.md for details and examples.
EOF
  exit "${1:-0}"
}

# ---- defaults (mirror the PowerShell param block) ---------------------------------
NAMESPACE=""
BUNDLE=""
REPORTS_DIR=""
SCHEMA_SQL=""
POD=""
CONTAINER=""
SELECTOR="app.kubernetes.io/name=central,app.kubernetes.io/component=api-server"
WORKDIR="/app/packages/central-server"
SCHEMA_SVC=""
DB_SVC="central-db-rw"
DB_NAME="app"
DB_ROLE="app"
DB_CONTAINER="postgres"
CONTEXT="demo"
NO_SCHEMA=false
PLAN_ONLY=false

# ---- parse args -------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)     NAMESPACE="$2"; shift 2 ;;
    --bundle)        BUNDLE="$2"; shift 2 ;;
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
    --no-schema)     NO_SCHEMA=true; shift ;;
    --plan-only)     PLAN_ONLY=true; shift ;;
    -h|--help)       usage 0 ;;
    -*) echo "ERROR: unknown argument: $1" >&2; usage 1 ;;
    *)
      # A bare word is the namespace (once only).
      [[ -z "$NAMESPACE" ]] || { echo "ERROR: unexpected argument: $1" >&2; usage 1; }
      NAMESPACE="$1"; shift ;;
  esac
done

[[ -n "$NAMESPACE" ]] || { echo "ERROR: --namespace is required" >&2; usage 1; }

# -c only when a container was named (single-container pods do not need it)
cexec=()
[[ -n "$CONTAINER" ]] && cexec=(-c "$CONTAINER")

# ---- validate inputs --------------------------------------------------------------
if $NO_SCHEMA && [[ -n "$SCHEMA_SQL" ]]; then
  echo "ERROR: --no-schema and --schema-sql contradict each other; pass one or neither" >&2
  exit 1
fi
# A bundle folder supplies whichever of reports / schema was not given explicitly.
if [[ -n "$BUNDLE" ]]; then
  [[ -d "$BUNDLE" ]] || { echo "ERROR: bundle dir not found: $BUNDLE" >&2; exit 1; }
  [[ -n "$REPORTS_DIR" ]] || REPORTS_DIR="$BUNDLE"
  if [[ -z "$SCHEMA_SQL" ]] && ! $NO_SCHEMA; then
    shopt -s nullglob
    found=("$BUNDLE"/reporting-schema-*.sql)
    shopt -u nullglob
    if [[ ${#found[@]} -eq 0 ]]; then
      echo "ERROR: no reporting-schema-*.sql in $BUNDLE (pass --schema-sql, or --no-schema to skip it)" >&2
      exit 1
    fi
    if [[ ${#found[@]} -gt 1 ]]; then
      echo "ERROR: several reporting-schema-*.sql in $BUNDLE (${found[*]}); pass --schema-sql" >&2
      exit 1
    fi
    SCHEMA_SQL="${found[0]}"
  fi
fi
if [[ -z "$REPORTS_DIR" && -z "$SCHEMA_SQL" ]]; then
  echo "ERROR: nothing to do - pass --bundle, --reports-dir or --schema-sql" >&2
  exit 1
fi
# A schema file with no reports folder is a schema-only run.
SCHEMA_ONLY=false
[[ -n "$REPORTS_DIR" ]] || SCHEMA_ONLY=true
if [[ -n "$SCHEMA_SQL" && ! -f "$SCHEMA_SQL" ]]; then
  echo "ERROR: schema SQL not found: $SCHEMA_SQL" >&2
  exit 1
fi

reports=()
if ! $SCHEMA_ONLY; then
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
# So every kubectl call runs against the intended cluster, not whatever was selected.
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
invoke_central_cli() {
  # $1 = args passed to the central-server CLI
  local cli_args="$1"
  # Pick the entry point in the pod: a dist/ directory means node resolves it as before
  # (index.js or package.json main); no dist/ means the image is build-less (2.60+) so run
  # from TS source via tsx. Error out if neither is present (usually a wrong --workdir).
  # "${cexec[@]+...}" guards against an empty array under `set -u` on bash 3.2 (stock macOS).
  kubectl exec -i -n "$NAMESPACE" "$POD" "${cexec[@]+"${cexec[@]}"}" -- \
    sh -lc "cd '$WORKDIR' && if [ -d dist ]; then node dist $cli_args; elif [ -d app ]; then node --import tsx app $cli_args; else echo \"ERROR: no central-server entry point under \$(pwd) - check --workdir\" >&2; exit 1; fi"
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
SELECT rd.id, rd.name, rd.db_schema,
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

# ---- resolve schema target services ----------------------------------------------
# Without --schema-svc, target every CNPG rw service in the namespace (central-db-rw,
# facility-N-db-rw, ...) so new facilities are picked up without editing the command.
svcs=()
svc_source="from --schema-svc"
if [[ -n "$SCHEMA_SQL" ]]; then
  if [[ -n "$SCHEMA_SVC" ]]; then
    # Split SCHEMA_SVC on commas, trim, drop empties.
    IFS=',' read -ra _raw_svcs <<< "$SCHEMA_SVC"
    for s in "${_raw_svcs[@]}"; do
      s="$(echo "$s" | tr -d '[:space:]')"
      [[ -n "$s" ]] && svcs+=("$s")
    done
  else
    svc_source="auto-discovered"
    all_svcs="$(kubectl get svc -n "$NAMESPACE" -o "jsonpath={.items[*].metadata.name}")"
    while IFS= read -r s; do
      [[ -n "$s" ]] && svcs+=("$s")
    done < <(tr ' ' '\n' <<< "$all_svcs" | grep -E -- '-db-rw$' | LC_ALL=C sort || true)
    if [[ ${#svcs[@]} -eq 0 ]]; then
      echo "ERROR: no *-db-rw services found in namespace $NAMESPACE (pass --schema-svc)" >&2
      exit 1
    fi
  fi
fi
# Join with ", " (IFS only uses its first character, so it cannot do this itself).
svcs_joined=""
for s in "${svcs[@]+"${svcs[@]}"}"; do
  svcs_joined="${svcs_joined:+$svcs_joined, }$s"
done

# ---- PLAN -------------------------------------------------------------------------

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
  echo "   schema -> svc  : $svcs_joined  ($svc_source; db=$DB_NAME role=$DB_ROLE container=$DB_CONTAINER)"
else
  if $NO_SCHEMA; then
    echo "   schema SQL     : (skipped - --no-schema)"
  else
    echo "   schema SQL     : (skipped - none provided)"
  fi
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

if $PLAN_ONLY; then
  echo "PLAN ONLY. Re-run without --plan-only to apply. Nothing was changed."
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
# EOF (no terminal) counts as pressing Enter: stop without writing.
read -r -p "Type the namespace to apply (or press Enter to stop): " confirm || confirm=""
if [[ -z "${confirm// }" ]]; then
  echo "Stopped. Nothing was changed."
  exit 0
fi
[[ "$confirm" == "$NAMESPACE" ]] || { echo "Confirmation did not match. Aborting." >&2; exit 1; }

# 1) Reporting schema FIRST (if provided), on each target service, as the app role.
# Unlike reports the schema is not byte-count-verified; --single-transaction +
# ON_ERROR_STOP=1 is the safety net, so a short write fails to parse and rolls back.
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
    # $bn is interpolated into a remote `sh -lc "... '/tmp/$bn'"`; reject anything outside
    # a safe charset so a stray quote or space can't break the quoting.
    case "$bn" in
      *[!A-Za-z0-9._-]*) echo "ERROR: unsafe report filename: $bn (allowed: A-Z a-z 0-9 . _ -)" >&2; exit 1 ;;
    esac
    echo ">> Importing $bn ..."
    # Stage with `kubectl cp` (binary-safe tar stream, reliable) rather than piping base64
    # over `kubectl exec -i` stdin, which can short-write over the network. Verify the byte
    # count and retry regardless, as cheap insurance.
    expected="$(wc -c < "$r" | tr -d '[:space:]')"
    staged=false
    for ((attempt = 1; attempt <= max_stage_attempts; attempt++)); do
      if ! kubectl cp -n "$NAMESPACE" "${cexec[@]+"${cexec[@]}"}" "$r" "$POD:/tmp/$bn"; then
        echo "   stage attempt $attempt/$max_stage_attempts failed (kubectl cp error)"
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
      # Drop the partial/failed temp file before aborting so nothing is left in the pod.
      kubectl exec -i -n "$NAMESPACE" "$POD" "${cexec[@]+"${cexec[@]}"}" -- \
        sh -lc "rm -f '/tmp/$bn'" || true
      echo "ERROR: failed to stage $bn intact after $max_stage_attempts attempts (expected $expected bytes). Aborting." >&2
      exit 1
    fi
    # Capture the exit so `set -e` doesn't abort before cleanup; always remove the staged
    # temp file, then fail loudly naming the report.
    import_rc=0
    invoke_central_cli "importReport -f '/tmp/$bn' -v" || import_rc=$?
    kubectl exec -i -n "$NAMESPACE" "$POD" "${cexec[@]+"${cexec[@]}"}" -- \
      sh -lc "rm -f '/tmp/$bn'" || echo "   (could not remove /tmp/$bn)"
    if [[ $import_rc -ne 0 ]]; then
      echo "ERROR: importReport failed for $bn (exit $import_rc). Aborting." >&2
      exit 1
    fi
  done
fi

# 3) After snapshot
echo "------------------------------------------------------------------"
echo " Current report state (after):"
show_snapshot
echo "=================================================================="
echo "DONE. Verify per the runbook (active versions + spot-check a report runs)."
