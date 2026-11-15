<#
.SYNOPSIS
  Give the server a static address and promote it to the first domain controller of a new forest.
.DESCRIPTION
  Run once on a fresh Windows Server 2025 install. Sets a static IPv4 address, points DNS at
  itself, installs AD DS + DNS, and creates the forest. The server reboots when promotion finishes.
  The DNS server forwards everything that is not the lab domain to the existing LAN resolver.
.EXAMPLE
  .\01-Promote-DomainController.ps1 -IPAddress 192.168.1.252 -PrefixLength 24 -Gateway 192.168.1.1 `
      -Forwarder 192.168.1.53 -DomainName lab.internal -NetbiosName LAB -SafeModePassword (Read-Host -AsSecureString)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $IPAddress,
    [int] $PrefixLength = 24,
    [Parameter(Mandatory)] [string] $Gateway,
    [Parameter(Mandatory)] [string] $Forwarder,
    [string] $DomainName = 'lab.internal',
    [string] $NetbiosName = 'LAB',
    [Parameter(Mandatory)] [securestring] $SafeModePassword
)
$ErrorActionPreference = 'Stop'

# 1. Static address on the first connected adapter
$nic = Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1
if (-not (Get-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $IPAddress -ErrorAction SilentlyContinue)) {
    Set-NetIPInterface -InterfaceIndex $nic.ifIndex -Dhcp Disabled
    Get-NetIPAddress -InterfaceIndex $nic.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Remove-NetIPAddress -Confirm:$false
    Get-NetRoute -InterfaceIndex $nic.ifIndex -DestinationPrefix '0.0.0.0/0' -ErrorAction SilentlyContinue |
        Remove-NetRoute -Confirm:$false
    New-NetIPAddress -InterfaceIndex $nic.ifIndex -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $Gateway | Out-Null
}
# Until DNS runs locally, resolve through the LAN resolver; promotion repoints it to 127.0.0.1.
Set-DnsClientServerAddress -InterfaceIndex $nic.ifIndex -ServerAddresses $Forwarder

# 2. Roles
Install-WindowsFeature AD-Domain-Services, DNS -IncludeManagementTools | Out-Null

# 3. New forest (reboots automatically)
Import-Module ADDSDeployment
Install-ADDSForest -DomainName $DomainName -DomainNetbiosName $NetbiosName `
    -InstallDns -SafeModeAdministratorPassword $SafeModePassword `
    -ForestMode WinThreshold -DomainMode WinThreshold `
    -NoRebootOnCompletion:$false -Force
