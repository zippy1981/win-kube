function Invoke-WinKubeKubectl {
    <#
    .SYNOPSIS
    Runs kubectl against the cluster's context.
    .PARAMETER ClusterProfile
    The minikube profile, which is also the kubectl context.
    .PARAMETER ArgumentList
    The kubectl arguments.
    .PARAMETER Capture
    Return kubectl's output instead of writing it to the host.
    .EXAMPLE
    Invoke-WinKubeKubectl -ClusterProfile 'winkube' -ArgumentList @('get', 'nodes')
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$ClusterProfile,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [switch]$Capture
    )

    $kubectl = Get-WinKubeToolPath -Name 'kubectl'
    Invoke-WinKubeNative -FilePath $kubectl -ArgumentList (@('--context', $ClusterProfile) + $ArgumentList) `
        -Capture:$Capture
}

function Get-WinKubeKubectlJson {
    <#
    .SYNOPSIS
    Runs a kubectl get with -o json and returns the parsed object.
    .PARAMETER ClusterProfile
    The minikube profile, which is also the kubectl context.
    .PARAMETER ArgumentList
    The kubectl arguments, without -o json.
    .EXAMPLE
    (Get-WinKubeKubectlJson -ClusterProfile 'winkube' -ArgumentList @('get', 'nodes')).items
    .OUTPUTS
    System.Management.Automation.PSObject
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory)]
        [string]$ClusterProfile,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList
    )

    $kubectlArgs = $ArgumentList + @('-o', 'json')
    $raw = Invoke-WinKubeKubectl -ClusterProfile $ClusterProfile -ArgumentList $kubectlArgs -Capture
    ($raw -join "`n") | ConvertFrom-Json
}

function Add-WinKubeAksNodeLabel {
    <#
    .SYNOPSIS
    Labels the nodes the way AKS does, so selectors in manifests shared with AKS work locally.
    .PARAMETER ClusterProfile
    The minikube profile.
    .EXAMPLE
    Add-WinKubeAksNodeLabel -ClusterProfile 'winkube'
    .OUTPUTS
    None
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [string]$ClusterProfile
    )

    $windows = Get-WinKubeWindowsNode -ClusterProfile $ClusterProfile
    $sku = 'Windows'
    if ($windows.Release) {
        $sku = "Windows$($windows.Release)"
    }
    Invoke-WinKubeKubectl -ClusterProfile $ClusterProfile -ArgumentList @(
        'label', 'node', $windows.Name, '--overwrite', 'agentpool=win', 'kubernetes.azure.com/agentpool=win',
        'kubernetes.azure.com/mode=user', "kubernetes.azure.com/os-sku=$sku"
    )
    $linux = Get-WinKubeKubectlJson -ClusterProfile $ClusterProfile -ArgumentList @(
        'get', 'nodes', '-l', 'kubernetes.io/os=linux'
    )
    foreach ($node in $linux.items) {
        Invoke-WinKubeKubectl -ClusterProfile $ClusterProfile -ArgumentList @(
            'label', 'node', $node.metadata.name, '--overwrite', 'agentpool=system',
            'kubernetes.azure.com/agentpool=system', 'kubernetes.azure.com/mode=system'
        )
    }
}

function Get-WinKubeSshArgument {
    <#
    .SYNOPSIS
    Returns the ssh/scp options for reaching the Windows node as Administrator with minikube's key.
    .PARAMETER Node
    A WinKube.WindowsNode from Get-WinKubeWindowsNode.
    .PARAMETER Interactive
    Leave out BatchMode so ssh may prompt.
    .EXAMPLE
    Get-WinKubeSshArgument -Node (Get-WinKubeWindowsNode)
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [psobject]$Node,

        [switch]$Interactive
    )

    $keyOutput = Invoke-WinKubeNative -FilePath (Get-WinKubeMinikubePath) -Capture -ArgumentList @(
        'ssh-key', '-p', $Node.ClusterProfile, '-n', $Node.Machine
    )
    $key = "$($keyOutput | Select-Object -Last 1)".Trim()
    [string[]]$options = @(
        '-i', $key, '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL',
        '-o', 'LogLevel=ERROR', '-o', 'ConnectTimeout=15'
    )
    if (-not $Interactive) {
        $options += @('-o', 'BatchMode=yes')
    }
    # One string per option on the pipeline; callers collect them with @()
    $options | ForEach-Object -Process { [string]$_ }
}

function Copy-WinKubeFileToWindowsNode {
    <#
    .SYNOPSIS
    Copies a local file to the Windows node with scp.
    .PARAMETER Node
    A WinKube.WindowsNode from Get-WinKubeWindowsNode.
    .PARAMETER Path
    The local file.
    .PARAMETER Destination
    The path on the node, such as C:\Windows\Temp\winkube\x.tar.
    .EXAMPLE
    Copy-WinKubeFileToWindowsNode -Node $node -Path .\image.tar -Destination 'C:\Windows\Temp\winkube\image.tar'
    .OUTPUTS
    None
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [psobject]$Node,

        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    $target = "Administrator@$($Node.IP):$($Destination -replace '\\', '/')"
    $scpArgs = @(Get-WinKubeSshArgument -Node $Node) + @('-q', $Path, $target)
    Invoke-WinKubeNative -FilePath 'scp.exe' -ArgumentList $scpArgs
}

function ConvertFrom-WinKubeJsonArray {
    <#
    .SYNOPSIS
    Parses JSON that is either one object or an array of objects, and returns an array.
    .DESCRIPTION
    Windows PowerShell 5.1's ConvertFrom-Json writes a JSON array to the pipeline as a single object, while
    PowerShell 7 enumerates it, so @(... | ConvertFrom-Json) counts differently. This always enumerates.
    .PARAMETER Json
    The JSON text, as one string or as output lines.
    .EXAMPLE
    ConvertFrom-WinKubeJsonArray -Json '[{"a": 1}, {"a": 2}]'
    .OUTPUTS
    System.Array
    #>
    [CmdletBinding()]
    [OutputType([System.Array])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Json
    )

    $parsed = ($Json -join "`n") | ConvertFrom-Json
    $items = @(foreach ($item in $parsed) {
            $item
        })
    , $items
}

function Get-WinKubePropertyValue {
    <#
    .SYNOPSIS
    Returns a property's value, or $null when the object doesn't have it.
    .DESCRIPTION
    Kubernetes labels and minikube status fields are optional; under Set-StrictMode, reading a missing property
    throws, so optional ones are read through this function.
    .PARAMETER InputObject
    The object, typically from ConvertFrom-Json.
    .PARAMETER Name
    The property name, which may contain dots and slashes (label keys).
    .EXAMPLE
    Get-WinKubePropertyValue -InputObject $node.metadata.labels -Name 'agentpool'
    .OUTPUTS
    System.Object
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [AllowNull()]
        [psobject]$InputObject,

        [Parameter(Mandatory)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) {
        $property.Value
    }
}

function ConvertTo-WinKubeSecureString {
    <#
    .SYNOPSIS
    Converts a plain string read from a Kubernetes Secret into a read-only SecureString.
    .PARAMETER Value
    The plain text.
    .EXAMPLE
    ConvertTo-WinKubeSecureString -Value $password
    .OUTPUTS
    System.Security.SecureString
    #>
    [CmdletBinding()]
    [OutputType([securestring])]
    param(
        [Parameter(Mandatory)]
        [string]$Value
    )

    $secure = New-Object -TypeName System.Security.SecureString
    foreach ($character in $Value.ToCharArray()) {
        $secure.AppendChar($character)
    }
    $secure.MakeReadOnly()
    $secure
}
