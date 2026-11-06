function Test-WinKubeHyperVAccess {
    <#
    .SYNOPSIS
    Tests whether the current token may manage Hyper-V.
    .DESCRIPTION
    True for members of Hyper-V Administrators (S-1-5-32-578), which minikube's hyperv driver accepts in place of an
    elevated token (ADR 0004), and for elevated administrators.
    .EXAMPLE
    Test-WinKubeHyperVAccess
    .OUTPUTS
    System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
    $hyperVAdmins = New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList 'S-1-5-32-578'
    $principal.IsInRole($hyperVAdmins) -or $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-WinKubeHyperV {
    <#
    .SYNOPSIS
    Throws unless Hyper-V is installed, running, reachable without elevation, and has the Default Switch.
    .EXAMPLE
    Assert-WinKubeHyperV
    .OUTPUTS
    None
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $vmms = Get-Service -Name 'vmms' -ErrorAction SilentlyContinue
    if (-not $vmms) {
        throw 'Hyper-V is not installed. Run Install-WinKubePrerequisite (then reboot).'
    }
    if (-not (Test-WinKubeHyperVAccess)) {
        throw ("You are not in 'Hyper-V Administrators'. Run Install-WinKubePrerequisite, " +
            'then sign out and back in.')
    }
    if ($vmms.Status -ne 'Running') {
        throw 'The Hyper-V Virtual Machine Management service (vmms) is not running.'
    }
    Import-Module -Name 'Hyper-V' -ErrorAction Stop
    if (-not (Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue)) {
        throw ("Hyper-V 'Default Switch' not found. It is created automatically on Windows 10 1709+; " +
            'reboot after enabling Hyper-V.')
    }
}

function Get-WinKubeFreeMemoryMB {
    <#
    .SYNOPSIS
    Returns the free physical memory in MB.
    .EXAMPLE
    Get-WinKubeFreeMemoryMB
    .OUTPUTS
    System.Int32
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    [int]((Get-CimInstance -ClassName Win32_OperatingSystem).FreePhysicalMemory / 1024)
}
