#Requires -Version 7.0
<#
.SYNOPSIS
    Read-only report of potentially inactive Microsoft Entra ID user accounts.
.DESCRIPTION
    Uses Microsoft Graph lastSuccessfulSignInDateTime (not LastDirSyncTime).
    NEVER disables accounts. Missing sign-in history is explicitly marked
    InsufficientData rather than treated as inactivity.
    Requires Microsoft.Graph.Users and Microsoft.Graph.Authentication modules,
    suitable Microsoft Entra permissions, and P1/P2 for signInActivity.
.EXAMPLE
    ./AAD_Innactive90days_Users.ps1 -DaysInactive 90 -OutputPath ./inactive-review.csv
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 3650)]
    [int]$DaysInactive = 90,

    [string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
$cutoff = [DateTimeOffset]::UtcNow.AddDays(-$DaysInactive)

if (-not $OutputPath) {
    $OutputPath = Join-Path (Get-Location).Path ('EntraInactiveReview-{0:yyyyMMdd-HHmmss}.csv' -f [DateTime]::UtcNow)
}

if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Users)) {
    throw 'Microsoft.Graph.Users is required. Install-Module Microsoft.Graph.Users -Scope CurrentUser'
}

Import-Module Microsoft.Graph.Users -ErrorAction Stop
Import-Module Microsoft.Graph.Authentication -ErrorAction Stop

$context = Get-MgContext
if (-not $context) {
    Connect-MgGraph -Scopes @('User.Read.All', 'AuditLog.Read.All') -NoWelcome
}

$properties = @(
    'id', 'displayName', 'userPrincipalName', 'accountEnabled',
    'userType', 'createdDateTime', 'signInActivity'
)
$users = @(Get-MgUser -All -PageSize 500 -Property $properties -ErrorAction Stop)
$results = @(
    foreach ($user in $users) {
        if ($user.AccountEnabled -ne $true -or $user.UserType -ne 'Member') {
            continue
        }

        $activity = $user.SignInActivity
        if (-not $activity -and $user.AdditionalProperties) {
            $activity = $user.AdditionalProperties['signInActivity']
        }

        $lastValue = $null
        if ($activity) {
            if ($activity -is [System.Collections.IDictionary]) {
                $lastValue = $activity['lastSuccessfulSignInDateTime']
            } else {
                $lastValue = $activity.LastSuccessfulSignInDateTime
            }
        }

        $lastSignIn = $null
        if ($lastValue) {
            $lastSignIn = [DateTimeOffset]::Parse(
                [string]$lastValue, [System.Globalization.CultureInfo]::InvariantCulture
            )
        }

        $created = $null
        if ($user.CreatedDateTime) {
            $created = [DateTimeOffset]$user.CreatedDateTime
        }

        $status = if (-not $lastSignIn -or -not $created) {
            'InsufficientData'
        } elseif ($created -gt $cutoff) {
            'RecentlyCreated'
        } elseif ($lastSignIn -lt $cutoff) {
            'ReviewCandidate'
        } else {
            'Active'
        }

        [PSCustomObject]@{
            UserPrincipalName         = $user.UserPrincipalName
            DisplayName               = $user.DisplayName
            CreatedDateTimeUtc        = if ($created) { $created.UtcDateTime.ToString('o') } else { '' }
            LastSuccessfulSignInUtc   = if ($lastSignIn) { $lastSignIn.UtcDateTime.ToString('o') } else { '' }
            DaysSinceSuccessfulSignIn = if ($lastSignIn) {
                [int][Math]::Floor(([DateTimeOffset]::UtcNow - $lastSignIn).TotalDays)
            } else { $null }
            ReviewStatus              = $status
        }
    }
)

if ($results.Count -eq 0) {
    Write-Warning 'No enabled member accounts returned. No CSV written.'
    return
}

$results | Sort-Object ReviewStatus, UserPrincipalName |
    Export-Csv -Path $OutputPath -NoTypeInformation -Encoding utf8
$summary = $results | Group-Object ReviewStatus |
    Select-Object Name, Count

Write-Host "Read-only account review saved to: $OutputPath"
$summary | Format-Table -AutoSize
Write-Warning 'Review candidates manually. This script NEVER disables accounts.'
