function Enable-WinKubeHyperVIsolation {
    <#
    .SYNOPSIS
    Enables Hyper-V isolated containers on the Windows node, so older (ltsc2022) images can run on it.
    .DESCRIPTION
    Installs the Hyper-V role inside the Windows node, adds a runhcs-wcow-hypervisor containerd runtime handler
    with SandboxIsolation = 1 next to the default process-isolation handler, and creates RuntimeClass
    windows-hyperv. If the role had to be installed, the node VM is power-cycled through Hyper-V (with dynamic
    memory turned off) and the cmdlet waits for the node to be Ready again. See ADR 0005.

    The node VM must expose virtualization extensions, which minikube sets when -CpuCount is 2 or more.
    .PARAMETER ClusterProfile
    The minikube profile. Defaults to winkube.
    .EXAMPLE
    Enable-WinKubeHyperVIsolation

    Prepares the winkube cluster's Windows node for ltsc2022 images.
    .EXAMPLE
    Enable-WinKubeHyperVIsolation -WhatIf

    Shows what would change without touching the node.
    .OUTPUTS
    None
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCompatibleCommands', 'Get-WindowsFeature',
        Justification = 'Runs on the Windows Server node through Invoke-WinKubeWindowsNode, not on the client.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseCompatibleCommands', 'Install-WindowsFeature',
        Justification = 'Runs on the Windows Server node through Invoke-WinKubeWindowsNode, not on the client.')]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    [OutputType([void])]
    param(
        [ValidateNotNullOrEmpty()]
        [Alias('Profile')]
        [string]$ClusterProfile = $script:DefaultClusterProfile
    )

    Assert-WinKubeHyperV
    $node = Get-WinKubeWindowsNode -ClusterProfile $ClusterProfile
    $vm = Get-VM -Name $node.Machine
    if (-not (Get-VMProcessor -VMName $vm.Name).ExposeVirtualizationExtensions) {
        throw ("VM $($vm.Name) does not expose virtualization extensions. Recreate the cluster with " +
            'New-WinKubeCluster -Isolation hyperv.')
    }
    if (-not $PSCmdlet.ShouldProcess($node.Name, 'Install the Hyper-V role and a Hyper-V isolation runtime handler')) {
        return
    }

    Write-WinKubeStep -Message "Configuring Hyper-V isolation on $($node.Name)"
    $result = Invoke-WinKubeWindowsNode -Node $node -ArgumentList $script:HyperVRuntimeHandler -ScriptBlock {
        param($Handler)
        $restart = $false
        if ((Get-WindowsFeature -Name 'Hyper-V').InstallState -ne 'Installed') {
            $install = Install-WindowsFeature -Name 'Hyper-V'
            if (-not $install.Success) {
                throw 'Install-WindowsFeature Hyper-V failed'
            }
            $restart = $true
        }
        $config = Join-Path -Path $env:ProgramFiles -ChildPath 'containerd\config.toml'
        $toml = [IO.File]::ReadAllText($config)
        if ($toml -notmatch [regex]::Escape($Handler)) {
            # Match whatever config schema (v2 or v3) the node uses by copying the process handler's table prefix
            # The handler name may be bare, single-quoted or double-quoted in the table header
            $pattern = '\[([^\]]*containerd\.runtimes)\.(?:runhcs-wcow-process|''runhcs-wcow-process''|' +
            '"runhcs-wcow-process")\]'
            $match = [regex]::Match($toml, $pattern)
            if (-not $match.Success) {
                throw "No runhcs-wcow-process runtime found in $config"
            }
            $prefix = $match.Groups[1].Value
            $toml += "`r`n[$prefix.$Handler]`r`n  runtime_type = 'io.containerd.runhcs.v1'`r`n" +
            "  [$prefix.$Handler.options]`r`n    SandboxIsolation = 1`r`n    ScaleCpuLimitsToSandbox = true`r`n"
            [IO.File]::WriteAllText($config, $toml, (New-Object -TypeName Text.ASCIIEncoding))
            if (-not $restart) {
                Restart-Service -Name 'containerd'
            }
        }
        if ($restart) {
            'RESTART_REQUIRED'
        } else {
            'OK'
        }
    }

    if (($result -join "`n") -match 'RESTART_REQUIRED') {
        Write-WinKubeStep -Message "Restarting VM $($vm.Name) to finish installing the Hyper-V role"
        Stop-VM -Name $vm.Name -Force
        if ((Get-VMMemory -VMName $vm.Name).DynamicMemoryEnabled) {
            # Nested virtualization needs static memory
            Set-VMMemory -VMName $vm.Name -DynamicMemoryEnabled $false
        }
        Start-VM -Name $vm.Name
        # The role install reboots the guest again on its own; wait until it settles
        $deadline = (Get-Date).AddMinutes(20)
        $ready = $false
        while ((Get-Date) -lt $deadline -and -not $ready) {
            Start-Sleep -Seconds 20
            try {
                $node = Get-WinKubeWindowsNode -ClusterProfile $ClusterProfile
                $state = Invoke-WinKubeWindowsNode -Node $node -ScriptBlock {
                    $role = (Get-WindowsFeature -Name 'Hyper-V').InstallState
                    if ($role -eq 'Installed' -and (Get-Service -Name 'containerd').Status -eq 'Running') {
                        'READY'
                    }
                }
                $ready = ($state -join '') -match 'READY'
            } catch {
                Write-Verbose -Message "Waiting for the Windows node to come back: $_"
            }
        }
        if (-not $ready) {
            throw 'Timed out waiting for the Windows node after enabling Hyper-V.'
        }
        Invoke-WinKubeKubectl -ClusterProfile $ClusterProfile -ArgumentList @(
            'wait', '--for=condition=Ready', "node/$($node.Name)", '--timeout=10m'
        )
    }

    $runtimeClass = @"
apiVersion: node.k8s.io/v1
kind: RuntimeClass
metadata:
  name: $script:HyperVRuntimeClass
handler: $script:HyperVRuntimeHandler
scheduling:
  nodeSelector:
    kubernetes.io/os: windows
  tolerations:
    - key: os
      operator: Equal
      value: windows
      effect: NoSchedule
"@
    $manifest = Join-Path -Path $script:CacheDir -ChildPath 'runtimeclass-hyperv.yaml'
    New-Item -ItemType Directory -Force -Path $script:CacheDir | Out-Null
    Set-Content -LiteralPath $manifest -Value $runtimeClass -Encoding Ascii
    Invoke-WinKubeKubectl -ClusterProfile $ClusterProfile -ArgumentList @('apply', '-f', $manifest)
    Write-Verbose -Message "RuntimeClass '$script:HyperVRuntimeClass' uses handler '$script:HyperVRuntimeHandler'"
}
