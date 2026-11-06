function Install-WinKubeChart {
    <#
    .SYNOPSIS
    Installs or upgrades a Helm chart on the cluster's Windows node, side-loading its images first.
    .DESCRIPTION
    Imports the chart's images into the Windows node (see Import-WinKubeImage), then runs helm upgrade --install with
    --wait and the windows.version and windows.nodeVersion values, which charts in this repo use to pick image tags
    and Hyper-V isolation. An image family older than the node (ltsc2022 on the ltsc2025 node) needs
    Enable-WinKubeHyperVIsolation first.

    The default chart is the WordPress sample in charts/wordpress-windows, whose images default to
    windows-nano-php and mysql-spike. Its admin password is returned as a credential.
    .PARAMETER Chart
    Path to the chart. Defaults to charts/wordpress-windows.
    .PARAMETER Release
    The Helm release name.
    .PARAMETER Namespace
    The namespace to install into; created if missing.
    .PARAMETER WindowsVersion
    The image family to deploy: 2025 or 2022.
    .PARAMETER Set
    Extra helm --set values, such as 'wordpress.service.nodePort=30080'.
    .PARAMETER Image
    Images to side-load before installing. Defaults to the sample's images when -Chart is the sample chart.
    .PARAMETER SkipImageLoad
    Don't side-load images.
    .PARAMETER TimeoutMinutes
    helm --timeout, which also bounds post-install hooks. Windows image pulls and first starts are slow.
    .PARAMETER ClusterProfile
    The minikube profile, which is also the kubectl context. Defaults to winkube.
    .EXAMPLE
    Install-WinKubeChart

    Installs the WordPress sample with ltsc2025 images and returns its URL and admin credential.
    .EXAMPLE
    Install-WinKubeChart -WindowsVersion 2022 -Set 'install.title=Legacy'

    Installs the sample with ltsc2022 images under Hyper-V isolation, with a custom site title.
    .OUTPUTS
    WinKube.ChartRelease
    .NOTES
    Output: Release, Namespace, Chart, Url and, for the sample, Credential.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType('WinKube.ChartRelease')]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Chart = $script:DefaultChart,

        [ValidateNotNullOrEmpty()]
        [string]$Release = 'wp',

        [ValidateNotNullOrEmpty()]
        [string]$Namespace = 'wordpress',

        [ValidateSet('2025', '2022')]
        [string]$WindowsVersion = '2025',

        [Alias('HelmSet')]
        [string[]]$Set = @(),

        [Alias('Images')]
        [string[]]$Image = @(),

        [switch]$SkipImageLoad,

        [ValidateRange(1, 180)]
        [int]$TimeoutMinutes = 30,

        [ValidateNotNullOrEmpty()]
        [Alias('Profile')]
        [string]$ClusterProfile = $script:DefaultClusterProfile
    )

    $helm = Get-WinKubeToolPath -Name 'helm'
    $node = Get-WinKubeWindowsNode -ClusterProfile $ClusterProfile
    if (-not $node.Release) {
        throw "Unknown Windows build $($node.Build) on $($node.Name)."
    }
    if ($WindowsVersion -ne $node.Release) {
        $kubectl = Get-WinKubeToolPath -Name 'kubectl'
        $hasRuntimeClass = Test-WinKubeNative -FilePath $kubectl -ArgumentList @(
            '--context', $ClusterProfile, 'get', 'runtimeclass', $script:HyperVRuntimeClass
        )
        if (-not $hasRuntimeClass) {
            throw ("ltsc$WindowsVersion images need Hyper-V isolation on this ltsc$($node.Release) node. " +
                'Run Enable-WinKubeHyperVIsolation first.')
        }
    }

    $isSample = (Split-Path -Path $Chart -Leaf) -eq 'wordpress-windows'
    if (-not $SkipImageLoad) {
        $images = $Image
        if ($images.Count -eq 0 -and $isSample) {
            $images = @("windows-nano-php:$WindowsVersion", "mysql-spike:$WindowsVersion")
        }
        if ($images.Count -gt 0) {
            Import-WinKubeImage -Image $images -ClusterProfile $ClusterProfile | Out-Null
        }
    }

    $helmArgs = @(
        'upgrade', '--install', $Release, $Chart, '--kube-context', $ClusterProfile,
        '--namespace', $Namespace, '--create-namespace',
        '--set', "windows.version=$WindowsVersion", '--set', "windows.nodeVersion=$($node.Release)",
        '--wait', '--timeout', "$($TimeoutMinutes)m"
    )
    foreach ($value in $Set) {
        $helmArgs += @('--set', $value)
    }
    if (-not $PSCmdlet.ShouldProcess("$Namespace/$Release", "helm upgrade --install $Chart")) {
        return
    }
    Write-WinKubeStep -Message "helm upgrade --install $Release (Windows $WindowsVersion images)"
    Invoke-WinKubeNative -FilePath $helm -ArgumentList $helmArgs

    $urls = @()
    $services = Get-WinKubeKubectlJson -ClusterProfile $ClusterProfile -ArgumentList @(
        '-n', $Namespace, 'get', 'svc', '-l', "app.kubernetes.io/instance=$Release"
    )
    foreach ($service in $services.items) {
        if ($service.spec.type -ne 'NodePort') {
            continue
        }
        foreach ($port in $service.spec.ports) {
            $urls += "http://$($node.IP):$($port.nodePort)/"
        }
    }

    $credential = $null
    if ($isSample) {
        $secrets = Get-WinKubeKubectlJson -ClusterProfile $ClusterProfile -ArgumentList @(
            '-n', $Namespace, 'get', 'secret', '-l',
            "app.kubernetes.io/instance=$Release,app.kubernetes.io/name=wordpress-windows"
        )
        $secret = @($secrets.items) | Select-Object -First 1
        $encoded = Get-WinKubePropertyValue -InputObject (Get-WinKubePropertyValue -InputObject $secret -Name 'data') `
            -Name 'wordpress-admin-password'
        if ($encoded) {
            $plain = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
            $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList @(
                'admin', (ConvertTo-WinKubeSecureString -Value $plain)
            )
        }
    }

    [pscustomobject]@{
        PSTypeName = 'WinKube.ChartRelease'
        Release    = $Release
        Namespace  = $Namespace
        Chart      = $Chart
        Url        = $urls
        Credential = $credential
    }
}
