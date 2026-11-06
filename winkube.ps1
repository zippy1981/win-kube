#Requires -Version 5.1

<#
.SYNOPSIS
    win-kube: a minikube-based, AKS-shaped local cluster with a Windows Server node.

.DESCRIPTION
    Wraps an experimental minikube build (Linux control plane + Windows Server 2025
    worker on Hyper-V) and adds AKS-style node labels, image side-loading from the local
    Docker engine, optional Hyper-V isolation for ltsc2022 images, and Helm deploys.

    Only 'prereqs' elevates. Everything else runs as a normal user who is a member of
    "Hyper-V Administrators" and "docker-users" (prereqs sets that up).

    Commands:
      prereqs                  One-time elevated setup (features, dockerd, groups).
      tools                    Download kubectl + helm, build the pinned minikube fork.
      up                       Create/start the cluster (-Isolation hyperv for 2022 images).
      enable-hyperv-isolation  Add Hyper-V isolation to an existing Windows node.
      load-images              docker save local images and import them on the Windows node.
      deploy                   Load images and helm install the WordPress sample chart.
      status                   Show nodes, runtime classes and releases.
      ssh-windows              Interactive SSH session to the Windows node.
      down                     Delete the cluster.

.EXAMPLE
    .\winkube.ps1 prereqs; .\winkube.ps1 tools; .\winkube.ps1 up; .\winkube.ps1 deploy

.EXAMPLE
    .\winkube.ps1 up -Isolation hyperv; .\winkube.ps1 deploy -WindowsVersion 2022
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('help', 'prereqs', 'tools', 'up', 'enable-hyperv-isolation', 'load-images',
                 'deploy', 'status', 'ssh-windows', 'down')]
    [string]$Command = 'help',

    # minikube profile; also the kubectl context name.
    [Alias('Profile')]
    [string]$ClusterProfile = 'winkube',

    # Must not be older than the kubelet baked into the Windows VHD (v1.37.0 in the default image).
    [string]$KubernetesVersion = 'v1.37.0',

    # Applied to each node VM. Nested virtualization (needed for Hyper-V isolation) requires >= 2.
    [ValidateRange(2, 64)]
    [int]$Cpus = 4,
    [ValidateRange(2048, 131072)]
    [int]$MemoryMB = 6144,

    # 'process' runs only images matching the node build (ltsc2025). 'hyperv' also enables
    # Hyper-V isolated containers so ltsc2022 images can run on the 2025 node.
    [ValidateSet('process', 'hyperv')]
    [string]$Isolation = 'process',

    # Custom Windows node VHDX (URL, absolute path, or file:// URI).
    [string]$WindowsVhdUrl,

    # Image tag family to deploy. 2022 requires Hyper-V isolation on the 2025 node.
    [ValidateSet('2025', '2022')]
    [string]$WindowsVersion = '2025',

    [string]$Namespace = 'wordpress',
    [string]$Release = 'wp',

    # load-images: images to import. Defaults to the sample chart's images for -WindowsVersion.
    [string[]]$Images,

    # deploy: extra helm --set values, e.g. -HelmSet 'wordpress.service.nodePort=30080'
    [string[]]$HelmSet,

    [switch]$SkipImageLoad,
    [switch]$Force
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar in 5.1
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Experimental Windows-node support lives on a fork branch until upstream merges it.
# Bump these together after validating a new commit.
$MinikubeRepo = 'https://github.com/bobsira/minikube.git'
$MinikubeRef = '8f57f5ea0e777c5d4ad81824235832562fd6fdb2'   # feature/windows-node-support, 2026-11-03

$Root = $PSScriptRoot
$ToolsDir = Join-Path $Root '.tools'
$BinDir = Join-Path $ToolsDir 'bin'
$CacheDir = Join-Path $Root '.cache'
$ChartDir = Join-Path $Root 'charts\wordpress-windows'
$HyperVRuntimeClass = 'windows-hyperv'
$HyperVRuntimeHandler = 'runhcs-wcow-hypervisor'
$RemoteDir = 'C:\Windows\Temp\winkube'
$WindowsBuilds = @{ '10.0.17763' = '2019'; '10.0.20348' = '2022'; '10.0.26100' = '2025' }

if (($env:Path -split ';') -notcontains $BinDir) { $env:Path = "$BinDir;$env:Path" }

# --- Output helpers ----------------------------------------------------------------------
function Write-Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Cyan }
function Write-Info([string]$Message) { Write-Host "    $Message" }

# Runs a native command and throws on a non-zero exit code. Output is passed through.
function Invoke-Native {
    param([Parameter(Mandatory)][string]$FilePath, [string[]]$Arguments = @())
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) { throw "'$FilePath $($Arguments -join ' ')' failed with exit code $LASTEXITCODE" }
}

function Get-UrlText([string]$Uri) {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri
    $content = $response.Content
    if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
    return $content.Trim()
}

function Get-Tool([string]$Name) {
    $local = Join-Path $BinDir "$Name.exe"
    if (Test-Path $local) { return $local }
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    throw "$Name not found. Run: .\winkube.ps1 tools"
}

function Get-Minikube {
    $exe = Join-Path $BinDir 'minikube.exe'
    if (-not (Test-Path $exe)) { throw 'The Windows-node minikube build is missing. Run: .\winkube.ps1 tools' }
    return $exe
}

function Invoke-Kubectl([string[]]$Arguments) {
    Invoke-Native (Get-Tool kubectl) (@('--context', $ClusterProfile) + $Arguments)
}

# Runs a native command for its exit code only. Windows PowerShell 5.1 turns redirected
# native stderr into terminating errors under ErrorActionPreference=Stop, so relax it here.
function Test-Native {
    param([Parameter(Mandatory)][string]$FilePath, [string[]]$Arguments = @())
    $saved = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $FilePath @Arguments 2>&1 | Out-Null
        return ($LASTEXITCODE -eq 0)
    } finally {
        $ErrorActionPreference = $saved
    }
}

function Get-KubectlJson([string[]]$Arguments) {
    $raw = & (Get-Tool kubectl) --context $ClusterProfile @Arguments -o json
    if ($LASTEXITCODE -ne 0) { throw "kubectl $($Arguments -join ' ') failed" }
    return ($raw -join "`n") | ConvertFrom-Json
}

# --- Access checks -----------------------------------------------------------------------
function Test-HyperVAccess {
    $principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    $hvAdmins = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-578')
    return $principal.IsInRole($hvAdmins) -or $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Assert-HyperV {
    if (-not (Get-Service vmms -ErrorAction SilentlyContinue)) {
        throw 'Hyper-V is not installed. Run: .\winkube.ps1 prereqs (then reboot)'
    }
    if (-not (Test-HyperVAccess)) {
        throw "You are not in 'Hyper-V Administrators'. Run: .\winkube.ps1 prereqs, then sign out and back in."
    }
    if ((Get-Service vmms).Status -ne 'Running') { throw 'The Hyper-V Virtual Machine Management service (vmms) is not running.' }
    Import-Module Hyper-V -ErrorAction Stop
    if (-not (Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue)) {
        throw "Hyper-V 'Default Switch' not found. It is created automatically on Windows 10 1709+; reboot after enabling Hyper-V."
    }
}

# --- prereqs -----------------------------------------------------------------------------
function Invoke-Prereqs {
    $script = Join-Path $Root 'scripts\Install-WinKubePrereqs.ps1'
    # Run under Windows PowerShell 5.1 so it works the same everywhere; it self-elevates.
    Invoke-Native 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script)
}

# --- tools -------------------------------------------------------------------------------
function Install-Kubectl {
    $exe = Join-Path $BinDir 'kubectl.exe'
    if ((Test-Path $exe) -and -not $Force) { Write-Info "kubectl present ($exe)"; return }
    Write-Step "Downloading kubectl $KubernetesVersion"
    Invoke-WebRequest -UseBasicParsing -Uri "https://dl.k8s.io/release/$KubernetesVersion/bin/windows/amd64/kubectl.exe" -OutFile $exe
}

function Install-Helm {
    $exe = Join-Path $BinDir 'helm.exe'
    if ((Test-Path $exe) -and -not $Force) { Write-Info "helm present ($exe)"; return }
    $version = Get-UrlText 'https://get.helm.sh/helm-latest-version'
    Write-Step "Downloading helm $version"
    $zip = Join-Path $CacheDir "helm-$version.zip"
    $extract = Join-Path $CacheDir "helm-$version"
    Invoke-WebRequest -UseBasicParsing -Uri "https://get.helm.sh/helm-$version-windows-amd64.zip" -OutFile $zip
    Expand-Archive -Path $zip -DestinationPath $extract -Force
    Copy-Item (Join-Path $extract 'windows-amd64\helm.exe') $exe -Force
    Remove-Item $zip, $extract -Recurse -Force
}

# Returns a go.exe that can build the given module, downloading a portable toolchain if needed.
function Get-Go([string]$RequiredVersion) {
    $candidates = @((Join-Path $ToolsDir 'go\bin\go.exe'))
    $onPath = Get-Command go -ErrorAction SilentlyContinue
    if ($onPath) { $candidates += $onPath.Source }
    foreach ($go in $candidates) {
        if (-not (Test-Path $go)) { continue }
        $have = ((& $go env GOVERSION) -replace '^go', '') -replace '[^0-9.].*$', ''
        if ([version]$have -ge [version]$RequiredVersion) { return $go }
    }
    $latest = (Get-UrlText 'https://go.dev/VERSION?m=text').Split("`n")[0].Trim()
    Write-Step "Downloading portable $latest"
    $zip = Join-Path $CacheDir "$latest.zip"
    Invoke-WebRequest -UseBasicParsing -Uri "https://go.dev/dl/$latest.windows-amd64.zip" -OutFile $zip
    $goRoot = Join-Path $ToolsDir 'go'
    if (Test-Path $goRoot) { Remove-Item $goRoot -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $ToolsDir -Force   # zip contains a top-level go\
    Remove-Item $zip -Force
    return (Join-Path $goRoot 'bin\go.exe')
}

function Install-Minikube {
    $exe = Join-Path $BinDir 'minikube.exe'
    $stamp = Join-Path $BinDir 'minikube.ref'
    if ((Test-Path $exe) -and (Test-Path $stamp) -and ((Get-Content $stamp -Raw).Trim() -eq $MinikubeRef) -and -not $Force) {
        Write-Info "minikube $($MinikubeRef.Substring(0, 12)) present ($exe)"
        return
    }
    $git = (Get-Command git -ErrorAction SilentlyContinue)
    if (-not $git) { throw 'git is required to build minikube (winget install Git.Git).' }

    $src = Join-Path $ToolsDir 'src\minikube'
    Write-Step "Fetching minikube $($MinikubeRef.Substring(0, 12)) from $MinikubeRepo"
    if (-not (Test-Path (Join-Path $src '.git'))) {
        New-Item -ItemType Directory -Force -Path $src | Out-Null
        Invoke-Native 'git' @('-C', $src, 'init', '--quiet')
        Invoke-Native 'git' @('-C', $src, 'remote', 'add', 'origin', $MinikubeRepo)
    }
    # The tree has paths longer than MAX_PATH.
    Invoke-Native 'git' @('-C', $src, 'config', 'core.longpaths', 'true')
    Invoke-Native 'git' @('-C', $src, 'fetch', '--quiet', '--depth', '1', 'origin', $MinikubeRef)
    Invoke-Native 'git' @('-C', $src, '-c', 'advice.detachedHead=false', 'checkout', '--quiet', '--force', 'FETCH_HEAD')

    $goVersion = ((Get-Content (Join-Path $src 'go.mod')) | Where-Object { $_ -match '^go\s+(\S+)' } | Select-Object -First 1) -replace '^go\s+', ''
    $go = Get-Go $goVersion

    # Reproduce the Makefile's ldflags so the binary resolves the right ISO and versions.
    $makefile = Get-Content (Join-Path $src 'Makefile')
    function Get-MakeVar([string]$Name) {
        $line = $makefile | Where-Object { $_ -match "^$Name\s*\?=" } | Select-Object -First 1
        if (-not $line) { throw "Could not find $Name in the minikube Makefile" }
        return ($line -replace "^$Name\s*\?=\s*", '').Trim()
    }
    $version = 'v{0}.{1}.{2}' -f (Get-MakeVar 'VERSION_MAJOR'), (Get-MakeVar 'VERSION_MINOR'), (Get-MakeVar 'VERSION_BUILD')
    $ldflags = @(
        "-X k8s.io/minikube/pkg/version.version=$version",
        "-X k8s.io/minikube/pkg/version.isoVersion=$(Get-MakeVar 'ISO_VERSION')",
        "-X k8s.io/minikube/pkg/version.gitCommitID=$MinikubeRef",
        "-X k8s.io/minikube/pkg/version.storageProvisionerVersion=$(Get-MakeVar 'STORAGE_PROVISIONER_TAG')"
    ) -join ' '

    Write-Step "Building minikube $version (this takes a few minutes the first time)"
    $savedCgo = $env:CGO_ENABLED
    $savedToolchain = $env:GOTOOLCHAIN
    Push-Location $src
    try {
        $env:CGO_ENABLED = '0'
        $env:GOTOOLCHAIN = 'auto'   # let go.mod pull a newer toolchain if it needs one
        Invoke-Native $go @('build', '-tags', 'libvirt_dlopen', '-ldflags', $ldflags, '-o', $exe, 'k8s.io/minikube/cmd/minikube')
    } finally {
        Pop-Location
        $env:CGO_ENABLED = $savedCgo
        $env:GOTOOLCHAIN = $savedToolchain
    }
    Set-Content -Path $stamp -Value $MinikubeRef -Encoding ascii
    Write-Info "Built $exe"
}

function Invoke-Tools {
    New-Item -ItemType Directory -Force -Path $BinDir, $CacheDir | Out-Null
    Install-Kubectl
    Install-Helm
    Install-Minikube
    Write-Host ''
    Write-Host "Tools ready in $BinDir. Next: .\winkube.ps1 up" -ForegroundColor Green
}

# --- Windows node access -----------------------------------------------------------------
# Returns name, IP, build, release year and minikube machine name of the Windows node.
function Get-WindowsNode {
    $nodes = Get-KubectlJson @('get', 'nodes', '-l', 'kubernetes.io/os=windows')
    if ($nodes.items.Count -eq 0) { throw "No Windows node found in cluster '$ClusterProfile'." }
    $n = $nodes.items[0]
    $ip = ($n.status.addresses | Where-Object { $_.type -eq 'InternalIP' } | Select-Object -First 1).address
    $buildLabel = $n.metadata.labels.PSObject.Properties['node.kubernetes.io/windows-build']
    $build = if ($buildLabel) { $buildLabel.Value } else { '' }
    $machine = $null
    foreach ($line in (& (Get-Minikube) node list -p $ClusterProfile)) {
        $parts = $line -split "\s+"
        if ($parts.Count -ge 2 -and $parts[1] -eq $ip) { $machine = $parts[0] }
    }
    if (-not $machine) { throw "Could not match Windows node $($n.metadata.name) ($ip) to a minikube machine." }
    $release = if ($build -and $WindowsBuilds.ContainsKey($build)) { $WindowsBuilds[$build] } else { $null }
    return New-Object PSObject -Property @{ Name = $n.metadata.name; IP = $ip; Build = $build; Release = $release; Machine = $machine }
}

function Get-SshArgs($Node, [switch]$Interactive) {
    $key = ((& (Get-Minikube) ssh-key -p $ClusterProfile -n $Node.Machine) | Select-Object -Last 1).Trim()
    $sshArgs = @('-i', $key, '-o', 'StrictHostKeyChecking=no', '-o', 'UserKnownHostsFile=NUL',
                 '-o', 'LogLevel=ERROR', '-o', 'ConnectTimeout=15')
    if (-not $Interactive) { $sshArgs += @('-o', 'BatchMode=yes') }
    return $sshArgs
}

function Copy-ToWindowsNode($Node, [string]$LocalPath, [string]$RemotePath) {
    Invoke-Native 'scp.exe' ((Get-SshArgs $Node) + @('-q', $LocalPath, "Administrator@$($Node.IP):$($RemotePath -replace '\\', '/')"))
}

# Runs a PowerShell script on the Windows node (the node's SSH default shell is cmd.exe).
function Invoke-WindowsNode($Node, [string]$Script) {
    $local = Join-Path $CacheDir ("remote-{0}.ps1" -f [guid]::NewGuid().ToString('N'))
    $remote = "$RemoteDir\$(Split-Path $local -Leaf)"
    # The script removes itself once loaded so failures do not leave files behind.
    $prelude = "`$ErrorActionPreference = 'Stop'`r`nRemove-Item -LiteralPath `$PSCommandPath -ErrorAction SilentlyContinue`r`n"
    Set-Content -Path $local -Value ($prelude + $Script) -Encoding UTF8
    try {
        Invoke-Native 'ssh.exe' ((Get-SshArgs $Node) + @("Administrator@$($Node.IP)", "if not exist $RemoteDir mkdir $RemoteDir"))
        Copy-ToWindowsNode $Node $local $remote
        $out = & ssh.exe @((Get-SshArgs $Node) + @("Administrator@$($Node.IP)",
            "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $remote"))
        if ($LASTEXITCODE -ne 0) { throw "Remote script failed on $($Node.Name) (exit $LASTEXITCODE): $($out -join "`n")" }
        return $out
    } finally {
        Remove-Item $local -ErrorAction SilentlyContinue
    }
}

# --- up ----------------------------------------------------------------------------------
function Set-AksNodeLabels {
    # Mirror the labels AKS puts on nodes so selectors in shared manifests work locally.
    $win = Get-WindowsNode
    $sku = if ($win.Release) { "Windows$($win.Release)" } else { 'Windows' }
    Invoke-Kubectl @('label', 'node', $win.Name, '--overwrite', 'agentpool=win', 'kubernetes.azure.com/agentpool=win',
                     'kubernetes.azure.com/mode=user', "kubernetes.azure.com/os-sku=$sku")
    $linux = Get-KubectlJson @('get', 'nodes', '-l', 'kubernetes.io/os=linux')
    foreach ($n in $linux.items) {
        Invoke-Kubectl @('label', 'node', $n.metadata.name, '--overwrite', 'agentpool=system',
                         'kubernetes.azure.com/agentpool=system', 'kubernetes.azure.com/mode=system')
    }
}

function Invoke-Up {
    Assert-HyperV
    $minikube = Get-Minikube
    $null = Get-Tool kubectl

    $freeMB = [int]((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1024)
    if ($freeMB -lt (2 * $MemoryMB)) {
        Write-Warning "Only $freeMB MB free; two nodes need $(2 * $MemoryMB) MB. Use -MemoryMB to lower it."
    }

    $startArgs = @('start', '-p', $ClusterProfile, '--driver=hyperv',
                   '--node', 'role=control-plane', '--node', 'role=worker,os=windows',
                   "--kubernetes-version=$KubernetesVersion", "--cpus=$Cpus", "--memory=$MemoryMB")
    if ($WindowsVhdUrl) { $startArgs += "--windows-vhd-url=$WindowsVhdUrl" }
    # Nested virtualization (needed by Hyper-V isolated containers) is unreliable with dynamic memory.
    if ($Isolation -eq 'hyperv') { $startArgs += '--hyperv-disable-dynamic-memory' }

    Write-Step "Starting cluster '$ClusterProfile' (first run downloads the Windows VHDX; allow 20+ minutes)"
    Invoke-Native $minikube $startArgs

    Write-Step 'Waiting for all nodes to be Ready'
    Invoke-Kubectl @('wait', '--for=condition=Ready', 'nodes', '--all', '--timeout=20m')
    Set-AksNodeLabels

    if ($Isolation -eq 'hyperv') { Invoke-EnableHyperVIsolation }
    Invoke-Status
}

# --- Hyper-V isolation -------------------------------------------------------------------
function Invoke-EnableHyperVIsolation {
    Assert-HyperV
    $node = Get-WindowsNode
    $vm = Get-VM -Name $node.Machine
    if (-not (Get-VMProcessor -VMName $vm.Name).ExposeVirtualizationExtensions) {
        throw "VM $($vm.Name) does not expose virtualization extensions. Recreate with: .\winkube.ps1 down; .\winkube.ps1 up -Isolation hyperv"
    }

    Write-Step "Configuring Hyper-V isolation on $($node.Name)"
    # Adds a containerd runtime handler with SandboxIsolation=1 next to the default
    # runhcs-wcow-process one, matching whatever config schema (v2/v3) the node uses.
    $remote = @"
`$restart = `$false
if ((Get-WindowsFeature Hyper-V).InstallState -ne 'Installed') {
    `$r = Install-WindowsFeature -Name Hyper-V
    if (-not `$r.Success) { throw 'Install-WindowsFeature Hyper-V failed' }
    `$restart = `$true
}
`$config = Join-Path `$env:ProgramFiles 'containerd\config.toml'
`$toml = [IO.File]::ReadAllText(`$config)
if (`$toml -notmatch '$HyperVRuntimeHandler') {
    `$m = [regex]::Match(`$toml, '\[([^\]]*containerd\.runtimes)\.(?:runhcs-wcow-process|''runhcs-wcow-process''|"runhcs-wcow-process")\]')
    if (-not `$m.Success) { throw "No runhcs-wcow-process runtime found in `$config" }
    `$p = `$m.Groups[1].Value
    `$toml += "`r`n[`$p.$HyperVRuntimeHandler]`r`n  runtime_type = 'io.containerd.runhcs.v1'`r`n  [`$p.$HyperVRuntimeHandler.options]`r`n    SandboxIsolation = 1`r`n    ScaleCpuLimitsToSandbox = true`r`n"
    [IO.File]::WriteAllText(`$config, `$toml, (New-Object Text.ASCIIEncoding))
    if (-not `$restart) { Restart-Service containerd }
}
if (`$restart) { 'RESTART_REQUIRED' } else { 'OK' }
"@
    $result = Invoke-WindowsNode $node $remote
    if (($result -join "`n") -match 'RESTART_REQUIRED') {
        Write-Step "Restarting VM $($vm.Name) to finish installing the Hyper-V role (several minutes)"
        Stop-VM -Name $vm.Name -Force
        if ((Get-VMMemory -VMName $vm.Name).DynamicMemoryEnabled) {
            Set-VMMemory -VMName $vm.Name -DynamicMemoryEnabled $false
            Write-Info 'Disabled dynamic memory (required for nested virtualization)'
        }
        Start-VM -Name $vm.Name
        # The role install reboots the guest again on its own; wait until it settles.
        $deadline = (Get-Date).AddMinutes(20)
        $ready = $false
        while ((Get-Date) -lt $deadline -and -not $ready) {
            Start-Sleep -Seconds 20
            try {
                $node = Get-WindowsNode
                $state = Invoke-WindowsNode $node "if ((Get-WindowsFeature Hyper-V).InstallState -eq 'Installed' -and (Get-Service containerd).Status -eq 'Running') { 'READY' }"
                $ready = ($state -join '') -match 'READY'
            } catch {
                Write-Info 'Waiting for the Windows node to come back...'
            }
        }
        if (-not $ready) { throw 'Timed out waiting for the Windows node after enabling Hyper-V.' }
        Invoke-Kubectl @('wait', '--for=condition=Ready', "node/$($node.Name)", '--timeout=10m')
    }

    $runtimeClass = @"
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: $HyperVRuntimeClass
handler: $HyperVRuntimeHandler
scheduling:
  nodeSelector:
    kubernetes.io/os: windows
  tolerations:
    - key: os
      operator: Equal
      value: windows
      effect: NoSchedule
"@
    $runtimeClass | & (Get-Tool kubectl) --context $ClusterProfile apply -f -
    if ($LASTEXITCODE -ne 0) { throw 'Failed to create the RuntimeClass' }
    Write-Info "RuntimeClass '$HyperVRuntimeClass' -> handler '$HyperVRuntimeHandler'"
}

# --- load-images -------------------------------------------------------------------------
function Invoke-LoadImages {
    $docker = Get-Tool docker
    $list = $Images
    if (-not $list) { $list = @("windows-nano-php:$WindowsVersion", "mysql-spike:$WindowsVersion") }
    $node = Get-WindowsNode
    $imageCache = Join-Path $CacheDir 'images'
    New-Item -ItemType Directory -Force -Path $imageCache | Out-Null

    foreach ($image in $list) {
        $id = (& $docker image inspect --format '{{.Id}}' $image)
        if ($LASTEXITCODE -ne 0 -or -not $id) { throw "Image '$image' not found in the local Docker engine." }
        $id = "$id".Trim()
        $safe = $image -replace '[^A-Za-z0-9._-]', '_'
        $marker = "$RemoteDir\imported\$safe.id"

        $present = Invoke-WindowsNode $node "if ((Test-Path '$marker') -and ((Get-Content '$marker' -Raw).Trim() -eq '$id')) { 'PRESENT' }"
        if (($present -join '') -match 'PRESENT' -and -not $Force) {
            Write-Info "$image already on $($node.Name)"
            continue
        }

        $tar = Join-Path $imageCache "$safe.tar"
        $idFile = "$tar.id"
        if (-not ((Test-Path $tar) -and (Test-Path $idFile) -and ((Get-Content $idFile -Raw).Trim() -eq $id))) {
            Write-Step "Saving $image"
            Invoke-Native $docker @('save', '-o', $tar, $image)
            Set-Content -Path $idFile -Value $id -Encoding ascii
        }
        Write-Step "Copying $image to $($node.Name) ($([int]((Get-Item $tar).Length / 1MB)) MB)"
        Invoke-Native 'ssh.exe' ((Get-SshArgs $node) + @("Administrator@$($node.IP)", "if not exist $RemoteDir\imported mkdir $RemoteDir\imported"))
        Copy-ToWindowsNode $node $tar "$RemoteDir\$safe.tar"
        Write-Step "Importing $image into containerd"
        # --platform without an OS version lets ltsc2022 images in alongside ltsc2025 ones.
        Invoke-WindowsNode $node @"
& "`$env:ProgramFiles\containerd\ctr.exe" -n k8s.io images import --platform windows/amd64 '$RemoteDir\$safe.tar'
if (`$LASTEXITCODE -ne 0) { throw "ctr import failed (`$LASTEXITCODE)" }
Remove-Item '$RemoteDir\$safe.tar'
Set-Content -Path '$marker' -Value '$id'
"@ | ForEach-Object { Write-Info $_ }
    }
}

# --- deploy ------------------------------------------------------------------------------
function Invoke-Deploy {
    $helm = Get-Tool helm
    $node = Get-WindowsNode
    $nodeRelease = $node.Release
    if (-not $nodeRelease) { throw "Unknown Windows build $($node.Build) on $($node.Name)." }
    if ($WindowsVersion -ne $nodeRelease) {
        if (-not (Test-Native (Get-Tool kubectl) @('--context', $ClusterProfile, 'get', 'runtimeclass', $HyperVRuntimeClass))) {
            throw "ltsc$WindowsVersion images need Hyper-V isolation on this ltsc$nodeRelease node. Run: .\winkube.ps1 enable-hyperv-isolation"
        }
    }
    if (-not $SkipImageLoad) { Invoke-LoadImages }

    Write-Step "helm upgrade --install $Release (Windows $WindowsVersion images)"
    $helmArgs = @('upgrade', '--install', $Release, $ChartDir, '--kube-context', $ClusterProfile,
                  '--namespace', $Namespace, '--create-namespace',
                  '--set', "windows.version=$WindowsVersion", '--set', "windows.nodeVersion=$nodeRelease",
                  '--wait', '--timeout', '30m')
    foreach ($s in @($HelmSet)) { if ($s) { $helmArgs += @('--set', $s) } }
    Invoke-Native $helm $helmArgs

    $svc = Get-KubectlJson @('-n', $Namespace, 'get', 'svc', '-l', "app.kubernetes.io/instance=$Release,app.kubernetes.io/component=wordpress")
    $nodePort = ($svc.items[0].spec.ports | Select-Object -First 1).nodePort
    Write-Host ''
    Write-Host "WordPress: http://$($node.IP):$nodePort/   (Windows node IP; the Linux node IP works too)" -ForegroundColor Green
    $secret = Get-KubectlJson @('-n', $Namespace, 'get', 'secret', '-l', "app.kubernetes.io/instance=$Release,app.kubernetes.io/name=wordpress-windows")
    $encoded = $secret.items[0].data.'wordpress-admin-password'
    $adminPassword = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
    Write-Host "Admin:     http://$($node.IP):$nodePort/wp-admin/  password '$adminPassword' (user: install.adminUser, default 'admin')"
    Write-Host "Verify:    helm test $Release -n $Namespace --kube-context $ClusterProfile"
}

# --- status / ssh / down -----------------------------------------------------------------
function Invoke-Status {
    Write-Step "Cluster '$ClusterProfile'"
    & (Get-Minikube) status -p $ClusterProfile
    Invoke-Kubectl @('get', 'nodes', '-o', 'wide', '-L', 'kubernetes.azure.com/os-sku,agentpool')
    & (Get-Tool kubectl) --context $ClusterProfile get runtimeclass
    $helm = Get-Command helm -ErrorAction SilentlyContinue
    if ($helm) { & $helm.Source list -A --kube-context $ClusterProfile }
}

function Invoke-SshWindows {
    $node = Get-WindowsNode
    & ssh.exe @((Get-SshArgs $node -Interactive) + @("Administrator@$($node.IP)"))
}

function Invoke-Down {
    Write-Step "Deleting cluster '$ClusterProfile'"
    Invoke-Native (Get-Minikube) @('delete', '-p', $ClusterProfile)
}

switch ($Command) {
    'prereqs' { Invoke-Prereqs }
    'tools' { Invoke-Tools }
    'up' { Invoke-Up }
    'enable-hyperv-isolation' { Invoke-EnableHyperVIsolation }
    'load-images' { Invoke-LoadImages }
    'deploy' { Invoke-Deploy }
    'status' { Invoke-Status }
    'ssh-windows' { Invoke-SshWindows }
    'down' { Invoke-Down }
    default { Get-Help $PSCommandPath -Detailed }
}
