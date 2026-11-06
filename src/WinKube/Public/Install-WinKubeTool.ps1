function Install-WinKubeTool {
    <#
    .SYNOPSIS
    Installs kubectl, helm and the Windows-node minikube build into .tools/bin.
    .DESCRIPTION
    Downloads kubectl for -KubernetesVersion and the latest helm, then builds minikube from the pinned fork commit
    (ADR 0003), downloading a portable Go toolchain if none new enough is on PATH. Needs git. Tools already present
    are kept unless -Force is given. Runs without elevation.
    .PARAMETER KubernetesVersion
    The kubectl version to download. Defaults to the cluster's default Kubernetes version.
    .PARAMETER Force
    Download and rebuild everything, even tools that are already present.
    .EXAMPLE
    Install-WinKubeTool

    Installs whatever is missing.
    .EXAMPLE
    Install-WinKubeTool -Force

    Reinstalls kubectl and helm and rebuilds minikube.
    .OUTPUTS
    WinKube.Tool
    .NOTES
    Output: One object per tool with Name and Path.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('WinKube.Tool')]
    param(
        [ValidatePattern('^v\d+\.\d+\.\d+$')]
        [string]$KubernetesVersion = $script:DefaultKubernetesVersion,

        [switch]$Force
    )

    if (-not $PSCmdlet.ShouldProcess($script:BinDir, 'Install kubectl, helm and minikube')) {
        return
    }
    New-Item -ItemType Directory -Force -Path $script:BinDir, $script:CacheDir | Out-Null
    $tools = [ordered]@{
        kubectl  = Install-WinKubeKubectl -KubernetesVersion $KubernetesVersion -Force:$Force
        helm     = Install-WinKubeHelm -Force:$Force
        minikube = Install-WinKubeMinikube -Force:$Force
    }
    foreach ($name in $tools.Keys) {
        [pscustomobject]@{
            PSTypeName = 'WinKube.Tool'
            Name       = $name
            Path       = $tools[$name]
        }
    }
}
