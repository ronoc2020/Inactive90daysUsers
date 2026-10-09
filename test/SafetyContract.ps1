#Requires -Version 7.0
# Dependency-free static contract checks. Execute with:
# pwsh -NoProfile -File ./test/SafetyContract.ps1
$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot '../AAD_Innactive90days_Users.ps1'
$errors = $null
$tokens = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath, [ref]$tokens, [ref]$errors
)
if ($errors.Count -gt 0) {
    throw ('PowerShell parse failure: ' + (($errors | ForEach-Object { $_.Message }) -join '; '))
}

$names = @($ast.FindAll({
    param($node) $node -is [System.Management.Automation.Language.CommandAst]
}, $true) | ForEach-Object { $_.GetCommandName() })
$forbidden = @(
    'Set-AzureADUser', 'Remove-AzureADUser', 'Update-MgUser',
    'Remove-MgUser', 'Disable-MgUser', 'Invoke-MgGraphRequest'
)
$present = @($names | Where-Object { $_ -in $forbidden })
if ($present.Count -gt 0) {
    throw ('Read-only safety contract failed; write commands found: ' + ($present -join ', '))
}

$content = Get-Content -Path $scriptPath -Raw -Encoding utf8
if ($content -notmatch 'lastSuccessfulSignInDateTime') {
    throw 'Successful sign-in timestamp must be used for account inactivity.'
}
if ($content -match '\.LastDirSyncTime\b') {
    throw 'Synchronization timestamp cannot be used as last sign-in.'
}
if ($content -notmatch 'InsufficientData') {
    throw 'Missing sign-in activity must not be assumed to mean inactivity.'
}
if ($content -notmatch 'Export-Csv') {
    throw 'The read-only CSV output is missing.'
}
Write-Host 'PASS: script parses and read-only safety checks passed.'
