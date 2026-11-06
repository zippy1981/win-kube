function Invoke-WinKubeWindowsNode {
    <#
    .SYNOPSIS
    Runs a PowerShell script block on the Windows node over SSH.
    .DESCRIPTION
    The node's SSH default shell is cmd.exe, so the script block is copied to the node as a .ps1 file and run with
    Windows PowerShell there, with ErrorActionPreference set to Stop. The file is removed afterwards. Values are
    passed with -ArgumentList and bound to the script block's param() block in order. Output lines are returned.
    .PARAMETER ScriptBlock
    The script to run on the node. Variables from the calling session are not available; pass them as arguments.
    .PARAMETER ArgumentList
    Values for the script block's parameters, in order. They may not contain double quotes or the cmd.exe
    metacharacters & | < > ^ %.
    .PARAMETER Node
    The node to run on, from Get-WinKubeWindowsNode. Accepts pipeline input.
    .PARAMETER ClusterProfile
    Looks the Windows node up in this cluster when -Node is not given. Defaults to winkube.
    .EXAMPLE
    Invoke-WinKubeWindowsNode -ScriptBlock { Get-Service -Name containerd, kubelet }

    Shows the state of the container runtime and kubelet on the Windows node.
    .EXAMPLE
    Get-WinKubeWindowsNode | Invoke-WinKubeWindowsNode -ArgumentList 'C:\k' -ScriptBlock {
        param($Path)
        Get-ChildItem -Path $Path
    }

    Lists the kubelet folder on the node.
    .OUTPUTS
    System.String
    #>
    [CmdletBinding(DefaultParameterSetName = 'ByProfile')]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [scriptblock]$ScriptBlock,

        [string[]]$ArgumentList = @(),

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'ByNode')]
        [PSTypeName('WinKube.WindowsNode')]
        [psobject]$Node,

        [Parameter(ParameterSetName = 'ByProfile')]
        [ValidateNotNullOrEmpty()]
        [Alias('Profile')]
        [string]$ClusterProfile = $script:DefaultClusterProfile
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'ByProfile') {
            $Node = Get-WinKubeWindowsNode -ClusterProfile $ClusterProfile
        }
        # The command line passes through cmd.exe on the node, and Windows PowerShell 5.1 does not escape embedded
        # double quotes in native arguments, so keep both quote-free and free of cmd metacharacters.
        foreach ($argument in $ArgumentList) {
            if ($argument -match '["&|<>^%]') {
                throw "Arguments for the Windows node may not contain any of `" & | < > ^ %: $argument"
            }
        }

        New-Item -ItemType Directory -Force -Path $script:CacheDir | Out-Null
        $name = 'remote-{0}.ps1' -f [guid]::NewGuid().ToString('N')
        $local = Join-Path -Path $script:CacheDir -ChildPath $name
        $remote = "$script:RemoteDir\$name"
        Set-Content -LiteralPath $local -Value $ScriptBlock.ToString() -Encoding UTF8

        $quoted = @($ArgumentList | ForEach-Object -Process { "'" + ($_ -replace "'", "''") + "'" }) -join ' '
        # Dot-source rather than use the call operator: & is a command separator for cmd.exe
        $command = "`$ErrorActionPreference = 'Stop'; try { . '$remote' $quoted } finally { " +
        "Remove-Item -LiteralPath '$remote' -ErrorAction SilentlyContinue }"
        $sshArgs = Get-WinKubeSshArgument -Node $Node
        $target = "Administrator@$($Node.IP)"
        try {
            Invoke-WinKubeNative -FilePath 'ssh.exe' -ArgumentList ($sshArgs + @(
                    $target, "if not exist $script:RemoteDir mkdir $script:RemoteDir"
                )) | Out-Null
            Copy-WinKubeFileToWindowsNode -Node $Node -Path $local -Destination $remote
            Invoke-WinKubeNative -FilePath 'ssh.exe' -Capture -ArgumentList ($sshArgs + @(
                    $target, "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command $command"
                ))
        } finally {
            Remove-Item -LiteralPath $local -ErrorAction SilentlyContinue
        }
    }
}
