function Get-WinKubeToolPath {
    <#
    .SYNOPSIS
    Returns the path of a tool, preferring the copy in .tools/bin.
    .DESCRIPTION
    Looks for <Name>.exe in the repo's .tools/bin folder first, then on PATH, and throws with a hint to run
    Install-WinKubeTool when it is missing.
    .PARAMETER Name
    The tool name without extension, such as kubectl or helm.
    .EXAMPLE
    Get-WinKubeToolPath -Name 'kubectl'
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    $local = Join-Path -Path $script:BinDir -ChildPath "$Name.exe"
    if (Test-Path -LiteralPath $local) {
        return $local
    }
    $command = Get-Command -Name $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($command) {
        return $command.Source
    }
    throw "$Name not found. Run Install-WinKubeTool (or .\winkube.ps1 tools)."
}

function Get-WinKubeMinikubePath {
    <#
    .SYNOPSIS
    Returns the path of the Windows-node minikube build.
    .DESCRIPTION
    Only the build from the pinned fork supports Windows nodes, so a minikube on PATH is never used.
    .EXAMPLE
    Get-WinKubeMinikubePath
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $exe = Join-Path -Path $script:BinDir -ChildPath 'minikube.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        throw 'The Windows-node minikube build is missing. Run Install-WinKubeTool (or .\winkube.ps1 tools).'
    }
    $exe
}

function Get-WinKubeUrlText {
    <#
    .SYNOPSIS
    Downloads a small text resource and returns it trimmed.
    .DESCRIPTION
    Handles servers that answer with application/octet-stream, which Invoke-WebRequest returns as bytes.
    .PARAMETER Uri
    The URL to read.
    .EXAMPLE
    Get-WinKubeUrlText -Uri 'https://get.helm.sh/helm-latest-version'
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri
    )

    $ProgressPreference = 'SilentlyContinue'
    $content = (Invoke-WebRequest -UseBasicParsing -Uri $Uri).Content
    if ($content -is [byte[]]) {
        $content = [Text.Encoding]::UTF8.GetString($content)
    }
    $content.Trim()
}

function Save-WinKubeDownload {
    <#
    .SYNOPSIS
    Downloads a file.
    .DESCRIPTION
    Wraps Invoke-WebRequest with the progress bar off, which is much faster in Windows PowerShell 5.1.
    .PARAMETER Uri
    The URL to download.
    .PARAMETER Path
    Where to save it.
    .EXAMPLE
    Save-WinKubeDownload -Uri 'https://dl.k8s.io/release/v1.37.0/bin/windows/amd64/kubectl.exe' -Path kubectl.exe
    .OUTPUTS
    None
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [uri]$Uri,

        [Parameter(Mandatory)]
        [string]$Path
    )

    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri $Uri -OutFile $Path
}

function Install-WinKubeKubectl {
    <#
    .SYNOPSIS
    Downloads kubectl for the given Kubernetes version into .tools/bin.
    .PARAMETER KubernetesVersion
    The kubectl release, such as v1.37.0.
    .PARAMETER Force
    Download again even if kubectl is present.
    .EXAMPLE
    Install-WinKubeKubectl -KubernetesVersion 'v1.37.0'
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$KubernetesVersion,

        [switch]$Force
    )

    $exe = Join-Path -Path $script:BinDir -ChildPath 'kubectl.exe'
    if ((Test-Path -LiteralPath $exe) -and -not $Force) {
        Write-Verbose -Message "kubectl present ($exe)"
        return $exe
    }
    Write-WinKubeStep -Message "Downloading kubectl $KubernetesVersion"
    $uri = "https://dl.k8s.io/release/$KubernetesVersion/bin/windows/amd64/kubectl.exe"
    Save-WinKubeDownload -Uri $uri -Path $exe
    $exe
}

function Install-WinKubeHelm {
    <#
    .SYNOPSIS
    Downloads the latest helm release into .tools/bin.
    .PARAMETER Force
    Download again even if helm is present.
    .EXAMPLE
    Install-WinKubeHelm
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [switch]$Force
    )

    $exe = Join-Path -Path $script:BinDir -ChildPath 'helm.exe'
    if ((Test-Path -LiteralPath $exe) -and -not $Force) {
        Write-Verbose -Message "helm present ($exe)"
        return $exe
    }
    $version = Get-WinKubeUrlText -Uri 'https://get.helm.sh/helm-latest-version'
    Write-WinKubeStep -Message "Downloading helm $version"
    $zip = Join-Path -Path $script:CacheDir -ChildPath "helm-$version.zip"
    $extract = Join-Path -Path $script:CacheDir -ChildPath "helm-$version"
    Save-WinKubeDownload -Uri "https://get.helm.sh/helm-$version-windows-amd64.zip" -Path $zip
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    Copy-Item -Path (Join-Path -Path $extract -ChildPath 'windows-amd64/helm.exe') -Destination $exe -Force
    Remove-Item -Path $zip, $extract -Recurse -Force
    $exe
}

function Get-WinKubeGoPath {
    <#
    .SYNOPSIS
    Returns a go.exe new enough to build minikube, downloading a portable toolchain if needed.
    .PARAMETER RequiredVersion
    The minimum Go version from minikube's go.mod, such as 1.26.0.
    .EXAMPLE
    Get-WinKubeGoPath -RequiredVersion '1.26.0'
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [version]$RequiredVersion
    )

    $candidates = @(Join-Path -Path $script:ToolsDir -ChildPath 'go/bin/go.exe')
    $onPath = Get-Command -Name 'go' -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($onPath) {
        $candidates += $onPath.Source
    }
    foreach ($go in $candidates) {
        if (-not (Test-Path -LiteralPath $go)) {
            continue
        }
        $reported = Invoke-WinKubeNative -FilePath $go -ArgumentList @('env', 'GOVERSION') -Capture
        $have = ("$reported" -replace '^go', '') -replace '[^0-9.].*$', ''
        if ([version]$have -ge $RequiredVersion) {
            return $go
        }
    }
    $latest = ((Get-WinKubeUrlText -Uri 'https://go.dev/VERSION?m=text') -split "`n")[0].Trim()
    Write-WinKubeStep -Message "Downloading portable $latest"
    $zip = Join-Path -Path $script:CacheDir -ChildPath "$latest.zip"
    Save-WinKubeDownload -Uri "https://go.dev/dl/$latest.windows-amd64.zip" -Path $zip
    $goRoot = Join-Path -Path $script:ToolsDir -ChildPath 'go'
    if (Test-Path -LiteralPath $goRoot) {
        Remove-Item -LiteralPath $goRoot -Recurse -Force
    }
    # The zip contains a top-level go\ folder
    Expand-Archive -Path $zip -DestinationPath $script:ToolsDir -Force
    Remove-Item -LiteralPath $zip -Force
    Join-Path -Path $goRoot -ChildPath 'bin/go.exe'
}

function Get-WinKubeMakeVariable {
    <#
    .SYNOPSIS
    Reads a `NAME ?= value` assignment from minikube's Makefile.
    .PARAMETER Makefile
    The Makefile lines.
    .PARAMETER Name
    The variable name.
    .EXAMPLE
    Get-WinKubeMakeVariable -Makefile (Get-Content Makefile) -Name 'ISO_VERSION'
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string[]]$Makefile,

        [Parameter(Mandatory)]
        [string]$Name
    )

    $line = $Makefile | Where-Object -FilterScript { $_ -match "^$Name\s*\?=" } | Select-Object -First 1
    if (-not $line) {
        throw "Could not find $Name in the minikube Makefile"
    }
    ($line -replace "^$Name\s*\?=\s*", '').Trim()
}

function Install-WinKubeMinikube {
    <#
    .SYNOPSIS
    Builds minikube from the pinned Windows-node fork into .tools/bin.
    .DESCRIPTION
    Fetches $MinikubeRef from $MinikubeRepo with long paths enabled, then runs go build with the Makefile's ldflags
    so the binary resolves the right ISO and versions. Skips the build when the stamp file matches the pin.
    .PARAMETER Force
    Rebuild even if the stamp matches.
    .EXAMPLE
    Install-WinKubeMinikube
    .OUTPUTS
    System.String
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [switch]$Force
    )

    $exe = Join-Path -Path $script:BinDir -ChildPath 'minikube.exe'
    $stamp = Join-Path -Path $script:BinDir -ChildPath 'minikube.ref'
    $built = (Test-Path -LiteralPath $exe) -and (Test-Path -LiteralPath $stamp)
    if ($built -and ((Get-Content -LiteralPath $stamp -Raw).Trim() -eq $script:MinikubeRef) -and -not $Force) {
        Write-Verbose -Message "minikube $($script:MinikubeRef.Substring(0, 12)) present ($exe)"
        return $exe
    }
    $git = Get-WinKubeToolPath -Name 'git'

    $src = Join-Path -Path $script:ToolsDir -ChildPath 'src/minikube'
    Write-WinKubeStep -Message "Fetching minikube $($script:MinikubeRef.Substring(0, 12)) from $script:MinikubeRepo"
    if (-not (Test-Path -LiteralPath (Join-Path -Path $src -ChildPath '.git'))) {
        New-Item -ItemType Directory -Force -Path $src | Out-Null
        Invoke-WinKubeNative -FilePath $git -ArgumentList @('-C', $src, 'init', '--quiet')
        Invoke-WinKubeNative -FilePath $git -ArgumentList @('-C', $src, 'remote', 'add', 'origin', $script:MinikubeRepo)
    }
    # The tree has paths longer than MAX_PATH
    Invoke-WinKubeNative -FilePath $git -ArgumentList @('-C', $src, 'config', 'core.longpaths', 'true')
    Invoke-WinKubeNative -FilePath $git -ArgumentList @(
        '-C', $src, 'fetch', '--quiet', '--depth', '1', 'origin', $script:MinikubeRef
    )
    Invoke-WinKubeNative -FilePath $git -ArgumentList @(
        '-C', $src, '-c', 'advice.detachedHead=false', 'checkout', '--quiet', '--force', 'FETCH_HEAD'
    )

    $goMod = Get-Content -LiteralPath (Join-Path -Path $src -ChildPath 'go.mod')
    $goLine = $goMod | Where-Object -FilterScript { $_ -match '^go\s+(\S+)' } | Select-Object -First 1
    $go = Get-WinKubeGoPath -RequiredVersion ($goLine -replace '^go\s+', '')

    $makefile = Get-Content -LiteralPath (Join-Path -Path $src -ChildPath 'Makefile')
    $version = 'v{0}.{1}.{2}' -f @(
        (Get-WinKubeMakeVariable -Makefile $makefile -Name 'VERSION_MAJOR'),
        (Get-WinKubeMakeVariable -Makefile $makefile -Name 'VERSION_MINOR'),
        (Get-WinKubeMakeVariable -Makefile $makefile -Name 'VERSION_BUILD')
    )
    $ldflags = @(
        "-X k8s.io/minikube/pkg/version.version=$version",
        "-X k8s.io/minikube/pkg/version.isoVersion=$(Get-WinKubeMakeVariable -Makefile $makefile -Name 'ISO_VERSION')",
        "-X k8s.io/minikube/pkg/version.gitCommitID=$script:MinikubeRef",
        ('-X k8s.io/minikube/pkg/version.storageProvisionerVersion=' +
        (Get-WinKubeMakeVariable -Makefile $makefile -Name 'STORAGE_PROVISIONER_TAG'))
    ) -join ' '

    Write-WinKubeStep -Message "Building minikube $version (this takes a few minutes the first time)"
    $savedCgo = $env:CGO_ENABLED
    $savedToolchain = $env:GOTOOLCHAIN
    Push-Location -LiteralPath $src
    try {
        $env:CGO_ENABLED = '0'
        # Let go.mod pull a newer toolchain if it needs one
        $env:GOTOOLCHAIN = 'auto'
        Invoke-WinKubeNative -FilePath $go -ArgumentList @(
            'build', '-tags', 'libvirt_dlopen', '-ldflags', $ldflags, '-o', $exe, 'k8s.io/minikube/cmd/minikube'
        )
    } finally {
        Pop-Location
        $env:CGO_ENABLED = $savedCgo
        $env:GOTOOLCHAIN = $savedToolchain
    }
    Set-Content -LiteralPath $stamp -Value $script:MinikubeRef -Encoding Ascii
    $exe
}
