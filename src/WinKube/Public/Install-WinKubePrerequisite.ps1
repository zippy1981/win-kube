function Install-WinKubePrerequisite {
    <#
    .SYNOPSIS
    Runs the one-time, elevated prerequisites setup (UAC prompt).
    .DESCRIPTION
    Starts scripts/Install-WinKubePrereqs.ps1 under Windows PowerShell 5.1, which self-elevates and then enables
    Hyper-V and Containers, installs the OSS dockerd into C:\docker, enables long paths, and adds the user to
    Hyper-V Administrators and docker-users. It is the only part of win-kube that elevates (ADR 0004). Reboot if it
    asks, then sign out and back in so the group memberships apply.
    .PARAMETER Restart
    Reboot automatically if enabling a Windows feature requires it.
    .EXAMPLE
    Install-WinKubePrerequisite

    Runs the setup and reports whether a reboot or sign-out is needed.
    .OUTPUTS
    None
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([void])]
    param(
        [switch]$Restart
    )

    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script:PrerequisiteScript)
    if ($Restart) {
        $arguments += '-Restart'
    }
    $action = 'Enable Hyper-V and Containers, install dockerd, add group members'
    if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, $action)) {
        Invoke-WinKubeNative -FilePath 'powershell.exe' -ArgumentList $arguments
    }
}
