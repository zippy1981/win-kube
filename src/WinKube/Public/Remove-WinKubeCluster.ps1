function Remove-WinKubeCluster {
    <#
    .SYNOPSIS
    Deletes a win-kube cluster and its VMs.
    .DESCRIPTION
    Runs minikube delete for the profile. The cached Windows VHDX and other profiles are kept. Because restarting the
    Windows node isn't supported by the minikube build, deleting and recreating is the way to reset a cluster.
    .PARAMETER ClusterProfile
    The minikube profile to delete. Defaults to winkube.
    .EXAMPLE
    Remove-WinKubeCluster

    Deletes the winkube cluster after asking for confirmation.
    .EXAMPLE
    Remove-WinKubeCluster -ClusterProfile 'demo' -Confirm:$false

    Deletes the demo cluster without prompting.
    .OUTPUTS
    None
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    [OutputType([void])]
    param(
        [ValidateNotNullOrEmpty()]
        [Alias('Profile')]
        [string]$ClusterProfile = $script:DefaultClusterProfile
    )

    if ($PSCmdlet.ShouldProcess($ClusterProfile, 'Delete minikube cluster')) {
        Write-WinKubeStep -Message "Deleting cluster '$ClusterProfile'"
        Invoke-WinKubeNative -FilePath (Get-WinKubeMinikubePath) -ArgumentList @('delete', '-p', $ClusterProfile)
    }
}
