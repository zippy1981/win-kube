function New-WinKubeCluster {
    <#
    .SYNOPSIS
    Creates a win-kube cluster: a Linux control plane and a Windows Server 2025 worker on Hyper-V.
    .DESCRIPTION
    Runs the Windows-node minikube build with --driver=hyperv, one control-plane node and one Windows worker, waits
    for both nodes to be Ready, and labels them the way AKS does (agentpool, kubernetes.azure.com/mode and os-sku).
    With -Isolation hyperv the VMs get static memory and the Windows node is set up for Hyper-V isolated containers,
    so ltsc2022 images can run on it (ADR 0005).

    Runs without elevation for members of Hyper-V Administrators (ADR 0004). The first run downloads the Windows
    VHDX; allow 20 minutes or more.
    .PARAMETER ClusterProfile
    The minikube profile, which is also the kubectl context. Defaults to winkube.
    .PARAMETER KubernetesVersion
    The control-plane version. Must not be older than the kubelet in the Windows VHD (v1.37.0 by default).
    .PARAMETER CpuCount
    Virtual CPUs for each node VM. Nested virtualization, needed for Hyper-V isolation, requires at least 2.
    .PARAMETER MemoryMB
    Memory for each node VM, in MB.
    .PARAMETER Isolation
    'process' (default) runs only images that match the node build. 'hyperv' also enables Hyper-V isolation.
    .PARAMETER WindowsVhdUrl
    A custom Windows node VHDX: a URL, an absolute path, or a file:// URI.
    .EXAMPLE
    New-WinKubeCluster

    Creates the default winkube cluster with process isolation.
    .EXAMPLE
    New-WinKubeCluster -Isolation hyperv -MemoryMB 8192 -InformationAction Continue

    Creates a cluster that can also run ltsc2022 images, with 8 GB per node, showing progress.
    .OUTPUTS
    WinKube.Cluster
    .NOTES
    Output: The state of the new cluster, as returned by Get-WinKubeCluster.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('WinKube.Cluster')]
    param(
        [ValidateNotNullOrEmpty()]
        [Alias('Profile')]
        [string]$ClusterProfile = $script:DefaultClusterProfile,

        [ValidatePattern('^v\d+\.\d+\.\d+$')]
        [string]$KubernetesVersion = $script:DefaultKubernetesVersion,

        [ValidateRange(2, 64)]
        [Alias('Cpus')]
        [int]$CpuCount = 4,

        [ValidateRange(2048, 131072)]
        [int]$MemoryMB = 6144,

        [ValidateSet('process', 'hyperv')]
        [string]$Isolation = 'process',

        [string]$WindowsVhdUrl
    )

    Assert-WinKubeHyperV
    $minikube = Get-WinKubeMinikubePath
    Get-WinKubeToolPath -Name 'kubectl' | Out-Null

    $freeMB = Get-WinKubeFreeMemoryMB
    if ($freeMB -lt (2 * $MemoryMB)) {
        Write-Warning -Message "Only $freeMB MB free; two nodes need $(2 * $MemoryMB) MB. Use -MemoryMB to lower it."
    }

    $startArgs = @(
        'start', '-p', $ClusterProfile, '--driver=hyperv',
        '--node', 'role=control-plane', '--node', 'role=worker,os=windows',
        "--kubernetes-version=$KubernetesVersion", "--cpus=$CpuCount", "--memory=$MemoryMB"
    )
    if ($WindowsVhdUrl) {
        $startArgs += "--windows-vhd-url=$WindowsVhdUrl"
    }
    # Nested virtualization (needed by Hyper-V isolated containers) is unreliable with dynamic memory
    if ($Isolation -eq 'hyperv') {
        $startArgs += '--hyperv-disable-dynamic-memory'
    }

    if (-not $PSCmdlet.ShouldProcess($ClusterProfile, 'Create minikube cluster with a Windows node')) {
        return
    }
    Write-WinKubeStep -Message "Starting cluster '$ClusterProfile' (the first run downloads the Windows VHDX)"
    Invoke-WinKubeNative -FilePath $minikube -ArgumentList $startArgs

    Write-WinKubeStep -Message 'Waiting for all nodes to be Ready'
    Invoke-WinKubeKubectl -ClusterProfile $ClusterProfile -ArgumentList @(
        'wait', '--for=condition=Ready', 'nodes', '--all', '--timeout=20m'
    )
    Add-WinKubeAksNodeLabel -ClusterProfile $ClusterProfile

    if ($Isolation -eq 'hyperv') {
        Enable-WinKubeHyperVIsolation -ClusterProfile $ClusterProfile -Confirm:$false
    }
    Get-WinKubeCluster -ClusterProfile $ClusterProfile
}
