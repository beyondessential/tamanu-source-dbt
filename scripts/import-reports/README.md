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

- `kubectl` on `PATH`, with a context for the target cluster in your kubeconfig. The
  scripts switch to it themselves (`-Context` / `--context`, default `demo`), so you do
  not need to select it first.
- Access to the central-server pod (report import) and the CNPG `*-db-rw`
  services (schema apply + snapshot).
- The reporting-schema `.sql` file and/or the compiled report `.json` files you
  want to import. The build produces them as a bundle folder, `compiled/v<X.Y.Z>/`, holding
  the report JSONs and that version's `reporting-schema-v<X.Y.Z>-*.sql` side by side.

## Safety model: plan first, then confirm

The `importReport` CLI has **no dry run**, so every run starts with a read-only
**PLAN**: the script resolves the pod and the schema target services, lists what *would*
be imported, and prints the current report state. It then asks you to **type the
namespace** to apply. Press Enter instead (or type anything else) and nothing is
written. Pass `-PlanOnly` / `--plan-only` to print the plan and exit without the prompt.

## Usage

Run from `scripts/import-reports/`. Point `-Bundle` / `--bundle` at a compiled bundle
folder to import its reports and apply its reporting schema in one go. The namespace can
be the first argument.

### Windows (PowerShell)

```powershell
# Schema + reports from a bundle — review the plan, then type the namespace to apply
.\import-reports-k8s.ps1 tamanu-syria-demo -Bundle ..\..\compiled\v2.66.0

# Reports only (schema already applied)
.\import-reports-k8s.ps1 tamanu-syria-demo -Bundle ..\..\compiled\v2.66.0 -NoSchema

# Schema only, no report import (a schema file with no reports folder)
.\import-reports-k8s.ps1 tamanu-syria-demo -SchemaSql .\reporting-schema-v2.54.0-msf.sql

# Reports and schema from separate places; plan only, no prompt
.\import-reports-k8s.ps1 tamanu-syria-demo -ReportsDir .\my-reports `
  -SchemaSql .\reporting-schema-v2.54.0-msf.sql -PlanOnly
```

### macOS / Linux (Bash)

```bash
chmod +x import-reports-k8s.sh   # first time only

# Schema + reports from a bundle — review the plan, then type the namespace to apply
./import-reports-k8s.sh tamanu-syria-demo --bundle ../../compiled/v2.66.0

# Reports only (schema already applied)
./import-reports-k8s.sh tamanu-syria-demo --bundle ../../compiled/v2.66.0 --no-schema

# Schema only, no report import (a schema file with no reports folder)
./import-reports-k8s.sh tamanu-syria-demo --schema-sql ./reporting-schema-v2.54.0-msf.sql

# Reports and schema from separate places; plan only, no prompt
./import-reports-k8s.sh tamanu-syria-demo --reports-dir ./my-reports \
  --schema-sql ./reporting-schema-v2.54.0-msf.sql --plan-only
```

## Options

| PowerShell        | Bash              | Default                              | Meaning |
| ----------------- | ----------------- | ------------------------------------ | ------- |
| `-Namespace` *(req)* | `--namespace` *(req)* | —                            | Target K8s namespace. Can also be given as the first argument. |
| `-Bundle`         | `--bundle`        | —                                    | Compiled bundle folder (e.g. `compiled/v2.66.0`). Supplies the reports folder and the schema file; stops if the folder has no `reporting-schema-*.sql` or more than one. |
| `-ReportsDir`     | `--reports-dir`   | the bundle                           | Folder of `*.json` reports to import. Overrides the bundle's. |
| `-SchemaSql`      | `--schema-sql`    | the bundle's `reporting-schema-*.sql` | Reporting-schema `.sql` to apply first. Overrides the bundle's. Given with no reports folder or bundle, the run is schema-only. |
| `-NoSchema`       | `--no-schema`     | off                                  | Skip the schema step (e.g. a bundle whose schema is already applied). |
| `-SchemaSvc`      | `--schema-svc`    | all `*-db-rw` in the namespace       | Comma-separated `*-db-rw` services to apply the schema to. When omitted, they are discovered with `kubectl get svc` (central plus every facility) and listed in the PLAN. |
| `-Pod`            | `--pod`           | auto-resolved                        | Override the central pod instead of resolving by selector. |
| `-Container`      | `--container`     | —                                    | Container name for multi-container pods. |
| `-Selector`       | `--selector`      | `app.kubernetes.io/name=central,…`   | Label selector used to find the central pod. |
| `-Workdir`        | `--workdir`       | `/app/packages/central-server`       | Working dir inside the pod for the central-server CLI. Only override for a non-standard image layout. |
| `-DbSvc`          | `--db-svc`        | `central-db-rw`                      | Service used for the before/after snapshot query. |
| `-DbName`         | `--db-name`       | `app`                                | Database name. |
| `-DbRole`         | `--db-role`       | `app`                                | Role the schema is applied as (`SET ROLE`). |
| `-DbContainer`    | `--db-container`  | `postgres`                           | Postgres container name in the CNPG pod. |
| `-Context`        | `--context`       | `demo`                               | kubectl context switched to before any cluster call. Defaults to the demo cluster. |
| `-PlanOnly`       | `--plan-only`     | off                                  | Print the plan and exit without the apply prompt. |

## What it does once you confirm

1. **Schema first** (unless there is no schema file or `--no-schema` is set): for each target service (`--schema-svc`, or every `*-db-rw` found), `exec` into the
   CNPG `rw` service over its local socket (peer auth as the superuser), `SET ROLE` to
   the app role, and apply the file in a single transaction.
2. **Reports**: each `.json` is copied into the pod with `kubectl cp` (a binary-safe tar
   stream, reliable where `kubectl exec -i` stdin can short-write), the transferred byte
   count is verified against the source (retried up to 3× on a short write), then imported
   with the central-server CLI's
   `importReport -f … -v` — run via `node dist` when the pod ships a built `dist/`, or
   `node --import tsx app` when it does not (build-less 2.60+ images run from source). The
   staged `/tmp/<name>.json` is always removed
   afterwards — on success and on failure alike — so nothing is left in the pod. If an
   import fails, the run aborts with an error naming the report that failed.
3. **Snapshot** of report definitions and their latest/published versions is printed
   before and after.

After applying, verify per the runbook (active versions + spot-check that a report runs).

> **Note on the schema transfer.** Unlike reports — which are copied with `kubectl cp`
> and byte-count-verified — the schema `.sql` is streamed over a `kubectl exec` stdin pipe
> and is *not* verified. The safety net there is `--single-transaction` +
> `ON_ERROR_STOP=1`: a truncated file almost certainly fails to parse and the whole
> transaction rolls back, so a short write aborts rather than partially applying. It
> catches a bad transfer via the transaction, not by verifying the transfer itself.
>
> Report filenames must match `[A-Za-z0-9._-]+` (they are interpolated into a remote
> shell command); the scripts reject anything outside that charset. Compiled report
> names already conform.
