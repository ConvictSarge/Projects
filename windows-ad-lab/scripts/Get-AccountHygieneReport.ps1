<#
.SYNOPSIS
  Report stale accounts, passwords about to expire, accounts that never logged on, and non-expiring passwords.
.DESCRIPTION
  Read-only. Uses lastLogonTimestamp (replicated, accurate to about 14 days, which is fine for
  stale-account reviews) and the computed msDS-UserPasswordExpiryTimeComputed attribute, which
  already accounts for fine-grained password policies.
.EXAMPLE
  .\Get-AccountHygieneReport.ps1 -StaleDays 90 -ExpiryWarnDays 14 -CsvPath C:\reports\hygiene.csv
#>
[CmdletBinding()]
param(
    [int] $StaleDays = 90,
    [int] $ExpiryWarnDays = 14,
    [string] $CsvPath
)
Import-Module ActiveDirectory
$now = Get-Date
$users = Get-ADUser -Filter 'Enabled -eq $true' -Properties lastLogonTimestamp, whenCreated, PasswordNeverExpires, 'msDS-UserPasswordExpiryTimeComputed'

$report = foreach ($u in $users) {
    $last = if ($u.lastLogonTimestamp) { [DateTime]::FromFileTime($u.lastLogonTimestamp) } else { $null }
    $expRaw = $u.'msDS-UserPasswordExpiryTimeComputed'
    $expires = if ($expRaw -and $expRaw -lt [Int64]::MaxValue -and $expRaw -gt 0) { [DateTime]::FromFileTime($expRaw) } else { $null }
    $issues = @()
    if ($u.PasswordNeverExpires) { $issues += 'password never expires' }
    if (-not $last -and $u.whenCreated -lt $now.AddDays(-14)) { $issues += 'never logged on (created over 14 days ago)' }
    elseif ($last -and $last -lt $now.AddDays(-$StaleDays)) { $issues += "no logon in $StaleDays+ days" }
    if ($expires -and $expires -lt $now.AddDays($ExpiryWarnDays)) { $issues += "password expires {0:yyyy-MM-dd}" -f $expires }
    if ($issues) {
        [pscustomobject]@{ SamAccountName = $u.SamAccountName; LastLogon = $last; PasswordExpires = $expires; Issues = $issues -join '; ' }
    }
}
if ($CsvPath) { $report | Export-Csv $CsvPath -NoTypeInformation }
Write-Output ("{0} enabled accounts checked, {1} need attention" -f @($users).Count, @($report).Count)
$report | Sort-Object SamAccountName | Format-Table -AutoSize | Out-String -Width 200 | Write-Output
