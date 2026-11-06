#Requires -Version 5.1

<#
.SYNOPSIS
    One-time, elevated setup for win-kube: Windows features, OSS dockerd, and the
    group memberships that let every other win-kube command run WITHOUT elevation.

.DESCRIPTION
    Idempotent. Safe to re-run; it only changes what is missing.

      * Enables Microsoft-Hyper-V-All (hypervisor, VMMS, Hyper-V PowerShell) and Containers.
      * Adds the target user to "Hyper-V Administrators" (S-1-5-32-578). minikube's
        hyperv driver accepts that group in place of an elevated token.
      * Creates "docker-users", adds the user, and sets dockerd's pipe group to it.
      * Installs the OSS static dockerd.exe/docker.exe into C:\docker if absent and
        registers the "docker" service (skipped when Docker Desktop is installed).
      * Enables Win32 long paths (the minikube source tree needs them).

    Works in Windows PowerShell 5.1 and PowerShell 7. Self-elevates via UAC.

.PARAMETER User
    Account to grant access to. Defaults to the user who launched the script, which is
    preserved across the UAC re-launch.

.PARAMETER DockerPath
    Where dockerd.exe / docker.exe live. Default C:\docker.

.PARAMETER DockerVersion
    'latest' (default) or an explicit version such as 29.9.3.

.PARAMETER SkipDocker
    Do not install or configure dockerd.

.PARAMETER Restart
    Reboot automatically if a feature install requires it.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\scripts\Install-WinKubePrereqs.ps1
#>
[CmdletBinding()]
param(
    [string]$User = ('{0}\{1}' -f $env:USERDOMAIN, $env:USERNAME),
    [string]$DockerPath = 'C:\docker',
    [string]$DockerVersion = 'latest',
    [switch]$SkipDocker,
    [switch]$Restart
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
# Progress goes to the information stream; show it, since this usually runs in its own elevated window
$InformationPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor
[Net.SecurityProtocolType]::Tls12

function Write-Step {
    <#
    .SYNOPSIS
    Reports the start of a setup step.
    .PARAMETER Message
    The step.
    .EXAMPLE
    Write-Step -Message 'Enabling Windows optional features'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param([string]$Message)

    Write-Information -MessageData "==> $Message"
}

function Write-Ok {
    <#
    .SYNOPSIS
    Reports something that was already in place.
    .PARAMETER Message
    What was checked.
    .EXAMPLE
    Write-Ok -Message 'Containers already enabled'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param([string]$Message)

    Write-Information -MessageData "    [ok] $Message"
}

function Write-Change {
    <#
    .SYNOPSIS
    Reports a change this script made.
    .PARAMETER Message
    What changed.
    .EXAMPLE
    Write-Change -Message 'Enabling Containers'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param([string]$Message)

    Write-Information -MessageData "    [+]  $Message"
}

function Test-Elevated {
    <#
    .SYNOPSIS
    Tests whether this process runs with an elevated administrator token.
    .EXAMPLE
    Test-Elevated
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object -TypeName Security.Principal.WindowsPrincipal -ArgumentList $identity
    $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Add-UserToGroup {
    <#
    .SYNOPSIS
    Adds an account to a local group unless it is already a member.
    .DESCRIPTION
    Get-LocalGroupMember can fail on groups holding Entra ID accounts, so the membership test is best-effort and a
    MemberExists error from Add-LocalGroupMember is not an error. Sets $script:LogoffNeeded when it adds a member.
    .PARAMETER GroupName
    The local group.
    .PARAMETER Account
    The account, as DOMAIN\user.
    .EXAMPLE
    Add-UserToGroup -GroupName 'docker-users' -Account 'CONTOSO\alice'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string]$GroupName,
        [string]$Account
    )

    $members = @(Get-LocalGroupMember -Name $GroupName -ErrorAction SilentlyContinue |
            ForEach-Object -Process { $_.Name })
    if ($members -contains $Account) {
        Write-Ok -Message "$Account is in '$GroupName'"
        return
    }
    try {
        Add-LocalGroupMember -Name $GroupName -Member $Account
        Write-Change -Message "Added $Account to '$GroupName'"
        $script:LogoffNeeded = $true
    } catch {
        if ($_.FullyQualifiedErrorId -notlike 'MemberExists*') {
            throw
        }
        Write-Ok -Message "$Account is in '$GroupName'"
    }
}

# --- Self-elevate, carrying the original user forward --------------------------------
if (-not (Test-Elevated)) {
    Write-Step "Re-launching elevated (UAC prompt) for user $User"
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"",
        '-User', "`"$User`"", '-DockerPath', "`"$DockerPath`"", '-DockerVersion', $DockerVersion)
    if ($SkipDocker) { $argList += '-SkipDocker' }
    if ($Restart) { $argList += '-Restart' }
    $exe = (Get-Process -Id $PID).Path
    $proc = Start-Process -FilePath $exe -ArgumentList $argList -Verb RunAs -Wait -PassThru
    exit $proc.ExitCode
}

$script:RestartNeeded = $false
$script:LogoffNeeded = $false

try {
    # --- Platform checks ------------------------------------------------------------
    Write-Step 'Checking OS and virtualization support'
    $os = Get-CimInstance Win32_OperatingSystem
    if ($os.Caption -match 'Home') {
        throw ("Hyper-V is not available on '$($os.Caption)'. " +
            'Windows Pro, Enterprise, Education or Server is required.')
    }
    Write-Ok $os.Caption
    $cs = Get-CimInstance Win32_ComputerSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    # Once a hypervisor is running, Win32_Processor reports firmware virtualization as false.
    if (-not $cs.HypervisorPresent -and -not $cpu.VirtualizationFirmwareEnabled) {
        throw 'CPU virtualization (VT-x/AMD-V) is disabled in firmware. Enable it in BIOS/UEFI and re-run.'
    }
    Write-Ok 'Hardware virtualization available'

    # --- Optional features ----------------------------------------------------------
    Write-Step 'Enabling Windows optional features'
    foreach ($name in @('Microsoft-Hyper-V-All', 'Containers')) {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $name
        if ($null -eq $feature) { throw "Optional feature '$name' is not available on this edition of Windows." }
        if ($feature.State -eq 'Enabled') {
            Write-Ok "$name already enabled"
            continue
        }
        Write-Change "Enabling $name"
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $name -All -NoRestart
        if ($result.RestartNeeded) { $script:RestartNeeded = $true }
    }

    # --- Long paths -----------------------------------------------------------------
    Write-Step 'Enabling Win32 long paths'
    $fsKey = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    $longPaths = Get-ItemProperty -Path $fsKey -Name LongPathsEnabled -ErrorAction SilentlyContinue
    if ($null -eq $longPaths -or $longPaths.LongPathsEnabled -ne 1) {
        New-ItemProperty -Path $fsKey -Name LongPathsEnabled -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Change 'LongPathsEnabled=1'
    } else {
        Write-Ok 'Already enabled'
    }

    # --- Groups ---------------------------------------------------------------------
    Write-Step "Granting $User non-elevated access to Hyper-V and Docker"
    # Look the Hyper-V group up by well-known SID; its display name is localized.
    $hvGroup = Get-LocalGroup -SID 'S-1-5-32-578' -ErrorAction SilentlyContinue
    if ($null -eq $hvGroup) {
        Write-Warning "The 'Hyper-V Administrators' group does not exist yet. Reboot, then re-run this script."
    } else {
        Add-UserToGroup -GroupName $hvGroup.Name -Account $User
    }
    if ($null -eq (Get-LocalGroup -Name 'docker-users' -ErrorAction SilentlyContinue)) {
        New-LocalGroup -Name 'docker-users' -Description 'Users allowed to use the Docker engine named pipe' | Out-Null
        Write-Change "Created group 'docker-users'"
    }
    Add-UserToGroup -GroupName 'docker-users' -Account $User

    # --- OSS dockerd ----------------------------------------------------------------
    if ($SkipDocker) {
        Write-Step 'Skipping Docker (-SkipDocker)'
    } elseif (Get-Service -Name 'com.docker.service' -ErrorAction SilentlyContinue) {
        Write-Step 'Docker Desktop detected; leaving its engine alone'
        Write-Warning 'Switch Docker Desktop to Windows containers to build Windows images.'
    } else {
        Write-Step "Ensuring OSS dockerd in $DockerPath"
        $dockerd = Join-Path $DockerPath 'dockerd.exe'
        if (Test-Path $dockerd) {
            Write-Ok "$dockerd present ($((Get-Item $dockerd).VersionInfo.ProductVersion))"
        } else {
            $base = 'https://download.docker.com/win/static/stable/x86_64/'
            if ($DockerVersion -eq 'latest') {
                $links = (Invoke-WebRequest -UseBasicParsing -Uri $base).Links |
                    ForEach-Object { $_.href } |
                    Where-Object { $_ -match '^docker-(\d+\.\d+\.\d+)\.zip$' }
                $DockerVersion = ($links | ForEach-Object { [version]($_ -replace '^docker-|\.zip$', '') } |
                        Sort-Object -Descending | Select-Object -First 1).ToString()
            }
            $zip = Join-Path $env:TEMP "docker-$DockerVersion.zip"
            $extract = Join-Path $env:TEMP "docker-$DockerVersion"
            Write-Change "Downloading docker $DockerVersion"
            Invoke-WebRequest -UseBasicParsing -Uri "$base/docker-$DockerVersion.zip" -OutFile $zip
            if (Test-Path $extract) { Remove-Item $extract -Recurse -Force }
            Expand-Archive -Path $zip -DestinationPath $extract
            New-Item -ItemType Directory -Force -Path $DockerPath | Out-Null
            Copy-Item -Path (Join-Path $extract 'docker\*') -Destination $DockerPath -Recurse -Force
            Remove-Item $zip, $extract -Recurse -Force
            Write-Change "Installed docker $DockerVersion to $DockerPath"
        }

        $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        if (($machinePath -split ';') -notcontains $DockerPath) {
            [Environment]::SetEnvironmentVariable('Path', "$machinePath;$DockerPath", 'Machine')
            Write-Change "Added $DockerPath to the machine PATH"
        }

        # Let docker-users talk to \\.\pipe\docker_engine without elevation.
        $configDir = Join-Path $env:ProgramData 'docker\config'
        $daemonJson = Join-Path $configDir 'daemon.json'
        New-Item -ItemType Directory -Force -Path $configDir | Out-Null
        $config = New-Object PSObject
        if (Test-Path $daemonJson) {
            $raw = Get-Content -Path $daemonJson -Raw
            if ($raw -and $raw.Trim()) { $config = $raw | ConvertFrom-Json }
        }
        $groupProp = $config.PSObject.Properties['group']
        $configChanged = $false
        if ($null -eq $groupProp -or $groupProp.Value -ne 'docker-users') {
            $config | Add-Member -NotePropertyName 'group' -NotePropertyValue 'docker-users' -Force
            # PS 5.1's Set-Content -Encoding UTF8 writes a BOM, which dockerd rejects.
            $utf8NoBom = New-Object -TypeName Text.UTF8Encoding -ArgumentList $false
            [IO.File]::WriteAllText($daemonJson, ($config | ConvertTo-Json -Depth 10), $utf8NoBom)
            Write-Change "Set `"group`": `"docker-users`" in $daemonJson"
            $configChanged = $true
        } else {
            Write-Ok 'daemon.json already grants docker-users'
        }

        $service = Get-Service -Name docker -ErrorAction SilentlyContinue
        if ($null -eq $service) {
            & $dockerd --register-service
            if ($LASTEXITCODE -ne 0) { throw "dockerd --register-service failed ($LASTEXITCODE)" }
            Write-Change "Registered the 'docker' service"
            $service = Get-Service -Name docker
        }
        Set-Service -Name docker -StartupType Automatic
        if ($script:RestartNeeded) {
            Write-Warning 'The docker service will start after the reboot (Containers feature pending).'
        } elseif ($service.Status -ne 'Running') {
            Start-Service docker
            Write-Change 'Started docker'
        } elseif ($configChanged) {
            Restart-Service docker
            Write-Change 'Restarted docker to apply daemon.json'
        } else {
            Write-Ok 'docker service running'
        }
    }

    # --- Summary --------------------------------------------------------------------
    if ($script:RestartNeeded) {
        Write-Warning -Message 'A REBOOT is required to finish enabling Windows features.'
    } elseif ($script:LogoffNeeded) {
        Write-Warning -Message "Sign out and back in (or reboot) so $User picks up the new group memberships."
    } else {
        Write-Information -MessageData 'Prerequisites satisfied. Next: .\winkube.ps1 tools'
    }
    if ($script:RestartNeeded -and $Restart) {
        Write-Information -MessageData 'Rebooting in 10 seconds...'
        shutdown.exe /r /t 10 /c 'win-kube prerequisites'
    }
    exit 0
} catch {
    Write-Warning -Message "ERROR: $($_.Exception.Message)"
    # Keep the elevated window open long enough to read the error.
    if ($Host.Name -eq 'ConsoleHost') { Start-Sleep -Seconds 15 }
    exit 1
}
