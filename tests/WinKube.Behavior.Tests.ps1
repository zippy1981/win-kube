#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

<#
.SYNOPSIS
Behaviour tests for the WinKube cmdlets with every native command mocked.
.DESCRIPTION
minikube, kubectl, helm, docker, ssh and scp are reached only through private functions, which these tests mock
inside the module, so they run without a cluster under Windows PowerShell 5.1 and PowerShell 7 on any OS.
#>
[CmdletBinding()]
param()

BeforeAll {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath '../src/WinKube/WinKube.psd1') -Force

    # kubectl get nodes -l kubernetes.io/os=windows for a ltsc2025 node
    $script:windowsNodesJson = @'
{"items": [{"metadata": {"name": "winkube-m02", "labels": {"kubernetes.io/os": "windows",
 "node.kubernetes.io/windows-build": "10.0.26100"}},
 "status": {"addresses": [{"type": "Hostname", "address": "win"}, {"type": "InternalIP", "address": "172.20.0.12"}]}}]}
'@
}

Describe 'Get-WinKubeWindowsNode' {
    BeforeAll {
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeMinikubePath' -MockWith { 'minikube.exe' }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeToolPath' -MockWith { 'kubectl.exe' }
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -MockWith {
            if ($FilePath -eq 'kubectl.exe') {
                $script:windowsNodesJson
            } else {
                "winkube`t172.20.0.11", "winkube-m02`t172.20.0.12"
            }
        }
    }

    It 'matches the Kubernetes node to its minikube machine by IP' {
        $node = Get-WinKubeWindowsNode
        $node.Name | Should -Be 'winkube-m02'
        $node.IP | Should -Be '172.20.0.12'
        $node.Machine | Should -Be 'winkube-m02'
        $node.ClusterProfile | Should -Be 'winkube'
        $node.PSObject.TypeNames | Should -Contain 'WinKube.WindowsNode'
    }

    It 'derives the Windows Server release from the build label' {
        $node = Get-WinKubeWindowsNode
        $node.Build | Should -Be '10.0.26100'
        $node.Release | Should -Be '2025'
    }

    It 'throws when there is no Windows node' {
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -MockWith { '{"items": []}' }
        { Get-WinKubeWindowsNode -ClusterProfile 'demo' } | Should -Throw "*No Windows node found in cluster 'demo'*"
    }
}

Describe 'New-WinKubeCluster' {
    BeforeAll {
        Mock -ModuleName 'WinKube' -CommandName 'Assert-WinKubeHyperV' -MockWith { }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeMinikubePath' -MockWith { 'minikube.exe' }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeToolPath' -MockWith { 'kubectl.exe' }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeFreeMemoryMB' -MockWith { 32768 }
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -MockWith { }
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeKubectl' -MockWith { }
        Mock -ModuleName 'WinKube' -CommandName 'Add-WinKubeAksNodeLabel' -MockWith { }
        Mock -ModuleName 'WinKube' -CommandName 'Enable-WinKubeHyperVIsolation' -MockWith { }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeCluster' -MockWith {
            [pscustomobject]@{ PSTypeName = 'WinKube.Cluster'; ClusterProfile = $ClusterProfile }
        }
    }

    It 'starts one Linux control plane and one Windows worker on Hyper-V' {
        New-WinKubeCluster | Out-Null
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 1 -Exactly -ParameterFilter {
            $line = $ArgumentList -join ' '
            $FilePath -eq 'minikube.exe' -and
            $line -like 'start -p winkube --driver=hyperv*' -and
            $line -like '*--node role=control-plane --node role=worker,os=windows*' -and
            $line -like '*--kubernetes-version=v1.37.0 --cpus=4 --memory=6144*' -and
            $line -notlike '*--hyperv-disable-dynamic-memory*'
        }
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Add-WinKubeAksNodeLabel' -Times 1 -Exactly
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Enable-WinKubeHyperVIsolation' -Times 0 -Exactly
    }

    It 'uses static memory and enables Hyper-V isolation with -Isolation hyperv' {
        New-WinKubeCluster -ClusterProfile 'iso' -Isolation 'hyperv' -CpuCount 2 -MemoryMB 8192 | Out-Null
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 1 -Exactly -ParameterFilter {
            $line = $ArgumentList -join ' '
            $line -like 'start -p iso *' -and $line -like '*--cpus=2 --memory=8192*' -and
            $line -like '*--hyperv-disable-dynamic-memory*'
        }
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Enable-WinKubeHyperVIsolation' -Times 1 -Exactly
    }

    It 'passes a custom VHD through' {
        New-WinKubeCluster -WindowsVhdUrl 'C:\vhd\node.vhdx' | Out-Null
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 1 -Exactly -ParameterFilter {
            $ArgumentList -contains '--windows-vhd-url=C:\vhd\node.vhdx'
        }
    }

    It 'does nothing with -WhatIf' {
        New-WinKubeCluster -WhatIf | Out-Null
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 0 -Exactly
    }

    It 'rejects a Kubernetes version that is not vX.Y.Z' {
        { New-WinKubeCluster -KubernetesVersion '1.37' } | Should -Throw
    }
}

Describe 'Remove-WinKubeCluster' {
    BeforeAll {
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeMinikubePath' -MockWith { 'minikube.exe' }
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -MockWith { }
    }

    It 'runs minikube delete for the profile' {
        Remove-WinKubeCluster -ClusterProfile 'demo' -Confirm:$false
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 1 -Exactly -ParameterFilter {
            ($ArgumentList -join ' ') -eq 'delete -p demo'
        }
    }

    It 'does nothing with -WhatIf' {
        Remove-WinKubeCluster -WhatIf
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 0 -Exactly
    }
}

Describe 'Install-WinKubeChart' {
    BeforeAll {
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeToolPath' -MockWith { "$Name.exe" }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeWindowsNode' -MockWith {
            [pscustomobject]@{
                PSTypeName = 'WinKube.WindowsNode'; Name = 'winkube-m02'; IP = '172.20.0.12'; Build = '10.0.26100'
                Release = '2025'; Machine = 'winkube-m02'; ClusterProfile = 'winkube'
            }
        }
        Mock -ModuleName 'WinKube' -CommandName 'Import-WinKubeImage' -MockWith { }
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -MockWith { }
        Mock -ModuleName 'WinKube' -CommandName 'Test-WinKubeNative' -MockWith { $false }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeKubectlJson' -MockWith {
            if ($ArgumentList -contains 'svc') {
                '{"items": [{"spec": {"type": "NodePort", "ports": [{"nodePort": 31080}]}}]}' | ConvertFrom-Json
            } else {
                # 'hunter2' base64-encoded, as Kubernetes stores Secret data
                '{"items": [{"data": {"wordpress-admin-password": "aHVudGVyMg=="}}]}' | ConvertFrom-Json
            }
        }
    }

    It 'side-loads the sample images and runs helm with the Windows versions' {
        $result = Install-WinKubeChart
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Import-WinKubeImage' -Times 1 -Exactly -ParameterFilter {
            ($Image -join ',') -eq 'windows-nano-php:2025,mysql-spike:2025'
        }
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 1 -Exactly -ParameterFilter {
            $line = $ArgumentList -join ' '
            $FilePath -eq 'helm.exe' -and $line -like 'upgrade --install wp *wordpress-windows*' -and
            $line -like '*--set windows.version=2025 --set windows.nodeVersion=2025*' -and
            $line -like '*--wait --timeout 30m*'
        }
        $result.Url | Should -Be @('http://172.20.0.12:31080/')
        $result.Credential.UserName | Should -Be 'admin'
        $result.Credential.GetNetworkCredential().Password | Should -Be 'hunter2'
    }

    It 'passes extra --set values through' {
        Install-WinKubeChart -Set 'install.title=Demo', 'wordpress.debug=true' -SkipImageLoad | Out-Null
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Import-WinKubeImage' -Times 0 -Exactly
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 1 -Exactly -ParameterFilter {
            ($ArgumentList -join ' ') -like '*--set install.title=Demo --set wordpress.debug=true'
        }
    }

    It 'refuses ltsc2022 images on a 2025 node without the Hyper-V runtime class' {
        { Install-WinKubeChart -WindowsVersion '2022' } | Should -Throw '*Enable-WinKubeHyperVIsolation*'
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 0 -Exactly
    }

    It 'deploys ltsc2022 images once the Hyper-V runtime class exists' {
        Mock -ModuleName 'WinKube' -CommandName 'Test-WinKubeNative' -MockWith { $true }
        Install-WinKubeChart -WindowsVersion '2022' | Out-Null
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Import-WinKubeImage' -Times 1 -Exactly -ParameterFilter {
            ($Image -join ',') -eq 'windows-nano-php:2022,mysql-spike:2022'
        }
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 1 -Exactly -ParameterFilter {
            ($ArgumentList -join ' ') -like '*--set windows.version=2022 --set windows.nodeVersion=2025*'
        }
    }
}

Describe 'Import-WinKubeImage' {
    BeforeAll {
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeToolPath' -MockWith { 'docker.exe' }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeWindowsNode' -MockWith {
            [pscustomobject]@{ PSTypeName = 'WinKube.WindowsNode'; Name = 'winkube-m02'; IP = '172.20.0.12' }
        }
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -MockWith { 'sha256:abc' }
        Mock -ModuleName 'WinKube' -CommandName 'Copy-WinKubeFileToWindowsNode' -MockWith { }
    }

    It 'skips an image the node already has' {
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeWindowsNode' -MockWith { 'PRESENT' }
        $result = Import-WinKubeImage -Image 'app:2025'
        $result.Status | Should -Be 'AlreadyPresent'
        $result.ImageId | Should -Be 'sha256:abc'
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Copy-WinKubeFileToWindowsNode' -Times 0 -Exactly
    }

    It 'defaults to the sample images for the Windows version, from the pipeline or not' {
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeWindowsNode' -MockWith { 'PRESENT' }
        (Import-WinKubeImage -WindowsVersion '2022').Image | Should -Be @('windows-nano-php:2022', 'mysql-spike:2022')
        ('a:1', 'b:1' | Import-WinKubeImage).Image | Should -Be @('a:1', 'b:1')
    }
}

Describe 'Invoke-WinKubeWindowsNode' {
    BeforeAll {
        $script:node = [pscustomobject]@{ PSTypeName = 'WinKube.WindowsNode'; Name = 'n'; IP = '172.20.0.12' }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeSshArgument' -MockWith { '-i', 'key' }
        Mock -ModuleName 'WinKube' -CommandName 'Copy-WinKubeFileToWindowsNode' -MockWith { }
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -MockWith { 'remote output' }
    }

    It 'runs the script on the node through Windows PowerShell without cmd.exe metacharacters' {
        $output = $script:node | Invoke-WinKubeWindowsNode -ArgumentList 'C:\k', "it's" -ScriptBlock {
            param($Path, $Word)
            Get-ChildItem -Path $Path -Filter $Word
        }
        $output | Should -Be 'remote output'
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -Times 1 -Exactly -ParameterFilter {
            $remote = $ArgumentList[-1]
            $remote -like 'powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command *' -and
            $remote -like "*. 'C:\Windows\Temp\winkube\remote-*.ps1' 'C:\k' 'it''s' *" -and
            $remote -notmatch '[&|<>^%"]'
        }
        Should -Invoke -ModuleName 'WinKube' -CommandName 'Copy-WinKubeFileToWindowsNode' -Times 1 -Exactly
    }

    It 'rejects arguments that cmd.exe would interpret' {
        foreach ($bad in @('a & b', '%PATH%')) {
            { $script:node | Invoke-WinKubeWindowsNode -ArgumentList $bad -ScriptBlock { } } |
                Should -Throw '*may not contain*'
        }
    }
}

Describe 'Get-WinKubeCluster' {
    BeforeAll {
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeMinikubePath' -MockWith { 'minikube.exe' }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeToolPath' -MockWith { "$Name.exe" }
    }

    It 'reports a stopped cluster without calling kubectl' {
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -MockWith {
            '[{"Name": "winkube", "Host": "Stopped", "APIServer": "Stopped"},' +
            ' {"Name": "winkube-m02", "Host": "Stopped"}]'
        }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeKubectlJson' -MockWith { throw 'should not be called' }
        $cluster = Get-WinKubeCluster
        $cluster.Running | Should -BeFalse
        @($cluster.Status).Count | Should -Be 2
        @($cluster.Nodes).Count | Should -Be 0
    }

    It 'lists nodes with their AKS-style labels when the API server is running' {
        Mock -ModuleName 'WinKube' -CommandName 'Invoke-WinKubeNative' -MockWith {
            if ($FilePath -eq 'minikube.exe') {
                '{"Name": "winkube", "Host": "Running", "APIServer": "Running"}'
            } else {
                '[]'
            }
        }
        Mock -ModuleName 'WinKube' -CommandName 'Get-WinKubeKubectlJson' -MockWith {
            if ($ArgumentList -contains 'nodes') {
                '{"items": [{"metadata": {"name": "winkube-m02", "labels": {"kubernetes.io/os": "windows",
                  "agentpool": "win", "kubernetes.azure.com/os-sku": "Windows2025"}},
                  "status": {"conditions": [{"type": "Ready", "status": "True"}],
                  "addresses": [{"type": "InternalIP", "address": "172.20.0.12"}],
                  "nodeInfo": {"kubeletVersion": "v1.37.0"}}}]}' | ConvertFrom-Json
            } else {
                '{"items": [{"metadata": {"name": "windows-hyperv"}}]}' | ConvertFrom-Json
            }
        }
        $cluster = Get-WinKubeCluster
        $cluster.Running | Should -BeTrue
        $cluster.Nodes[0].Name | Should -Be 'winkube-m02'
        $cluster.Nodes[0].Ready | Should -BeTrue
        $cluster.Nodes[0].OsSku | Should -Be 'Windows2025'
        $cluster.Nodes[0].AgentPool | Should -Be 'win'
        $cluster.RuntimeClass | Should -Be @('windows-hyperv')
    }
}
