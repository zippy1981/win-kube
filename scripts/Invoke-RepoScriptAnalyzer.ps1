#Requires -Version 5.1

<#
.SYNOPSIS
Runs PSScriptAnalyzer with the repo's settings over the repo's PowerShell files.

.DESCRIPTION
Uses PSScriptAnalyzerSettings.psd1, including the custom rules in tools/psscriptanalyzer/RepoRules.psm1. With no
-Path, analyzes every .ps1, .psm1 and .psd1 file tracked by git, so .venv, .tools and worktrees are skipped; the
pre-commit hook passes the staged files instead. Prints one line per finding (a GitHub annotation when run in
Actions) and fails if there are any. Adapted from windows-nano-demos.

.PARAMETER Path
Files to analyze, relative to the repository root. Defaults to every tracked PowerShell file.

.PARAMETER Root
The repository root. Defaults to the parent of this script's folder.

.EXAMPLE
./scripts/Invoke-RepoScriptAnalyzer.ps1

Analyzes every tracked PowerShell file.

.EXAMPLE
./scripts/Invoke-RepoScriptAnalyzer.ps1 winkube.ps1 src/WinKube/WinKube.psm1

Analyzes two files, as the pre-commit hook does.
#>
# Only -Path takes unnamed arguments, so the pre-commit hook's file list never binds to -Root
[CmdletBinding(PositionalBinding = $false)]
param(
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$Path = @(),

    [string]$Root = (Split-Path -Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'
Import-Module -Name PSScriptAnalyzer -MinimumVersion 1.25.0

Push-Location -LiteralPath $Root
try {
    $files = @($Path | Where-Object -FilterScript { $_ -match '\.(ps1|psm1|psd1)$' })
    if ($Path.Count -eq 0) {
        $files = @(& git ls-files -- '*.ps1' '*.psm1' '*.psd1')
        if ($LASTEXITCODE -ne 0) {
            throw 'git ls-files failed; run this from a git checkout or pass -Path.'
        }
    }
    $settings = Import-PowerShellDataFile -Path (Join-Path -Path $Root -ChildPath 'PSScriptAnalyzerSettings.psd1')
    # Pester's DSL (Describe, It, Should, Mock) isn't in PSScriptAnalyzer's compatibility profiles. Test files are
    # checked for 5.1 and 7 compatibility by running them under both editions in CI instead.
    $testSettings = $settings.Clone()
    $testSettings['ExcludeRules'] = @($settings['ExcludeRules']) + @('PSUseCompatibleCommands', 'PSUseCompatibleTypes')
    $results = @(foreach ($file in $files) {
            $fileSettings = $settings
            if ($file -like '*.Tests.ps1') {
                $fileSettings = $testSettings
            }
            # The compatibility rules occasionally throw a NullReferenceException when their profiles load
            # concurrently; a retry of the same file succeeds, so try up to three times before failing.
            $attempt = 0
            while ($true) {
                $attempt++
                try {
                    Invoke-ScriptAnalyzer -Path $file -Settings $fileSettings -ErrorAction Stop
                    break
                } catch [System.NullReferenceException] {
                    if ($attempt -ge 3) {
                        throw
                    }
                    Write-Verbose -Message "Retrying $file after: $($_.Exception.Message)"
                }
            }
        })
} finally {
    Pop-Location
}

$rootPrefix = (Resolve-Path -LiteralPath $Root).Path.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
foreach ($result in $results) {
    $file = $result.ScriptPath
    if ($file.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        $file = $file.Substring($rootPrefix.Length)
    }
    $file = $file -replace '\\', '/'
    if ($env:GITHUB_ACTIONS) {
        $location = "file=$file,line=$($result.Line),col=$($result.Column),title=$($result.RuleName)"
        Write-Output -InputObject "::error ${location}::$($result.Message)"
    } else {
        Write-Output -InputObject "${file}:$($result.Line): $($result.RuleName): $($result.Message)"
    }
}
if ($results.Count -gt 0) {
    throw "PSScriptAnalyzer: $($results.Count) finding(s) in $($files.Count) files"
}
Write-Output -InputObject "PSScriptAnalyzer: no findings in $($files.Count) files"
