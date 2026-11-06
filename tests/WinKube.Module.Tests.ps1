#Requires -Modules @{ ModuleName = 'Pester'; ModuleVersion = '5.5.0' }

<#
.SYNOPSIS
Contract tests for the WinKube module: manifest, exports, naming, help and ShouldProcess.
.DESCRIPTION
These need no cluster, Hyper-V or docker and run under Windows PowerShell 5.1 and PowerShell 7 on any OS.
#>
[CmdletBinding()]
param()

BeforeDiscovery {
    $manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/WinKube/WinKube.psd1'
    Import-Module -Name $manifestPath -Force
    $script:exported = @(Get-Command -Module 'WinKube' | ForEach-Object -Process { @{ Name = $_.Name } })
}

BeforeAll {
    $script:manifestPath = Join-Path -Path $PSScriptRoot -ChildPath '../src/WinKube/WinKube.psd1'
    $script:publicDir = Join-Path -Path $PSScriptRoot -ChildPath '../src/WinKube/Public'
    Import-Module -Name $script:manifestPath -Force
    $script:commonParameters = @(
        [System.Management.Automation.PSCmdlet]::CommonParameters +
        [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
    )
}

Describe 'WinKube manifest' {
    It 'is a valid manifest for Windows PowerShell 5.1 and PowerShell 7' {
        $manifest = Test-ModuleManifest -Path $script:manifestPath
        $manifest.PowerShellVersion | Should -Be ([version]'5.1')
        $manifest.CompatiblePSEditions | Should -Be @('Desktop', 'Core')
    }

    It 'exports exactly the functions in Public/' {
        $files = @(Get-ChildItem -Path $script:publicDir -Filter '*.ps1' | ForEach-Object -Process { $_.BaseName })
        $exports = @((Test-ModuleManifest -Path $script:manifestPath).ExportedFunctions.Keys)
        ($exports | Sort-Object) | Should -Be ($files | Sort-Object)
        (@(Get-Command -Module 'WinKube').Name | Sort-Object) | Should -Be ($files | Sort-Object)
    }

    It 'exports no cmdlets, variables or aliases' {
        $manifest = Test-ModuleManifest -Path $script:manifestPath
        $manifest.ExportedCmdlets.Count | Should -Be 0
        $manifest.ExportedVariables.Count | Should -Be 0
        $manifest.ExportedAliases.Count | Should -Be 0
    }
}

Describe '<Name>' -ForEach $script:exported {
    BeforeAll {
        $script:command = Get-Command -Name $Name -Module 'WinKube'
        $script:help = Get-Help -Name $Name -Full
    }

    It 'uses an approved verb and the WinKube noun prefix' {
        (Get-Verb).Verb | Should -Contain $script:command.Verb
        $script:command.Noun | Should -BeLike 'WinKube*'
    }

    It 'is an advanced function with an OutputType' {
        $script:command.CmdletBinding | Should -BeTrue
        $script:command.OutputType.Count | Should -BeGreaterThan 0
    }

    It 'has a synopsis, a description and at least one example' {
        $script:help.Synopsis | Should -Not -BeNullOrEmpty
        # Without comment-based help, Get-Help falls back to the syntax line as the synopsis
        $script:help.Synopsis | Should -Not -Match ([regex]::Escape($Name) + '\s+\[')
        ($script:help.Description | Out-String).Trim() | Should -Not -BeNullOrEmpty
        @($script:help.Examples.Example).Count | Should -BeGreaterThan 0
    }

    It 'documents every parameter' {
        $documented = @{}
        foreach ($parameter in @($script:help.Parameters.Parameter)) {
            if ($parameter -and ($parameter.Description | Out-String).Trim()) {
                $documented[$parameter.Name] = $true
            }
        }
        foreach ($parameter in $script:command.Parameters.Keys) {
            if ($script:commonParameters -notcontains $parameter) {
                $documented.ContainsKey($parameter) | Should -BeTrue -Because "-$parameter needs a .PARAMETER entry"
            }
        }
    }

    It 'supports -WhatIf when it changes state' {
        $changesState = $script:command.Verb -in @('New', 'Remove', 'Install', 'Enable', 'Import', 'Set')
        if ($changesState) {
            $script:command.Parameters.Keys | Should -Contain 'WhatIf'
        }
    }

    It 'takes -ClusterProfile with the Profile alias when it targets a cluster' {
        if ($script:command.Parameters.ContainsKey('ClusterProfile')) {
            $script:command.Parameters['ClusterProfile'].Aliases | Should -Contain 'Profile'
        }
    }
}
