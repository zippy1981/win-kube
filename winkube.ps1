#Requires -Version 5.1

<#
.SYNOPSIS
win-kube command-line shim over the WinKube module.

.DESCRIPTION
Keeps the original `.\winkube.ps1 <command>` interface. Each command imports src/WinKube and calls one cmdlet,
passing on the parameters that cmdlet accepts and showing progress (-InformationAction Continue).

    prereqs                  Install-WinKubePrerequisite (the only elevated step)
    tools                    Install-WinKubeTool
    up                       New-WinKubeCluster
    enable-hyperv-isolation  Enable-WinKubeHyperVIsolation
    load-images              Import-WinKubeImage
    deploy                   Install-WinKubeChart
    status                   Get-WinKubeCluster
    ssh-windows              Enter-WinKubeWindowsNode
    down                     Remove-WinKubeCluster (without prompting)

Use the cmdlets directly for scripting: Import-Module ./src/WinKube; Get-Help New-WinKubeCluster -Full.

.PARAMETER Command
The command to run. Defaults to help.

.PARAMETER ClusterProfile
The minikube profile, which is also the kubectl context.

.PARAMETER KubernetesVersion
The control-plane (up) or kubectl (tools) version.

.PARAMETER Cpus
Virtual CPUs for each node VM (up).

.PARAMETER MemoryMB
Memory for each node VM in MB (up).

.PARAMETER Isolation
process or hyperv (up).

.PARAMETER WindowsVhdUrl
A custom Windows node VHDX (up).

.PARAMETER WindowsVersion
The image family: 2025 or 2022 (load-images, deploy).

.PARAMETER Namespace
The namespace to deploy into (deploy).

.PARAMETER Release
The Helm release name (deploy).

.PARAMETER Images
Images to side-load (load-images, deploy).

.PARAMETER HelmSet
Extra helm --set values (deploy).

.PARAMETER SkipImageLoad
Don't side-load images before deploying (deploy).

.PARAMETER Force
Re-download tools (tools) or re-import images (load-images).

.EXAMPLE
.\winkube.ps1 prereqs; .\winkube.ps1 tools; .\winkube.ps1 up; .\winkube.ps1 deploy

.EXAMPLE
.\winkube.ps1 up -Isolation hyperv; .\winkube.ps1 deploy -WindowsVersion 2022
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('help', 'prereqs', 'tools', 'up', 'enable-hyperv-isolation', 'load-images',
        'deploy', 'status', 'ssh-windows', 'down')]
    [string]$Command = 'help',

    [Alias('Profile')]
    [string]$ClusterProfile,

    [string]$KubernetesVersion,

    [int]$Cpus,

    [int]$MemoryMB,

    [ValidateSet('process', 'hyperv')]
    [string]$Isolation,

    [string]$WindowsVhdUrl,

    [ValidateSet('2025', '2022')]
    [string]$WindowsVersion,

    [string]$Namespace,

    [string]$Release,

    [string[]]$Images,

    [string[]]$HelmSet,

    [switch]$SkipImageLoad,

    [switch]$Force
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$commands = @{
    'prereqs'                 = 'Install-WinKubePrerequisite'
    'tools'                   = 'Install-WinKubeTool'
    'up'                      = 'New-WinKubeCluster'
    'enable-hyperv-isolation' = 'Enable-WinKubeHyperVIsolation'
    'load-images'             = 'Import-WinKubeImage'
    'deploy'                  = 'Install-WinKubeChart'
    'status'                  = 'Get-WinKubeCluster'
    'ssh-windows'             = 'Enter-WinKubeWindowsNode'
    'down'                    = 'Remove-WinKubeCluster'
}
if ($Command -eq 'help') {
    Get-Help -Name $PSCommandPath -Detailed
    return
}

Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'src/WinKube/WinKube.psd1') -Force
$cmdlet = Get-Command -Name $commands[$Command] -Module 'WinKube'

# Pass on each bound shim parameter the cmdlet accepts under its name or one of its aliases
$accepted = @{}
foreach ($parameter in $cmdlet.Parameters.Values) {
    $accepted[$parameter.Name] = $true
    foreach ($alias in $parameter.Aliases) {
        $accepted[$alias] = $true
    }
}
$arguments = @{ InformationAction = 'Continue' }
foreach ($name in $PSBoundParameters.Keys) {
    if ($name -ne 'Command' -and $accepted.ContainsKey($name)) {
        $arguments[$name] = $PSBoundParameters[$name]
    }
}
if ($Command -eq 'down') {
    $arguments['Confirm'] = $false
}

$result = & $cmdlet @arguments
if ($Command -eq 'deploy' -and $result) {
    foreach ($url in $result.Url) {
        Write-Information -MessageData "WordPress: $url" -InformationAction Continue
    }
    if ($result.Credential) {
        $password = $result.Credential.GetNetworkCredential().Password
        $admin = "Admin:     $($result.Credential.UserName) / $password"
        Write-Information -MessageData $admin -InformationAction Continue
    }
} elseif ($Command -eq 'status' -and $result) {
    $result.Nodes | Format-Table -AutoSize | Out-Host
    $result | Select-Object -Property ClusterProfile, Running, RuntimeClass | Format-List | Out-Host
    if ($result.Release) {
        $result.Release | Format-Table -Property name, namespace, status, chart -AutoSize | Out-Host
    }
} elseif ($result) {
    $result
}
