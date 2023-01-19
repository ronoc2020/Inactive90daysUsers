# Connect to Azure AD
Connect-AzureAD

# Set the number of days since last logon
$DaysInactive = 90
$InactiveDate = (Get-Date).AddDays(-$DaysInactive)

# Find inactive users
$Users = Get-AzureADUser -All $true | Where-Object {$_.LastDirSyncTime -lt $InactiveDate -and $_.AccountEnabled -eq $true} | Select-Object UserPrincipalName, DisplayName, LastDirSyncTime

# Export results to CSV
$Users | Export-Csv C:\Inactive90daysUsers.csv -NoTypeInformation

# Disable Inactive Users
ForEach ($User in $Users){
  Set-AzureADUser -ObjectId $User.ObjectId -AccountEnabled $false
  Get-AzureADUser -ObjectId $User.ObjectId | Select-Object UserPrincipalName, DisplayName, AccountEnabled
}
