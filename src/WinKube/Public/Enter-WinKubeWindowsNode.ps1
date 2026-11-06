function Enter-WinKubeWindowsNode {
    <#
    .SYNOPSIS
    Opens an interactive SSH session to the Windows node.
    .DESCRIPTION
    Connects as Administrator with minikube's key for the node. The node's default shell is cmd.exe; type
    powershell to switch. Use Invoke-WinKubeWindowsNode for scripted commands.
    .PARAMETER ClusterProfile
    The minikube profile. Defaults to winkube.
    .EXAMPLE
    Enter-WinKubeWindowsNode

    Opens a shell on the winkube cluster's Windows node.
    .OUTPUTS
    None
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [ValidateNotNullOrEmpty()]
        [Alias('Profile')]
        [string]$ClusterProfile = $script:DefaultClusterProfile
    )

    $node = Get-WinKubeWindowsNode -ClusterProfile $ClusterProfile
    $sshArgs = (Get-WinKubeSshArgument -Node $node -Interactive) + @("Administrator@$($node.IP)")
    & ssh.exe @sshArgs
}
