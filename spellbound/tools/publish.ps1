# Creates a NEW GitHub repository and pushes this folder. Never force-pushes.
# Default visibility is PUBLIC. Use -Visibility private to change it.
[CmdletBinding()]
param(
    [ValidatePattern('^[A-Za-z0-9_.-]+$')][string]$Name = 'spellbound',
    [ValidateSet('public', 'private')][string]$Visibility = 'public',
    [string]$Owner = ''
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
foreach ($Command in @('git', 'gh')) {
    if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
        throw "$Command is required. Install Git and GitHub CLI, then run gh auth login."
    }
}
function Check-Exit([string]$Operation) {
    if ($LASTEXITCODE -ne 0) { throw "$Operation failed (exit $LASTEXITCODE). No force-push was attempted." }
}
Push-Location $Root
try {
    gh auth status
    Check-Exit 'GitHub authentication; run gh auth login'
    $Profile = gh api user | ConvertFrom-Json
    Check-Exit 'Reading authenticated account'
    if (-not $Owner) { $Owner = $Profile.login }
    if ($Owner -notmatch '^[A-Za-z0-9-]+$') { throw 'Invalid owner name.' }
    $FullName = "$Owner/$Name"
    gh repo view $FullName --json nameWithOwner 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        throw "$FullName already exists. Use -Name with a new name; this script never overwrites a repository."
    }
    if (-not (Test-Path '.git')) { git init -b main; Check-Exit 'Git initialization' }
    $Origin = git remote get-url origin 2>$null
    if ($LASTEXITCODE -eq 0) { throw "This folder already has origin: $Origin. Nothing was published." }
    git add --all
    Check-Exit 'Staging files'
    git diff --cached --quiet
    if ($LASTEXITCODE -eq 1) {
        $Author = $Profile.login
        $Email = "$($Profile.id)+$($Profile.login)@users.noreply.github.com"
        git -c "user.name=$Author" -c "user.email=$Email" commit -m 'Implement Spellbound badge duels'
        Check-Exit 'Creating commit'
    }
    Write-Host "Creating $Visibility repository $FullName from $Root"
    gh repo create $FullName "--$Visibility" --source . --remote origin --push --description 'Teachable motion-controlled spellcasting duels for the Hack the North 2026 badge'
    Check-Exit 'Repository creation/push'
    gh repo view --json url --jq .url
    Check-Exit 'Reading new repository URL'
} finally {
    Pop-Location
}
