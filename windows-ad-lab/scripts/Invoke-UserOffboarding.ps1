<#
.SYNOPSIS
  Offboard a user: disable, record and remove group memberships, scramble the password, park the account.
.DESCRIPTION
  Nothing is deleted. The account is disabled, its groups are saved to a CSV (so access can be
  restored if offboarding was a mistake), group memberships are removed, the password is set to
  a random value, the description records who/when/why, and the account moves to OU=Disabled Users.
.EXAMPLE
  .\Invoke-UserOffboarding.ps1 -SamAccountName jdoe -Ticket CHG-1042 -AuditFolder C:\offboarding
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $SamAccountName,
    [Parameter(Mandatory)] [string] $Ticket,
    [string] $AuditFolder = "$env:ProgramData\Offboarding"
)
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$domain = Get-ADDomain
$user = Get-ADUser $SamAccountName -Properties MemberOf, Description
$disabledOu = "OU=Disabled Users,OU=Lab,$($domain.DistinguishedName)"

if ($PSCmdlet.ShouldProcess($user.SamAccountName, 'Offboard')) {
    New-Item -ItemType Directory -Force -Path $AuditFolder | Out-Null
    $stamp = Get-Date -Format 'yyyy-MM-dd'
    # Timestamped file, never overwritten: a re-run must not replace the original group record.
    $audit = Join-Path $AuditFolder ("{0}-groups-{1:yyyyMMdd-HHmmss}.csv" -f $user.SamAccountName, (Get-Date))
    $user.MemberOf | ForEach-Object { [pscustomobject]@{ User = $user.SamAccountName; Group = $_; Removed = $stamp; Ticket = $Ticket } } |
        Export-Csv $audit -NoTypeInformation

    # Scramble the password first (works on Windows PowerShell 5.1 and PowerShell 7).
    $bytes = New-Object byte[] 32
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create(); $rng.GetBytes($bytes); $rng.Dispose()
    Set-ADAccountPassword $user -Reset -NewPassword (ConvertTo-SecureString ([Convert]::ToBase64String($bytes) + 'aA1!') -AsPlainText -Force)
    Disable-ADAccount $user
    foreach ($g in $user.MemberOf) { Remove-ADGroupMember -Identity $g -Members $user -Confirm:$false }
    Set-ADUser $user -Description ("Offboarded {0} by {1} ({2})" -f $stamp, $env:USERNAME, $Ticket)
    Move-ADObject $user.DistinguishedName -TargetPath $disabledOu
    Write-Output ("offboarded {0}: disabled, {1} group(s) removed and saved, moved to Disabled Users" -f $user.SamAccountName, @($user.MemberOf).Count)
}
