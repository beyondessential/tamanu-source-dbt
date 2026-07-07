<#
.SYNOPSIS
  Import Tamanu report definitions (and optionally a reporting schema) into a central
  server on K8s. PowerShell port of import-reports-k8s.sh. Mechanical plumbing only;
  the runbook owns decisions.

.DESCRIPTION
  The active kubectl context is switched before any cluster call so the run targets the
  intended cluster. It defaults to the demo cluster (-Context demo); pass -Context to
  target a different cluster.

  Default mode is PLAN (read-only): resolves the pod, prints the current report state,
  and shows what WOULD be applied. Nothing is written until you pass -Apply. There is no
  native dry run on the importReport CLI, so this plan/apply split is the safety net.

  Reports to import: every *.json file in -ReportsDir.
  Schema: optional. Pass -SchemaSql to apply a reporting-schema file first (CNPG socket
  mode: exec into the rw Postgres service over its local socket with peer auth as the
  superuser, SET ROLE to the app role, apply in one transaction). Omit -SchemaSql to skip
  the schema step and only import reports. -SchemaSvc may list several services
  (e.g. "central-db-rw,facility-1-db-rw").

  Schema-only: pass -SchemaOnly (with -SchemaSql) to apply the schema and skip report
  import entirely. -ReportsDir and the central pod are not needed in this mode.

.EXAMPLE
  .\import-reports-k8s.ps1 -Namespace tamanu-syria-demo -ReportsDir .\my-reports `
    -SchemaSql .\reporting-schema-v2.54.0-msf.sql `
    -SchemaSvc central-db-rw,facility-1-db-rw `
    -Workdir /app/packages/central-server
  # review the plan, then re-run with -Apply

.EXAMPLE
  # Reports only, schema already applied:
  .\import-reports-k8s.ps1 -Namespace tamanu-syria-demo -ReportsDir .\my-reports `
    -Workdir /app/packages/central-server -Apply

.EXAMPLE
  # Schema only, no report import:
  .\import-reports-k8s.ps1 -Namespace tamanu-syria-demo `
    -SchemaSql .\reporting-schema-v2.54.0-msf.sql `
    -SchemaSvc central-db-rw,facility-1-db-rw -SchemaOnly
  # review the plan, then re-run with -Apply
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Namespace,
  [string]$ReportsDir,
  [string]$SchemaSql,
  [string]$Pod,
  [string]$Container,
  [string]$Selector = "app.kubernetes.io/name=central,app.kubernetes.io/component=api-server",
  [string]$Workdir = ".",
  [string]$SchemaSvc = "central-db-rw",
  [string]$DbSvc = "central-db-rw",
  [string]$DbName = "app",
  [string]$DbRole = "app",
  [string]$DbContainer = "postgres",
  [string]$Context = "demo",
  [switch]$SchemaOnly,
  [switch]$Apply
)

$ErrorActionPreference = "Stop"
# Keep piped file content as UTF-8 without BOM (Win PowerShell 5.1 defaults to ASCII on this pipe)
$OutputEncoding = New-Object System.Text.UTF8Encoding $false

function Assert-LastExit([string]$What) {
  if ($LASTEXITCODE -ne 0) { throw "ERROR: $What failed (exit $LASTEXITCODE)" }
}

# ---- validate inputs --------------------------------------------------------------
if ($SchemaOnly -and -not $SchemaSql) {
  throw "ERROR: -SchemaOnly requires -SchemaSql (there is nothing to apply otherwise)"
}
if ($SchemaSql -and -not (Test-Path -LiteralPath $SchemaSql)) {
  throw "ERROR: schema SQL not found: $SchemaSql"
}
$reports = @()
if (-not $SchemaOnly) {
  if (-not $ReportsDir) { throw "ERROR: -ReportsDir is required unless -SchemaOnly is set" }
  if (-not (Test-Path -LiteralPath $ReportsDir)) { throw "ERROR: reports dir not found: $ReportsDir" }
  $reports = @(Get-ChildItem -LiteralPath $ReportsDir -Filter *.json -File | Sort-Object Name)
  if ($reports.Count -eq 0) { throw "ERROR: no .json files in $ReportsDir" }
}

# ---- switch cluster context -------------------------------------------------------
# So every kubectl call runs against the intended cluster, not whatever was selected.
Write-Host ">> Switching kubectl context to '$Context' ..."
kubectl config use-context $Context
Assert-LastExit "kubectl config use-context $Context"

# ---- resolve the central pod (only needed for report import) ----------------------
if (-not $SchemaOnly -and -not $Pod) {
  $Pod = (kubectl get pods -n $Namespace -l $Selector --field-selector=status.phase=Running `
          -o "jsonpath={.items[0].metadata.name}")
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($Pod)) {
    throw "ERROR: could not resolve a Running central pod (pass -Pod)"
  }
}

# -c only when a container was named (single-container pods do not need it)
$cExec = @()
if ($Container) { $cExec = @("-c", $Container) }

function Invoke-NodeDist([string]$DistArgs) {
  $inner = "cd '$Workdir' && node dist $DistArgs"
  kubectl exec -i -n $Namespace $Pod @cExec -- sh -lc $inner
  Assert-LastExit "node dist $DistArgs"
}

# Socket-mode psql into a CNPG rw service (peer auth as superuser, no password)
function Invoke-PsqlSvc {
  param([string]$Svc, [string[]]$ExtraArgs, [string]$StdinFile)
  $base = @("exec", "-i", "-n", $Namespace, "svc/$Svc", "-c", $DbContainer, "--",
            "psql", "-d", $DbName, "-v", "ON_ERROR_STOP=1") + $ExtraArgs
  if ($StdinFile) {
    Get-Content -Raw -LiteralPath $StdinFile | kubectl @base
  } else {
    kubectl @base
  }
}

$snapshotSql = @"
SELECT rd.id AS definition_id, rd.name, rd.db_schema,
  max(rdv.version_number) AS latest,
  max(rdv.version_number) FILTER (WHERE rdv.status='published') AS latest_published
FROM report_definitions rd
LEFT JOIN report_definition_versions rdv
  ON rdv.report_definition_id = rd.id AND rdv.deleted_at IS NULL
WHERE rd.deleted_at IS NULL
GROUP BY rd.id, rd.name, rd.db_schema
ORDER BY rd.name;
"@

function Show-Snapshot {
  Invoke-PsqlSvc -Svc $DbSvc -ExtraArgs @("-P", "pager=off", "-c", $snapshotSql)
  if ($LASTEXITCODE -ne 0) { Write-Host "  (snapshot unavailable)" }
}

# ---- PLAN -------------------------------------------------------------------------
$svcs = $SchemaSvc.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ }

Write-Host "=================================================================="
Write-Host " PLAN"
Write-Host "   kube context   : $Context"
Write-Host "   namespace      : $Namespace"
if ($SchemaOnly) {
  Write-Host "   central pod    : (skipped - schema-only run)"
} else {
  $podLine = "   central pod    : $Pod"
  if ($Container) { $podLine += "  (container: $Container)" }
  Write-Host $podLine
}
if ($SchemaSql) {
  Write-Host "   schema SQL     : $SchemaSql"
  Write-Host "   schema -> svc  : $($svcs -join ', ')  (db=$DbName role=$DbRole container=$DbContainer)"
} else {
  Write-Host "   schema SQL     : (skipped - none provided)"
}
Write-Host "   snapshot svc   : $DbSvc"
if ($SchemaOnly) {
  Write-Host "   reports dir    : (skipped - schema-only run)"
} else {
  Write-Host "   reports dir    : $ReportsDir  ($($reports.Count) *.json files)"
}
Write-Host "------------------------------------------------------------------"
if ($SchemaOnly) {
  Write-Host " Reports: none (schema-only run)"
} else {
  Write-Host " Reports that WOULD be imported:"
  foreach ($r in $reports) { Write-Host "   - $($r.Name)" }
}
Write-Host "------------------------------------------------------------------"
Write-Host " Current report state (before):"
Show-Snapshot
Write-Host "=================================================================="

if (-not $Apply) {
  Write-Host "PLAN ONLY. Re-run with -Apply to write. Nothing was changed."
  exit 0
}

# ---- APPLY guard ------------------------------------------------------------------
Write-Host ""
if ($SchemaOnly) {
  Write-Host "About to APPLY schema to [$($svcs -join ', ')] into '$Namespace' (schema-only - no reports imported)."
} elseif ($SchemaSql) {
  Write-Host "About to APPLY schema to [$($svcs -join ', ')] and import $($reports.Count) reports into '$Namespace'."
} else {
  Write-Host "About to import $($reports.Count) reports into '$Namespace' (no schema step)."
}
Write-Host "This writes to the live database(s) and has NO dry run."
$confirm = Read-Host "Type the namespace to confirm"
if ($confirm -ne $Namespace) { throw "Confirmation did not match. Aborting." }

# 1) Reporting schema FIRST (if provided), on each target service, as the app role.
# Unlike reports the schema is not byte-count-verified; --single-transaction +
# ON_ERROR_STOP=1 is the safety net, so a short write fails to parse and rolls back.
if ($SchemaSql) {
  foreach ($svc in $svcs) {
    Write-Host ">> Applying reporting schema to svc/$svc as role $DbRole ..."
    Invoke-PsqlSvc -Svc $svc `
      -ExtraArgs @("--single-transaction", "-c", "SET ROLE $DbRole", "-f", "-") `
      -StdinFile $SchemaSql
    Assert-LastExit "schema apply to svc/$svc"
  }
  Write-Host ">> Schema applied."
} else {
  Write-Host ">> No schema file provided; skipping schema step."
}

# 2) Import each report (skipped on a schema-only run)
if ($SchemaOnly) {
  Write-Host ">> Schema-only run; skipping report import."
} else {
  $maxStageAttempts = 3
  foreach ($r in $reports) {
    $bn = $r.Name
    # $bn is interpolated into a remote `sh -lc "... '/tmp/$bn'"`; reject anything outside
    # a safe charset so a stray quote or space can't break the quoting.
    if ($bn -notmatch '^[A-Za-z0-9._-]+$') {
      throw "ERROR: unsafe report filename: $bn (allowed: A-Z a-z 0-9 . _ -)"
    }
    Write-Host ">> Importing $bn ..."
    # Stage as base64 (pure ASCII, immune to newline/encoding truncation), then verify the
    # byte count and retry — the stdin pipe can short-write over the network.
    $expected = (Get-Item -LiteralPath $r.FullName).Length
    $b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($r.FullName))
    $staged = $false
    for ($attempt = 1; $attempt -le $maxStageAttempts; $attempt++) {
      $b64 | kubectl exec -i -n $Namespace $Pod @cExec -- sh -lc "base64 -d > '/tmp/$bn'"
      if ($LASTEXITCODE -ne 0) {
        Write-Host "   stage attempt $attempt/$maxStageAttempts failed (kubectl exit $LASTEXITCODE)"
        continue
      }
      # Verify the staged file is intact before importing (catches a truncated transfer).
      $size = (kubectl exec -i -n $Namespace $Pod @cExec -- sh -lc "wc -c < '/tmp/$bn'").Trim()
      if ($LASTEXITCODE -ne 0) {
        Write-Host "   verify attempt $attempt/$maxStageAttempts failed (kubectl exit $LASTEXITCODE)"
        continue
      }
      if ($size -eq "$expected") { $staged = $true; break }
      Write-Host "   staged $bn is $size bytes, expected $expected (attempt $attempt/$maxStageAttempts); retrying"
    }
    if (-not $staged) {
      throw "ERROR: failed to stage $bn intact after $maxStageAttempts attempts (expected $expected bytes). Aborting."
    }
    # finally{} always removes the staged temp file, even if the import throws; catch{}
    # re-throws naming the report so the CLI says which one failed.
    try {
      Invoke-NodeDist "importReport -f '/tmp/$bn' -v"
    } catch {
      throw "ERROR: importReport failed for $bn. Aborting. ($_)"
    } finally {
      kubectl exec -i -n $Namespace $Pod @cExec -- sh -lc "rm -f '/tmp/$bn'"
      if ($LASTEXITCODE -ne 0) { Write-Host "   (could not remove /tmp/$bn)" }
    }
  }
}

# 3) After snapshot
Write-Host "------------------------------------------------------------------"
Write-Host " Current report state (after):"
Show-Snapshot
Write-Host "=================================================================="
Write-Host "DONE. Verify per the runbook (active versions + spot-check a report runs)."
