# import-reports

Import Tamanu report definitions (and optionally a reporting schema) into a central
server running on Kubernetes. This is **mechanical plumbing only** — the deployment
runbook owns the decisions about *what* and *when*.

> **Cluster.** These scripts switch the active `kubectl` context before doing anything,
> and **default to the demo cluster** (`--context demo` / `-Context demo`). They are
> intended for the demo cluster; to target another cluster, pass `--context` / `-Context`
> explicitly. The chosen context is printed at the top of the PLAN so you can confirm it
> before applying.

Two equivalent scripts are provided so the same workflow runs on any machine:

| Platform      | Script                | Run with          |
| ------------- | --------------------- | ----------------- |
| Windows       | `import-reports-k8s.ps1`  | PowerShell        |
| macOS / Linux | `import-reports-k8s.sh`   | Bash              |

Both take the same options and behave identically.

## Prerequisites

- `kubectl` on `PATH`, with your context pointed at the target cluster.
- Access to the central-server pod (report import) and the CNPG `*-db-rw`
  services (schema apply + snapshot).
- The reporting-schema `.sql` file and/or the compiled report `.json` files you
  want to import. Compiled reports are produced by the build in `compiled/reports/`.

## Safety model: plan first, then apply

The `importReport` CLI has **no dry run**, so these scripts default to a read-only
**PLAN**: they resolve the pod, list what *would* be imported, and print the current
report state. Nothing is written until you re-run with `-Apply` / `--apply`, which
also prompts you to type the namespace back to confirm.

## Usage

### Windows (PowerShell)

```powershell
# Schema + reports — review the plan, then re-run with -Apply
.\import-reports-k8s.ps1 -Namespace tamanu-syria-demo -ReportsDir .\my-reports `
  -SchemaSql .\reporting-schema-v2.54.0-msf.sql `
  -SchemaSvc central-db-rw,facility-1-db-rw `
  -Workdir /app/packages/central-server

# Reports only (schema already applied)
.\import-reports-k8s.ps1 -Namespace tamanu-syria-demo -ReportsDir .\my-reports `
  -Workdir /app/packages/central-server -Apply

# Schema only, no report import
.\import-reports-k8s.ps1 -Namespace tamanu-syria-demo `
  -SchemaSql .\reporting-schema-v2.54.0-msf.sql `
  -SchemaSvc central-db-rw,facility-1-db-rw -SchemaOnly
```

### macOS / Linux (Bash)

```bash
chmod +x import-reports-k8s.sh   # first time only

# Schema + reports — review the plan, then re-run with --apply
./import-reports-k8s.sh --namespace tamanu-syria-demo --reports-dir ./my-reports \
  --schema-sql ./reporting-schema-v2.54.0-msf.sql \
  --schema-svc central-db-rw,facility-1-db-rw \
  --workdir /app/packages/central-server

# Reports only (schema already applied)
./import-reports-k8s.sh --namespace tamanu-syria-demo --reports-dir ./my-reports \
  --workdir /app/packages/central-server --apply

# Schema only, no report import
./import-reports-k8s.sh --namespace tamanu-syria-demo \
  --schema-sql ./reporting-schema-v2.54.0-msf.sql \
  --schema-svc central-db-rw,facility-1-db-rw --schema-only
```

## Options

| PowerShell        | Bash              | Default                              | Meaning |
| ----------------- | ----------------- | ------------------------------------ | ------- |
| `-Namespace` *(req)* | `--namespace` *(req)* | —                            | Target K8s namespace. |
| `-ReportsDir`     | `--reports-dir`   | —                                    | Folder of `*.json` reports to import. Required unless schema-only. |
| `-SchemaSql`      | `--schema-sql`    | —                                    | Reporting-schema `.sql` to apply first. Omit to import reports only. |
| `-SchemaSvc`      | `--schema-svc`    | `central-db-rw`                      | Comma-separated `*-db-rw` services to apply the schema to. |
| `-SchemaOnly`     | `--schema-only`   | off                                  | Apply the schema and skip report import (requires a schema file). |
| `-Pod`            | `--pod`           | auto-resolved                        | Override the central pod instead of resolving by selector. |
| `-Container`      | `--container`     | —                                    | Container name for multi-container pods. |
| `-Selector`       | `--selector`      | `app.kubernetes.io/name=central,…`   | Label selector used to find the central pod. |
| `-Workdir`        | `--workdir`       | `.`                                  | Working dir inside the pod for `node dist` (e.g. `/app/packages/central-server`). |
| `-DbSvc`          | `--db-svc`        | `central-db-rw`                      | Service used for the before/after snapshot query. |
| `-DbName`         | `--db-name`       | `app`                                | Database name. |
| `-DbRole`         | `--db-role`       | `app`                                | Role the schema is applied as (`SET ROLE`). |
| `-DbContainer`    | `--db-container`  | `postgres`                           | Postgres container name in the CNPG pod. |
| `-Context`        | `--context`       | `demo`                               | kubectl context switched to before any cluster call. Defaults to the demo cluster. |
| `-Apply`          | `--apply`         | off (plan only)                      | Actually write. Prompts for namespace confirmation. |

## What it does on apply

1. **Schema first** (if `--schema-sql` given): for each `--schema-svc`, `exec` into the
   CNPG `rw` service over its local socket (peer auth as the superuser), `SET ROLE` to
   the app role, and apply the file in a single transaction.
2. **Reports**: each `.json` is staged into the pod as base64 (immune to
   encoding/newline truncation), the transferred byte count is verified against the
   source (retried up to 3× on a short write), then imported with
   `node dist importReport -f … -v`. On success the staged `/tmp/<name>.json` is removed;
   if an import fails the run aborts and the file is deliberately left in the pod for
   inspection / re-run.
3. **Snapshot** of report definitions and their latest/published versions is printed
   before and after.

After applying, verify per the runbook (active versions + spot-check that a report runs).

> **Note on the schema transfer.** The schema `.sql` is streamed over the same
> `kubectl exec` stdin pipe as reports, but — unlike reports — it is *not* base64-staged
> or byte-count-verified. The safety net there is `--single-transaction` +
> `ON_ERROR_STOP=1`: a truncated file almost certainly fails to parse and the whole
> transaction rolls back, so a short write aborts rather than partially applying. It
> catches a bad transfer via the transaction, not by verifying the transfer itself.
>
> Report filenames must match `[A-Za-z0-9._-]+` (they are interpolated into a remote
> shell command); the scripts reject anything outside that charset. Compiled report
> names already conform.
