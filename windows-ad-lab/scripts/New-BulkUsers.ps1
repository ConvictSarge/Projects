<#
.SYNOPSIS
  Create user accounts in bulk from a CSV (onboarding).
.DESCRIPTION
  CSV columns: FirstName,LastName,Department,Title
  For each row: builds a unique sAMAccountName (first initial + last name, with a number added
  on collision), creates the user in OU=<Department>,OU=Staff,OU=Lab, adds them to GG-<Department>,
  sets a random temporary password and forces a change at first logon.
  Temporary passwords are written ONLY to the output file you name (meant for a secure hand-off),
  never to the console. Use -WhatIf to preview.
.EXAMPLE
  .\New-BulkUsers.ps1 -CsvPath .\sample-users.csv -PasswordFile C:\secure\onboarding.csv -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)] [string] $CsvPath,
    [Parameter(Mandatory)] [string] $PasswordFile
)
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
$domain = Get-ADDomain

function New-TempPassword {
    # 16 characters from all four classes; RNG-based, not Get-Random
    $sets = 'ABCDEFGHJKLMNPQRSTUVWXYZ', 'abcdefghijkmnopqrstuvwxyz', '23456789', '!@#$%*-_=+'
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $pick = { param($s) $b = [byte[]]::new(1); $rng.GetBytes($b); $s[$b[0] % $s.Length] }
    $chars = foreach ($s in $sets) { & $pick $s }          # one from each class
    $all = -join $sets
    $chars += 1..12 | ForEach-Object { & $pick $all }
    -join ($chars | Sort-Object { $b = [byte[]]::new(1); $rng.GetBytes($b); $b[0] })
}

$results = foreach ($row in Import-Csv $CsvPath) {
    $ou = "OU=$($row.Department),OU=Staff,OU=Lab,$($domain.DistinguishedName)"
    $base = ($row.FirstName.Substring(0, 1) + $row.LastName).ToLower() -replace '[^a-z0-9]', ''
    $sam = $base; $n = 1
    while (Get-ADUser -Filter "SamAccountName -eq '$sam'" -ErrorAction SilentlyContinue) { $n++; $sam = "$base$n" }

    # The object name (CN) must also be unique within the OU: two people can share a full name.
    $cn = "$($row.FirstName) $($row.LastName)"
    if (Get-ADUser -Filter "Name -eq '$cn'" -SearchBase $ou -SearchScope OneLevel -ErrorAction SilentlyContinue) { $cn = "$cn ($sam)" }

    if ($PSCmdlet.ShouldProcess("$sam in $ou", 'Create user')) {
        $pw = New-TempPassword
        New-ADUser -Name $cn -GivenName $row.FirstName -Surname $row.LastName `
            -SamAccountName $sam -UserPrincipalName "$sam@$($domain.DNSRoot)" -DisplayName "$($row.FirstName) $($row.LastName)" `
            -Title $row.Title -Department $row.Department -Path $ou `
            -AccountPassword (ConvertTo-SecureString $pw -AsPlainText -Force) -ChangePasswordAtLogon $true -Enabled $true
        Add-ADGroupMember -Identity "GG-$($row.Department)" -Members $sam
        [pscustomobject]@{ SamAccountName = $sam; Name = "$($row.FirstName) $($row.LastName)"; Department = $row.Department; TempPassword = $pw }
    }
}
if ($results) {
    $results | Export-Csv $PasswordFile -NoTypeInformation
    Write-Output ("created {0} users; temporary passwords written to {1}" -f @($results).Count, $PasswordFile)
    $results | Select-Object SamAccountName, Name, Department | Format-Table -AutoSize | Out-String | Write-Output
}
