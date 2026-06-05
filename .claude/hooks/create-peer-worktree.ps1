$ErrorActionPreference = "Stop"

$rawInput = [Console]::In.ReadToEnd()

if ([string]::IsNullOrWhiteSpace($rawInput)) {
  Write-Error "WorktreeCreate hook did not receive input JSON."
  exit 1
}

$inputJson = $rawInput | ConvertFrom-Json
$name = $inputJson.name

if ([string]::IsNullOrWhiteSpace($name)) {
  Write-Error "Worktree name is empty."
  exit 1
}

$projectDir = $env:CLAUDE_PROJECT_DIR

if ([string]::IsNullOrWhiteSpace($projectDir)) {
  $projectDir = (Get-Location).Path
}

$projectDir = (Resolve-Path $projectDir).Path
$projectName = Split-Path -Leaf $projectDir
$parentDir = Split-Path -Parent $projectDir

$worktreeDir = Join-Path $parentDir $name
$branchName = "worktree-$name"

if (Test-Path $worktreeDir) {
  Write-Error "Worktree directory already exists: $worktreeDir"
  exit 1
}

git -C $projectDir show-ref --verify --quiet "refs/heads/$branchName"

if ($LASTEXITCODE -eq 0) {
  Write-Error "Branch already exists: $branchName"
  exit 1
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = "Continue"
$gitOutput = & git -C $projectDir worktree add $worktreeDir -b $branchName HEAD 2>&1
$gitExitCode = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference

if ($gitOutput) {
  [Console]::Error.WriteLine(($gitOutput | Out-String).TrimEnd())
}

if ($gitExitCode -ne 0) {
  Write-Error "git worktree add failed."
  exit 1
}

$nestedProjectDir = Join-Path $worktreeDir $projectName

if ($projectName -and ($nestedProjectDir -ne $worktreeDir) -and (Test-Path $nestedProjectDir)) {
  Get-ChildItem -Force -LiteralPath $nestedProjectDir | ForEach-Object {
    Move-Item -LiteralPath $_.FullName -Destination $worktreeDir -Force
  }

  Remove-Item -LiteralPath $nestedProjectDir -Recurse -Force
}

if (-not (Test-Path $worktreeDir)) {
  Write-Error "Worktree directory was not created: $worktreeDir"
  exit 1
}

$resolvedWorktreeDir = (Resolve-Path $worktreeDir).Path

Write-Output $resolvedWorktreeDir
