# Inactive90daysUsers — safe Microsoft Entra ID inactivity review

**Read-only by design.** Generates a CSV of Microsoft Entra ID user accounts that may require an inactivity review. It **never disables users** and makes no changes to your tenant.

## Why it was corrected

The previous script used `LastDirSyncTime` as though it represented the last user sign-in. It does **not**: it describes directory synchronization, not account activity. It also attempted to disable accounts automatically. That behavior has been removed.

## Requirements

- PowerShell 7+.
- `Microsoft.Graph.Users` and `Microsoft.Graph.Authentication` modules.
- Permission to read directory user and sign-in activity (`User.Read.All` and `AuditLog.Read.All` delegated scopes).
- Entra ID P1/P2 licensing and a suitable administrative role for sign-in activity access, where required.

Install the modules if needed:

```powershell
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

## Usage

```powershell
pwsh ./AAD_Innactive90days_Users.ps1 -DaysInactive 90 -OutputPath ./inactive-review.csv
```

The script reports **enabled member users**, not guest accounts, and assigns one of these statuses:

| Status | Meaning |
| --- | --- |
| `ReviewCandidate` | User was created before the cutoff and their **last successful** sign-in is older than the cutoff. |
| `Active` | Recent successful sign-in observed. |
| `RecentlyCreated` | Account is younger than the review threshold. |
| `InsufficientData` | No reliable successful sign-in or creation timestamp available. **Not evidence of inactivity.** |

> Microsoft Graph's `lastSuccessfulSignInDateTime` is available from December 2023 and is **not backfilled**. A missing value cannot prove inactivity. Check identity, business owner, service dependencies, and logs before any manual account change.

**No disabling action is implemented.** If you need a future deprovisioning workflow, it should use an explicit reviewed approval list, independent safeguards, audit evidence, and a reversible process.

## Offline safety check

The repository includes a static, read-only contract test:

```powershell
pwsh -NoProfile -File ./test/SafetyContract.ps1
```

This checks PowerShell syntax, blocks common user-write commands, and confirms that last successful sign-in rather than directory synchronization drives the report. It is not a substitute for tenant-level authorization checks. Run it locally before use.

## Security notes

- No secrets or credentials are saved in the repo.
- Do not commit generated CSV files, as they contain user-identifying account information. `.gitignore` excludes CSV, TSV and local environment files.
- Use read-only Graph permissions; do not grant account write permissions to run this script.
- This repository contains no GitHub Actions workflows, so updates do not consume Actions minutes.

## References

- [Microsoft Graph signInActivity (v1.0)](https://learn.microsoft.com/en-us/graph/api/resources/signinactivity?view=graph-rest-1.0)
- [Manage inactive users in Microsoft Entra ID](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-manage-inactive-user-accounts)
