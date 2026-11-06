function Get-WinKubeWindowsNode {
    <#
    .SYNOPSIS
    Gets the cluster's Windows Server node.
    .DESCRIPTION
    Reads the node labelled kubernetes.io/os=windows from Kubernetes and matches its InternalIP to a minikube machine,
    whose name is needed for SSH keys and the Hyper-V VM. The Windows Server release is derived from the
    node.kubernetes.io/windows-build label (10.0.26100 is 2025, 10.0.20348 is 2022, 10.0.17763 is 2019).
    .PARAMETER ClusterProfile
    The minikube profile, which is also the kubectl context. Defaults to winkube.
    .EXAMPLE
    Get-WinKubeWindowsNode

    Returns the Windows node of the winkube cluster.
    .EXAMPLE
    Get-WinKubeWindowsNode -ClusterProfile 'demo' | Invoke-WinKubeWindowsNode -ScriptBlock { Get-Service containerd }

    Runs a command on the Windows node of the demo cluster.
    .OUTPUTS
    WinKube.WindowsNode
    .NOTES
    Output: An object with Name, IP, Build, Release, Machine and ClusterProfile properties.
    #>
    [CmdletBinding()]
    [OutputType('WinKube.WindowsNode')]
    param(
        [ValidateNotNullOrEmpty()]
        [Alias('Profile')]
        [string]$ClusterProfile = $script:DefaultClusterProfile
    )

    $nodes = Get-WinKubeKubectlJson -ClusterProfile $ClusterProfile -ArgumentList @(
        'get', 'nodes', '-l', 'kubernetes.io/os=windows'
    )
    $items = @($nodes.items)
    if ($items.Count -eq 0) {
        throw "No Windows node found in cluster '$ClusterProfile'."
    }
    $node = $items[0]
    $ip = ($node.status.addresses | Where-Object -FilterScript { $_.type -eq 'InternalIP' } |
            Select-Object -First 1).address
    $build = "$(Get-WinKubePropertyValue -InputObject $node.metadata.labels -Name 'node.kubernetes.io/windows-build')"
    $release = $null
    if ($build -and $script:WindowsBuilds.ContainsKey($build)) {
        $release = $script:WindowsBuilds[$build]
    }

    $machine = $null
    $list = Invoke-WinKubeNative -FilePath (Get-WinKubeMinikubePath) -ArgumentList @(
        'node', 'list', '-p', $ClusterProfile
    ) -Capture
    foreach ($line in @($list)) {
        $parts = "$line" -split '\s+'
        if ($parts.Count -ge 2 -and $parts[1] -eq $ip) {
            $machine = $parts[0]
        }
    }
    if (-not $machine) {
        throw "Could not match Windows node $($node.metadata.name) ($ip) to a minikube machine."
    }

    [pscustomobject]@{
        PSTypeName     = 'WinKube.WindowsNode'
        Name           = $node.metadata.name
        IP             = $ip
        Build          = $build
        Release        = $release
        Machine        = $machine
        ClusterProfile = $ClusterProfile
    }
}
