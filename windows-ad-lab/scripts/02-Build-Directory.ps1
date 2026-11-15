<#
.SYNOPSIS
  Build the lab's OU layout, department groups, admin tiering, password policies and GPOs.
.DESCRIPTION
  Idempotent: safe to run again; anything that already exists is left alone.
  Layout:
    OU=Lab
      OU=Staff\<Department>     user accounts, one OU per department
      OU=Groups                 one global security group per department (GG-<Department>)
      OU=Admins                 separate admin accounts (never used for email or browsing)
      OU=Service Accounts
      OU=Workstations
      OU=Disabled Users         where offboarded accounts are parked
  Policies:
    - Default domain password policy: 14 characters, history 24, lockout after 10 tries for 15 minutes
    - Fine-grained policy for Admins: 20 characters
    - GPO "Staff - Screen Lock": lock idle sessions after 15 minutes
    - GPO "Workstations - Hardening": no LM hashes, NTLMv2 only, SMB signing required
#>
[CmdletBinding()]
param(
    [string[]] $Departments = @('IT', 'Finance', 'Sales', 'Operations', 'HR')
)
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory, GroupPolicy

$domain = Get-ADDomain
$root   = $domain.DistinguishedName

function Ensure-OU([string] $Name, [string] $Path) {
    $dn = "OU=$Name,$Path"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$dn'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion $true
        Write-Host "created OU $dn"     # Write-Host, not Write-Output: the function's only output must be the DN
    }
    return $dn
}

$lab = Ensure-OU 'Lab' $root
$staff, $groups, $admins, $svc, $wks, $disabled = foreach ($n in 'Staff', 'Groups', 'Admins', 'Service Accounts', 'Workstations', 'Disabled Users') {
    Ensure-OU $n $lab
}
foreach ($d in $Departments) {
    [void](Ensure-OU $d $staff)
    if (-not (Get-ADGroup -Filter "Name -eq 'GG-$d'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name "GG-$d" -GroupScope Global -GroupCategory Security -Path $groups -Description "$d department staff"
        Write-Output "created group GG-$d"
    }
}
if (-not (Get-ADGroup -Filter "Name -eq 'GG-Lab-Admins'" -ErrorAction SilentlyContinue)) {
    New-ADGroup -Name 'GG-Lab-Admins' -GroupScope Global -GroupCategory Security -Path $groups -Description 'Separate admin accounts'
}

# Domain password and lockout policy
Set-ADDefaultDomainPasswordPolicy -Identity $domain.DNSRoot -MinPasswordLength 14 -PasswordHistoryCount 24 `
    -LockoutThreshold 10 -LockoutDuration '00:15:00' -LockoutObservationWindow '00:15:00' `
    -ComplexityEnabled $true -MaxPasswordAge '365.00:00:00'

# Stricter fine-grained policy for admin accounts
if (-not (Get-ADFineGrainedPasswordPolicy -Filter "Name -eq 'PSO-Admins'" -ErrorAction SilentlyContinue)) {
    New-ADFineGrainedPasswordPolicy -Name 'PSO-Admins' -Precedence 10 -MinPasswordLength 20 -PasswordHistoryCount 24 `
        -ComplexityEnabled $true -LockoutThreshold 5 -LockoutDuration '00:30:00' -LockoutObservationWindow '00:30:00' `
        -MaxPasswordAge '180.00:00:00' -MinPasswordAge '1.00:00:00' -ReversibleEncryptionEnabled $false
    Add-ADFineGrainedPasswordPolicySubject -Identity 'PSO-Admins' -Subjects 'GG-Lab-Admins'
    Write-Output 'created fine-grained policy PSO-Admins'
}

# GPO: lock idle user sessions after 15 minutes
if (-not (Get-GPO -Name 'Staff - Screen Lock' -ErrorAction SilentlyContinue)) {
    $g = New-GPO -Name 'Staff - Screen Lock' -Comment 'Lock idle sessions after 15 minutes'
    Set-GPRegistryValue -Name $g.DisplayName -Key 'HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System' `
        -ValueName 'InactivityTimeoutSecs' -Type DWord -Value 900 | Out-Null
    New-GPLink -Name $g.DisplayName -Target $wks | Out-Null
    Write-Output 'created and linked GPO Staff - Screen Lock'
}

# GPO: basic workstation hardening
if (-not (Get-GPO -Name 'Workstations - Hardening' -ErrorAction SilentlyContinue)) {
    $g = New-GPO -Name 'Workstations - Hardening' -Comment 'NTLMv2 only, no LM hashes, SMB signing'
    $lsa = 'HKLM\SYSTEM\CurrentControlSet\Control\Lsa'
    Set-GPRegistryValue -Name $g.DisplayName -Key $lsa -ValueName 'LmCompatibilityLevel' -Type DWord -Value 5 | Out-Null
    Set-GPRegistryValue -Name $g.DisplayName -Key $lsa -ValueName 'NoLMHash' -Type DWord -Value 1 | Out-Null
    Set-GPRegistryValue -Name $g.DisplayName -Key 'HKLM\SYSTEM\CurrentControlSet\Services\LanmanWorkstation\Parameters' `
        -ValueName 'RequireSecuritySignature' -Type DWord -Value 1 | Out-Null
    New-GPLink -Name $g.DisplayName -Target $wks | Out-Null
    Write-Output 'created and linked GPO Workstations - Hardening'
}

# New computer accounts land in Workstations instead of the default Computers container
redircmp $wks | Out-Null
Write-Output 'directory build complete'
