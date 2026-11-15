# Windows Server and Active Directory lab

A Windows Server 2025 domain controller built on my Proxmox cluster without clicking through an installer, plus PowerShell for the user lifecycle work a sysadmin does every week: onboarding, offboarding and account hygiene. Everything here was run against the live lab domain; the outputs below come from those runs.

## How it is built

1. **Unattended install.** [`autounattend.xml`](autounattend.xml) goes on a small ISO next to the Windows Server ISO. Setup loads the VirtIO SCSI and network drivers from the virtio-win ISO, partitions the disk, installs the Desktop Experience edition, and at first logon installs the VirtIO guest tools, including the QEMU guest agent. The admin password is generated on the hypervisor into a root-only file and substituted when the answer ISO is built, so it never appears in this repo.
2. **No console clicking.** With the guest agent running, every later step is PowerShell sent from the Proxmox host (`qm guest exec`). Install to working domain controller took about 25 minutes, all hands-off.
3. **Promotion.** [`01-Promote-DomainController.ps1`](scripts/01-Promote-DomainController.ps1) sets a static address, installs AD DS and DNS, and creates the `lab.internal` forest. DNS forwards everything else to the existing LAN resolver. The DC runs no DHCP, so it cannot interfere with the rest of the network.
4. **Directory build.** [`02-Build-Directory.ps1`](scripts/02-Build-Directory.ps1) is idempotent; a second run changes nothing.

```text
OU=Lab
  OU=Staff\IT, Finance, Sales, Operations, HR    users, one OU per department
  OU=Groups                                      GG-<Department>, GG-Lab-Admins
  OU=Admins                                      separate admin accounts
  OU=Service Accounts
  OU=Workstations                                default location for new computers (redircmp)
  OU=Disabled Users                              where offboarded accounts are parked
```

| Policy | Setting |
|---|---|
| Default domain password policy | 14 characters minimum, history 24, lockout after 10 attempts for 15 minutes |
| Fine-grained policy `PSO-Admins` (applies to GG-Lab-Admins) | 20 characters minimum, lockout after 5 attempts for 30 minutes |
| GPO `Staff - Screen Lock` (linked to Workstations) | lock idle sessions after 15 minutes |
| GPO `Workstations - Hardening` (linked to Workstations) | NTLMv2 only, no LM hashes, SMB client signing required |

## User lifecycle scripts

| Script | What it does |
|---|---|
| [`New-BulkUsers.ps1`](scripts/New-BulkUsers.ps1) | Onboarding from a CSV. It builds unique usernames and display names, puts each user in the right department OU and group, sets a random temporary password, and forces a change at first logon. It supports `-WhatIf`. Passwords go only to a file you name, never to the screen. |
| [`Invoke-UserOffboarding.ps1`](scripts/Invoke-UserOffboarding.ps1) | Saves the user's group memberships to a timestamped CSV first, then scrambles the password, disables the account, removes the groups, stamps the description with date and ticket, and moves the account to Disabled Users. Nothing is deleted, so a mistake can be undone. |
| [`Get-AccountHygieneReport.ps1`](scripts/Get-AccountHygieneReport.ps1) | Read-only report of stale accounts, accounts that never logged on, passwords about to expire (fine-grained policies included), and non-expiring passwords. |

### Real runs

```text
PS> .\New-BulkUsers.ps1 -CsvPath .\sample-users.csv -PasswordFile C:\lab\secure\onboarding.csv
created 10 users; temporary passwords written to C:\lab\secure\onboarding.csv
SamAccountName Name          Department
acollins       Avery Collins IT
jprice         Jordan Price  IT
...
acole          Avery Cole    HR

# Same name again: unique username and object name, no failure
PS> .\New-BulkUsers.ps1 -CsvPath .\collision.csv -PasswordFile C:\lab\secure\onboarding2.csv
SamAccountName Name
acollins2      Avery Collins (acollins2)

PS> .\Invoke-UserOffboarding.ps1 -SamAccountName jellis -Ticket LAB-0002 -AuditFolder C:\lab\offboarding
offboarded jellis: disabled, 1 group(s) removed and saved, moved to Disabled Users
Enabled           : False
DistinguishedName : CN=Jamie Ellis,OU=Disabled Users,OU=Lab,DC=lab,DC=internal
Description       : Offboarded 2026-11-14 by DC01$ (LAB-0002)

PS> .\Get-AccountHygieneReport.ps1 -StaleDays 90
10 enabled accounts checked, 1 need attention
SamAccountName LastLogon PasswordExpires Issues
Administrator                            password never expires
```

## Bugs found by testing against the real domain

- **The directory script failed with "object name has bad syntax".** A helper function printed a status line with `Write-Output`, and PowerShell returned it along with the OU path. Fixed by printing with `Write-Host`, so the function's only output is the DN.
- **Offboarding failed halfway on Windows PowerShell 5.1.** `[RandomNumberGenerator]::Fill()` only exists in .NET Core / PowerShell 7. By then the account was already disabled and its groups removed, and a re-run would have overwritten the saved group list with an empty one. Fixed three ways:
  - a random generator that works on both PowerShell versions
  - the password reset moved before the irreversible steps
  - audit files timestamped so they are never overwritten
- **Two people with the same name.** The username was already made unique, but the object name ("Avery Collins") also has to be unique within an OU. The script now appends the username on a clash.

## Health

`dcdiag /q` on the new DC reports two expected first-day warnings: a DFSR event from the initial SYSVOL share, and unrelated system log noise from first boot. Nothing else.

## Files

```text
autounattend.xml                      answer file (password placeholder)
scripts/01-Promote-DomainController.ps1
scripts/02-Build-Directory.ps1
scripts/New-BulkUsers.ps1
scripts/Invoke-UserOffboarding.ps1
scripts/Get-AccountHygieneReport.ps1
scripts/sample-users.csv              fictional names
```
