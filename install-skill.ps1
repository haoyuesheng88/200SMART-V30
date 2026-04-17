$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceSkill = Join-Path $repoRoot ".codex\\skills\\s7-200smart"
$targetRoot = Join-Path $HOME ".codex\\skills"
$targetSkill = Join-Path $targetRoot "s7-200smart"

if (-not (Test-Path -LiteralPath $sourceSkill)) {
  throw "Skill source folder not found: $sourceSkill"
}

New-Item -ItemType Directory -Force -Path $targetRoot | Out-Null
if (Test-Path -LiteralPath $targetSkill) {
  Remove-Item -LiteralPath $targetSkill -Recurse -Force
}

Copy-Item -LiteralPath $sourceSkill -Destination $targetRoot -Recurse -Force
Write-Output "Installed s7-200smart to $targetSkill"
