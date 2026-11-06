# WinKube: a minikube-based, AKS-shaped local cluster with a Windows Server node.
# Loads the private helpers, then the public cmdlets (one function per file), and exports only the public ones.
Set-StrictMode -Version 2.0

# Experimental Windows-node support lives on a fork branch until upstream merges it (ADR 0003). Bump these together
# after validating a new commit with the minikube-fork-tracker agent.
$script:MinikubeRepo = 'https://github.com/bobsira/minikube.git'
$script:MinikubeRef = '8f57f5ea0e777c5d4ad81824235832562fd6fdb2' # feature/windows-node-support, 2026-11-03

# Must not be older than the kubelet baked into the fork's Windows VHD (v1.37.0 in the default image).
$script:DefaultKubernetesVersion = 'v1.37.0'
$script:DefaultClusterProfile = 'winkube'

$script:RepoRoot = Split-Path -Path (Split-Path -Path $PSScriptRoot -Parent) -Parent
$script:ToolsDir = Join-Path -Path $script:RepoRoot -ChildPath '.tools'
$script:BinDir = Join-Path -Path $script:ToolsDir -ChildPath 'bin'
$script:CacheDir = Join-Path -Path $script:RepoRoot -ChildPath '.cache'
$script:DefaultChart = Join-Path -Path $script:RepoRoot -ChildPath 'charts/wordpress-windows'
$script:PrerequisiteScript = Join-Path -Path $script:RepoRoot -ChildPath 'scripts/Install-WinKubePrereqs.ps1'

$script:HyperVRuntimeClass = 'windows-hyperv'
$script:HyperVRuntimeHandler = 'runhcs-wcow-hypervisor'
$script:RemoteDir = 'C:\Windows\Temp\winkube'
$script:WindowsBuilds = @{
    '10.0.17763' = '2019'
    '10.0.20348' = '2022'
    '10.0.26100' = '2025'
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor
[Net.SecurityProtocolType]::Tls12

foreach ($folder in @('Private', 'Public')) {
    $path = Join-Path -Path $PSScriptRoot -ChildPath $folder
    foreach ($file in (Get-ChildItem -Path $path -Filter '*.ps1' | Sort-Object -Property Name)) {
        . $file.FullName
    }
}

$public = Get-ChildItem -Path (Join-Path -Path $PSScriptRoot -ChildPath 'Public') -Filter '*.ps1' |
    ForEach-Object -Process { $_.BaseName }
Export-ModuleMember -Function $public
