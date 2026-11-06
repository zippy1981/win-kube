function Invoke-WinKubeNative {
    <#
    .SYNOPSIS
    Runs a native command and throws when it exits with a non-zero code.
    .DESCRIPTION
    Every call to minikube, kubectl, helm, docker, ssh, scp, git and go goes through this function so tests can mock
    it. By default the command's output is written to the host, so long-running progress (minikube start) stays
    visible and never pollutes a cmdlet's output objects. With -Capture the output lines are returned instead.
    .PARAMETER FilePath
    The executable to run.
    .PARAMETER ArgumentList
    The arguments, one array element per argument.
    .PARAMETER Capture
    Return the standard output lines instead of writing them to the host.
    .PARAMETER IgnoreExitCode
    Do not throw when the command exits with a non-zero code.
    .EXAMPLE
    Invoke-WinKubeNative -FilePath 'kubectl' -ArgumentList @('version', '--client') -Capture
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [string[]]$ArgumentList = @(),

        [switch]$Capture,

        [switch]$IgnoreExitCode
    )

    Write-Verbose -Message "$FilePath $($ArgumentList -join ' ')"
    if ($Capture) {
        $output = & $FilePath @ArgumentList
    } else {
        & $FilePath @ArgumentList | Out-Host
        $output = $null
    }
    if (-not $IgnoreExitCode -and $LASTEXITCODE -ne 0) {
        throw "'$FilePath $($ArgumentList -join ' ')' failed with exit code $LASTEXITCODE"
    }
    $output
}

function Test-WinKubeNative {
    <#
    .SYNOPSIS
    Runs a native command for its exit code only.
    .DESCRIPTION
    Windows PowerShell 5.1 turns redirected native stderr into terminating errors under
    ErrorActionPreference = 'Stop', so this relaxes the preference for the one call and discards all output.
    .PARAMETER FilePath
    The executable to run.
    .PARAMETER ArgumentList
    The arguments, one array element per argument.
    .EXAMPLE
    Test-WinKubeNative -FilePath 'kubectl' -ArgumentList @('get', 'runtimeclass', 'windows-hyperv')
    .OUTPUTS
    System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [string[]]$ArgumentList = @()
    )

    $saved = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $FilePath @ArgumentList 2>&1 | Out-Null
        $LASTEXITCODE -eq 0
    } finally {
        $ErrorActionPreference = $saved
    }
}

function Write-WinKubeStep {
    <#
    .SYNOPSIS
    Writes a progress step to the information stream.
    .DESCRIPTION
    Steps are shown when the caller passes -InformationAction Continue (winkube.ps1 always does).
    .PARAMETER Message
    The step to report.
    .EXAMPLE
    Write-WinKubeStep -Message 'Starting cluster'
    .OUTPUTS
    None
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Information -MessageData "==> $Message" -Tags 'WinKube'
}
