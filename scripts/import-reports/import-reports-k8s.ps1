<#
.SYNOPSIS
  Import Tamanu report definitions (and optionally a reporting schema) into a central
  server on K8s. PowerShell port of import-reports-k8s.sh. Mechanical plumbing only;
  the runbook owns decisions.

.DESCRIPTION
  The active kubectl context is switched before any cluster call so the run targets the
  intended cluster. It defaults to the demo cluster (-Context demo); pass -Context to
  target a different cluster.

  Every run starts with a read-only PLAN: resolves the pod, prints the current report
  state, and shows what WOULD be applied. It then asks you to type the namespace to apply;
  press Enter instead to stop with nothing changed. -PlanOnly prints the plan and exits
  without asking. There is no native dry run on the importReport CLI, so this
  plan-then-confirm step is the safety net.

  Bundle: -Bundle points at a compiled bundle folder (e.g. compiled\v2.66.0). Its *.json
  files are imported and its single reporting-schema-*.sql is applied first. -ReportsDir
  and -SchemaSql override either half; -NoSchema skips the schema step.

  Reports to import: every *.json file in -ReportsDir (or -Bundle).
  Schema: optional. The reporting-schema file is applied first (CNPG socket mode: exec
  into the rw Postgres service over its local socket with peer auth as the superuser,
  SET ROLE to the app role, apply in one transaction). The schema goes to every *-db-rw
  service in the namespace (central plus each facility), discovered automatically; pass
  -SchemaSvc (e.g. "central-db-rw,facility-1-db-rw") to target specific services instead.

  Schema-only: pass -SchemaSql without -ReportsDir or -Bundle to apply the schema and
  skip report import entirely. The central pod is not needed in this mode.

.EXAMPLE
  # Schema + reports from a compiled bundle; review the plan, then type the namespace:
  .\import-reports-k8s.ps1 tamanu-syria-demo -Bundle ..\..\compiled\v2.66.0

.EXAMPLE
  # Reports only, schema already applied:
  .\import-reports-k8s.ps1 tamanu-syria-demo -Bundle ..\..\compiled\v2.66.0 -NoSchema

.EXAMPLE
  # Schema only, no report import:
  .\import-reports-k8s.ps1 tamanu-syria-demo -SchemaSql .\reporting-schema-v2.54.0-msf.sql

.EXAMPLE
  # Separate reports folder and schema file, plan only:
  .\import-reports-k8s.ps1 tamanu-syria-demo -ReportsDir .\my-reports `
    -SchemaSql .\reporting-schema-v2.54.0-msf.sql -PlanOnly
#>

[CmdletBinding()]
param(
  [Parameter(Position = 0)][string]$Namespace,
  [string]$Bundle,
  [string]$ReportsDir,
  [string]$SchemaSql,
  [string]$Pod,
  [string]$Container,
  [string]$Selector = "app.kubernetes.io/name=central,app.kubernetes.io/component=api-server",
  [string]$Workdir = "/app/packages/central-server",
  [string]$SchemaSvc,
  [string]$DbSvc = "central-db-rw",
  [string]$DbName = "app",
  [string]$DbRole = "app",
  [string]$DbContainer = "postgres",
  [string]$Context = "demo",
  [switch]$NoSchema,
  [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
# Keep piped file content as UTF-8 without BOM (Win PowerShell 5.1 defaults to ASCII on this pipe)
$OutputEncoding = New-Object System.Text.UTF8Encoding $false

function Assert-LastExit([string]$What) {
  if ($LASTEXITCODE -ne 0) { throw "ERROR: $What failed (exit $LASTEXITCODE)" }
}

# ---- validate inputs --------------------------------------------------------------
# Checked here rather than via Mandatory so a missing namespace errors out (as the Bash
# script does) instead of stopping at an interactive prompt.
if (-not $Namespace) { throw "ERROR: -Namespace is required" }
if ($NoSchema -and $SchemaSql) {
  throw "ERROR: -NoSchema and -SchemaSql contradict each other; pass one or neither"
}
# A bundle folder supplies whichever of reports / schema was not given explicitly.
if ($Bundle) {
  if (-not (Test-Path -LiteralPath $Bundle -PathType Container)) { throw "ERROR: bundle dir not found: $Bundle" }
  if (-not $ReportsDir) { $ReportsDir = $Bundle }
  if (-not $SchemaSql -and -not $NoSchema) {
    $found = @(Get-ChildItem -LiteralPath $Bundle -Filter "reporting-schema-*.sql" -File)
    if ($found.Count -eq 0) {
      throw "ERROR: no reporting-schema-*.sql in $Bundle (pass -SchemaSql, or -NoSchema to skip it)"
    }
    if ($found.Count -gt 1) {
      throw "ERROR: several reporting-schema-*.sql in $Bundle ($($found.Name -join ', ')); pass -SchemaSql"
    }
    $SchemaSql = Join-Path $Bundle $found[0].Name
  }
}
if (-not $ReportsDir -and -not $SchemaSql) {
  throw "ERROR: nothing to do - pass -Bundle, -ReportsDir or -SchemaSql"
}
# A schema file with no reports folder is a schema-only run.
$SchemaOnly = -not $ReportsDir
if ($SchemaSql -and -not (Test-Path -LiteralPath $SchemaSql)) {
  throw "ERROR: schema SQL not found: $SchemaSql"
}
$reports = @()
if (-not $SchemaOnly) {
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

function Invoke-CentralCli([string]$CliArgs) {
  # Pick the entry point in the pod: a dist/ directory means node resolves it as before
  # (index.js or package.json main); no dist/ means the image is build-less (2.60+) so run
  # from TS source via tsx. Error out if neither is present (usually a wrong -Workdir).
  $inner = "cd '$Workdir' && if [ -d dist ]; then node dist $CliArgs; elif [ -d app ]; then node --import tsx app $CliArgs; else echo `"ERROR: no central-server entry point under `$(pwd) - check -Workdir`" >&2; exit 1; fi"
  kubectl exec -i -n $Namespace $Pod @cExec -- sh -lc $inner
  Assert-LastExit "central-server CLI: $CliArgs"
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
SELECT rd.id, rd.name, rd.db_schema,
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

# ---- resolve schema target services ----------------------------------------------
# Without -SchemaSvc, target every CNPG rw service in the namespace (central-db-rw,
# facility-N-db-rw, ...) so new facilities are picked up without editing the command.
$svcs = @()
$svcSource = "from -SchemaSvc"
if ($SchemaSql) {
  if ($SchemaSvc) {
    $svcs = @($SchemaSvc.Split(",") | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  } else {
    $svcSource = "auto-discovered"
    $allSvcs = (kubectl get svc -n $Namespace -o "jsonpath={.items[*].metadata.name}")
    Assert-LastExit "kubectl get svc -n $Namespace"
    $svcs = @("$allSvcs".Split(" ") | Where-Object { $_ -match '-db-rw$' } | Sort-Object)
    if ($svcs.Count -eq 0) {
      throw "ERROR: no *-db-rw services found in namespace $Namespace (pass -SchemaSvc)"
    }
  }
}

# ---- PLAN -------------------------------------------------------------------------

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
  Write-Host "   schema -> svc  : $($svcs -join ', ')  ($svcSource; db=$DbName role=$DbRole container=$DbContainer)"
} else {
  if ($NoSchema) {
    Write-Host "   schema SQL     : (skipped - -NoSchema)"
  } else {
    Write-Host "   schema SQL     : (skipped - none provided)"
  }
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

if ($PlanOnly) {
  Write-Host "PLAN ONLY. Re-run without -PlanOnly to apply. Nothing was changed."
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
# No usable console (e.g. -NonInteractive) counts as pressing Enter: stop without writing.
try {
  $confirm = Read-Host "Type the namespace to apply (or press Enter to stop)"
} catch {
  $confirm = ""
}
if ([string]::IsNullOrWhiteSpace($confirm)) {
  Write-Host "Stopped. Nothing was changed."
  exit 0
}
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
    # Stage with `kubectl cp` (binary-safe tar stream, reliable) rather than piping base64
    # over `kubectl exec -i` stdin, which short-writes over the network on Windows. Verify the
    # byte count and retry regardless, as cheap insurance.
    $expected = (Get-Item -LiteralPath $r.FullName).Length
    $staged = $false
    for ($attempt = 1; $attempt -le $maxStageAttempts; $attempt++) {
      # kubectl cp mis-parses a Windows drive-letter path (C:\...) as a remote spec, so cd into
      # the report's directory and pass the bare filename ($bn is charset-validated above).
      Push-Location -LiteralPath $r.DirectoryName
      kubectl cp -n $Namespace @cExec $bn "${Pod}:/tmp/$bn"
      $cpRc = $LASTEXITCODE
      Pop-Location
      if ($cpRc -ne 0) {
        Write-Host "   stage attempt $attempt/$maxStageAttempts failed (kubectl cp exit $cpRc)"
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
      # Drop the partial/failed temp file before aborting so nothing is left in the pod.
      kubectl exec -i -n $Namespace $Pod @cExec -- sh -lc "rm -f '/tmp/$bn'" | Out-Null
      throw "ERROR: failed to stage $bn intact after $maxStageAttempts attempts (expected $expected bytes). Aborting."
    }
    # finally{} always removes the staged temp file, even if the import throws; catch{}
    # re-throws naming the report so the CLI says which one failed.
    try {
      Invoke-CentralCli "importReport -f '/tmp/$bn' -v"
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
