#Requires -Version 5.1

<#
.SYNOPSIS
Generates the WinKube cmdlet reference in docs/cmdlets from the module's comment-based help, or checks it is current.

.DESCRIPTION
Runs Microsoft.PowerShell.PlatyPS New-MarkdownCommandHelp for the WinKube module, then normalizes the output so it
is stable and passes markdownlint: LF line endings, no ms.date (which changes every day), no unfilled
{{ placeholder }} lines, a `text` language on bare code fences, and single blank lines. With -Check nothing is
written; the script fails if docs/cmdlets differs from what the help would generate, which is how CI catches help
changes without regenerated docs.

.PARAMETER Check
Compare instead of writing, and throw if docs/cmdlets is out of date.

.PARAMETER Root
The repository root. Defaults to the parent of this script's folder.

.EXAMPLE
./scripts/Update-WinKubeCmdletDoc.ps1

Regenerates docs/cmdlets after changing a cmdlet's help or parameters.

.EXAMPLE
./scripts/Update-WinKubeCmdletDoc.ps1 -Check

Fails when docs/cmdlets is stale, as the cmdlet-docs CI job does.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [switch]$Check,

    [string]$Root = (Split-Path -Path $PSScriptRoot -Parent)
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function ConvertTo-StableMarkdown {
    <#
    .SYNOPSIS
    Normalizes one PlatyPS Markdown file.
    .PARAMETER Text
    The generated Markdown.
    .EXAMPLE
    ConvertTo-StableMarkdown -Text (Get-Content -Raw -Path New-WinKubeCluster.md)
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )

    $lines = New-Object -TypeName System.Collections.Generic.List[string]
    $headings = @{}
    $inFence = $false
    foreach ($line in ($Text -replace "`r`n", "`n") -split "`n") {
        if (-not $inFence) {
            if ($line -match '^#{1,6} ') {
                # PlatyPS can list an output type twice (from .OUTPUTS and [OutputType()]); keep the first (MD024)
                if ($headings.ContainsKey($line)) {
                    continue
                }
                $headings[$line] = $true
            } elseif ($line.Trim().Length -gt 0 -and $lines.Count -gt 0 -and
                $lines[$lines.Count - 1] -match '^#{1,6} ') {
                # A heading needs a blank line below it (MD022)
                $lines.Add('')
            }
            # ms.date changes daily; markdownlint counts a front-matter title as a second H1 (MD025)
            if ($line -match '^(ms\.date|title):' -or $line -match '^\s*\{\{.*\}\}\s*$' -or
                $line -match '^This cmdlet has the following aliases,\s*$') {
                continue
            }
            if ($line.Trim().Length -eq 0 -and $lines.Count -gt 0 -and $lines[$lines.Count - 1].Trim().Length -eq 0) {
                continue
            }
        }
        if ($line -match '^```') {
            if (-not $inFence -and $line -eq '```') {
                $line = '```text'
            }
            $inFence = -not $inFence
        }
        $lines.Add($line.TrimEnd())
    }
    (($lines -join "`n").Trim()) + "`n"
}

Import-Module -Name Microsoft.PowerShell.PlatyPS -MinimumVersion 1.0.0
$module = Import-Module -Name (Join-Path -Path $Root -ChildPath 'src/WinKube/WinKube.psd1') -Force -PassThru
$temp = Join-Path -Path ([IO.Path]::GetTempPath()) -ChildPath ('winkube-docs-' + [guid]::NewGuid().ToString('N'))
$target = Join-Path -Path $Root -ChildPath 'docs/cmdlets'

try {
    # PlatyPS reads optional help properties that don't exist on every command, which strict mode turns into errors
    Set-StrictMode -Off
    New-MarkdownCommandHelp -ModuleInfo $module -OutputFolder $temp -WithModulePage -Force | Out-Null
    Set-StrictMode -Version 2.0
    $generated = @{}
    foreach ($file in (Get-ChildItem -Path (Join-Path -Path $temp -ChildPath 'WinKube') -Filter '*.md')) {
        $generated[$file.Name] = ConvertTo-StableMarkdown -Text ([IO.File]::ReadAllText($file.FullName))
    }
} finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}

$existing = @{}
if (Test-Path -LiteralPath $target) {
    foreach ($file in (Get-ChildItem -Path $target -Filter '*.md')) {
        $existing[$file.Name] = [IO.File]::ReadAllText($file.FullName) -replace "`r`n", "`n"
    }
}

$stale = @()
foreach ($name in $generated.Keys) {
    if (-not $existing.ContainsKey($name) -or $existing[$name] -ne $generated[$name]) {
        $stale += $name
    }
}
$extra = @($existing.Keys | Where-Object -FilterScript { -not $generated.ContainsKey($_) })

if ($Check) {
    if ($stale.Count -gt 0 -or $extra.Count -gt 0) {
        foreach ($name in ($stale + $extra | Sort-Object)) {
            Write-Output -InputObject "docs/cmdlets/$name is out of date"
            if ($existing.ContainsKey($name) -and $generated.ContainsKey($name)) {
                # Show what differs, so platform differences can be diagnosed from the CI log
                $differences = Compare-Object -ReferenceObject ($existing[$name] -split "`n") `
                    -DifferenceObject ($generated[$name] -split "`n") -SyncWindow 0 | Select-Object -First 20
                foreach ($difference in $differences) {
                    $side = 'committed'
                    if ($difference.SideIndicator -eq '=>') {
                        $side = 'generated'
                    }
                    Write-Output -InputObject "    ${side}: $($difference.InputObject)"
                }
            }
        }
        throw 'Cmdlet docs are stale. Run ./scripts/Update-WinKubeCmdletDoc.ps1 and commit docs/cmdlets.'
    }
    Write-Output -InputObject "docs/cmdlets is up to date ($($generated.Count) files)"
    return
}

if ($PSCmdlet.ShouldProcess($target, 'Write cmdlet docs')) {
    New-Item -ItemType Directory -Force -Path $target | Out-Null
    $utf8NoBom = New-Object -TypeName Text.UTF8Encoding -ArgumentList $false
    foreach ($name in ($generated.Keys | Sort-Object)) {
        [IO.File]::WriteAllText((Join-Path -Path $target -ChildPath $name), $generated[$name], $utf8NoBom)
    }
    foreach ($name in $extra) {
        Remove-Item -LiteralPath (Join-Path -Path $target -ChildPath $name)
    }
    Write-Output -InputObject "Wrote $($generated.Count) files to docs/cmdlets ($($stale.Count) changed)"
}
