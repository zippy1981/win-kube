function Get-WinKubeCluster {
    <#
    .SYNOPSIS
    Gets the state of a win-kube cluster: minikube status, nodes, runtime classes and Helm releases.
    .DESCRIPTION
    Returns one object describing the cluster. Node entries include the AKS-style labels added by
    New-WinKubeCluster. If the cluster is not running, the Nodes, RuntimeClass and Release properties are empty.
    .PARAMETER ClusterProfile
    The minikube profile, which is also the kubectl context. Defaults to winkube.
    .EXAMPLE
    Get-WinKubeCluster

    Shows the winkube cluster.
    .EXAMPLE
    (Get-WinKubeCluster).Nodes | Format-Table -Property Name, OS, Ready, OsSku

    Lists the nodes and whether they are Ready.
    .OUTPUTS
    WinKube.Cluster
    .NOTES
    Output: An object with ClusterProfile, Status, Nodes, RuntimeClass and Release properties.
    #>
    [CmdletBinding()]
    [OutputType('WinKube.Cluster')]
    param(
        [ValidateNotNullOrEmpty()]
        [Alias('Profile')]
        [string]$ClusterProfile = $script:DefaultClusterProfile
    )

    # minikube status exits non-zero when anything is stopped, which is still a valid answer
    $statusJson = Invoke-WinKubeNative -FilePath (Get-WinKubeMinikubePath) -Capture -IgnoreExitCode -ArgumentList @(
        'status', '-p', $ClusterProfile, '-o', 'json'
    )
    $status = @()
    if ($statusJson) {
        $status = ConvertFrom-WinKubeJsonArray -Json $statusJson
    }

    $nodes = @()
    $runtimeClasses = @()
    $releases = @()
    $running = @($status | Where-Object -FilterScript {
            (Get-WinKubePropertyValue -InputObject $_ -Name 'APIServer') -eq 'Running'
        }).Count -gt 0
    if ($running) {
        $nodeList = Get-WinKubeKubectlJson -ClusterProfile $ClusterProfile -ArgumentList @('get', 'nodes')
        $nodes = @(foreach ($node in $nodeList.items) {
                $labels = $node.metadata.labels
                $ready = $node.status.conditions | Where-Object -FilterScript { $_.type -eq 'Ready' }
                [pscustomobject]@{
                    PSTypeName     = 'WinKube.ClusterNode'
                    Name           = $node.metadata.name
                    OS             = Get-WinKubePropertyValue -InputObject $labels -Name 'kubernetes.io/os'
                    Ready          = (@($ready)[0].status -eq 'True')
                    InternalIP     = ($node.status.addresses | Where-Object -FilterScript {
                            $_.type -eq 'InternalIP' } | Select-Object -First 1).address
                    KubeletVersion = $node.status.nodeInfo.kubeletVersion
                    AgentPool      = Get-WinKubePropertyValue -InputObject $labels -Name 'agentpool'
                    OsSku          = Get-WinKubePropertyValue -InputObject $labels -Name 'kubernetes.azure.com/os-sku'
                }
            })
        $classes = Get-WinKubeKubectlJson -ClusterProfile $ClusterProfile -ArgumentList @('get', 'runtimeclass')
        $runtimeClasses = @($classes.items | ForEach-Object -Process { $_.metadata.name })

        $helm = Get-Command -Name 'helm' -CommandType Application -ErrorAction SilentlyContinue
        $helmPath = Join-Path -Path $script:BinDir -ChildPath 'helm.exe'
        if ((Test-Path -LiteralPath $helmPath) -or $helm) {
            $helmOutput = Invoke-WinKubeNative -FilePath (Get-WinKubeToolPath -Name 'helm') -Capture -ArgumentList @(
                'list', '--all-namespaces', '--kube-context', $ClusterProfile, '-o', 'json'
            )
            $releases = ConvertFrom-WinKubeJsonArray -Json $helmOutput
        }
    }

    [pscustomobject]@{
        PSTypeName     = 'WinKube.Cluster'
        ClusterProfile = $ClusterProfile
        Running        = $running
        Status         = $status
        Nodes          = $nodes
        RuntimeClass   = $runtimeClasses
        Release        = $releases
    }
}
