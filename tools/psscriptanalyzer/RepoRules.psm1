# Custom PSScriptAnalyzer rules for this repo, loaded through CustomRulePath in PSScriptAnalyzerSettings.psd1.
# Every script and every function is advanced and documented, so Get-Help works everywhere and common parameters
# such as -Verbose, -WhatIf and -ErrorAction behave the same. Adapted from windows-nano-demos.

function Get-RepoScriptFileAst {
    <#
    .SYNOPSIS
    Returns the AST when it is the top-level block of a .ps1 script (not a file of function definitions).
    .DESCRIPTION
    PSScriptAnalyzer calls each rule for every script block. Only a file's own top-level block counts, only for .ps1
    files, and not for module function files under src/ that contain nothing but function definitions.
    .PARAMETER ScriptBlockAst
    The block PSScriptAnalyzer passed to the rule.
    .EXAMPLE
    Get-RepoScriptFileAst -ScriptBlockAst $ast
    .OUTPUTS
    System.Management.Automation.Language.ScriptBlockAst
    #>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.Language.ScriptBlockAst])]
    param(
        [System.Management.Automation.Language.ScriptBlockAst]$ScriptBlockAst
    )

    if ($null -ne $ScriptBlockAst.Parent -or $ScriptBlockAst.Extent.File -notlike '*.ps1') {
        return
    }
    $statements = @()
    if ($ScriptBlockAst.EndBlock) {
        $statements = @($ScriptBlockAst.EndBlock.Statements)
    }
    $onlyFunctions = $statements.Count -gt 0 -and @($statements | Where-Object -FilterScript {
            $_ -isnot [System.Management.Automation.Language.FunctionDefinitionAst]
        }).Count -eq 0
    if ($onlyFunctions -and $null -eq $ScriptBlockAst.ParamBlock) {
        return
    }
    $ScriptBlockAst
}

function ConvertTo-RepoDiagnostic {
    <#
    .SYNOPSIS
    Builds an Error-severity diagnostic record.
    .PARAMETER Message
    The finding.
    .PARAMETER Extent
    Where it is.
    .PARAMETER RuleName
    The rule's name.
    .EXAMPLE
    ConvertTo-RepoDiagnostic -Message 'x' -Extent $ast.Extent -RuleName 'PSRepoX'
    .OUTPUTS
    Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord
    #>
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord])]
    param(
        [string]$Message,

        [System.Management.Automation.Language.IScriptExtent]$Extent,

        [string]$RuleName
    )

    [Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord]@{
        Message  = $Message
        Extent   = $Extent
        RuleName = $RuleName
        Severity = 'Error'
    }
}

function Test-RepoCmdletBinding {
    <#
    .SYNOPSIS
    Tests whether a param block has [CmdletBinding()].
    .PARAMETER ParamBlock
    The param block, which may be $null.
    .EXAMPLE
    Test-RepoCmdletBinding -ParamBlock $ast.ParamBlock
    .OUTPUTS
    System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [System.Management.Automation.Language.ParamBlockAst]$ParamBlock
    )

    if ($null -eq $ParamBlock) {
        return $false
    }
    $names = @($ParamBlock.Attributes | ForEach-Object -Process { $_.TypeName.Name })
    @($names -match '^(System\.Management\.Automation\.)?CmdletBinding(Attribute)?$').Count -gt 0
}

<#
.SYNOPSIS
Every script declares [CmdletBinding()] on its param block.
.DESCRIPTION
Advanced scripts get the common parameters and reject misspelled parameters instead of silently ignoring them.
A script without parameters still needs `[CmdletBinding()]` followed by `param()`.
#>
function Measure-ScriptCmdletBinding {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Language.ScriptBlockAst]$ScriptBlockAst
    )

    process {
        $script = Get-RepoScriptFileAst -ScriptBlockAst $ScriptBlockAst
        if (-not $script -or (Test-RepoCmdletBinding -ParamBlock $script.ParamBlock)) {
            return
        }
        $extent = $script.Extent
        if ($script.ParamBlock) {
            $extent = $script.ParamBlock.Extent
        }
        ConvertTo-RepoDiagnostic -RuleName 'PSRepoScriptCmdletBinding' -Extent $extent -Message (
            'Scripts must be advanced scripts: put [CmdletBinding()] before param() ' +
            '(add an empty param() if there are no parameters).')
    }
}

<#
.SYNOPSIS
Every script starts with comment-based help that has a .SYNOPSIS.
.DESCRIPTION
The help block goes at the top of the file, before [CmdletBinding()], so `Get-Help ./script.ps1` shows it.
#>
function Measure-ScriptCommentHelp {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Language.ScriptBlockAst]$ScriptBlockAst
    )

    process {
        $script = Get-RepoScriptFileAst -ScriptBlockAst $ScriptBlockAst
        if (-not $script) {
            return
        }
        $help = $script.GetHelpContent()
        if ($help -and -not [string]::IsNullOrWhiteSpace($help.Synopsis)) {
            return
        }
        $extent = $script.Extent
        if ($script.ParamBlock) {
            $extent = $script.ParamBlock.Extent
        }
        ConvertTo-RepoDiagnostic -RuleName 'PSRepoScriptCommentHelp' -Extent $extent -Message (
            'Scripts must start with comment-based help (<# .SYNOPSIS ... #>) before [CmdletBinding()] and param().')
    }
}

<#
.SYNOPSIS
Every function is an advanced function: [CmdletBinding()] on a param() block.
.DESCRIPTION
Applies to all functions, exported or private, so -Verbose, -ErrorAction and -WhatIf propagate through helpers.
#>
function Measure-FunctionCmdletBinding {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Language.ScriptBlockAst]$ScriptBlockAst
    )

    process {
        $function = $ScriptBlockAst.Parent
        if ($function -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
            return
        }
        if (Test-RepoCmdletBinding -ParamBlock $ScriptBlockAst.ParamBlock) {
            return
        }
        ConvertTo-RepoDiagnostic -RuleName 'PSRepoFunctionCmdletBinding' -Extent $function.Extent -Message (
            "Function '$($function.Name)' must be an advanced function: add [CmdletBinding()] and a param() block.")
    }
}

<#
.SYNOPSIS
Every advanced function declares [OutputType()].
.DESCRIPTION
OutputType documents what a function returns, feeds tab completion and lets PSUseOutputTypeCorrectly check it.
Functions that return nothing declare [OutputType([void])].
#>
function Measure-FunctionOutputType {
    [CmdletBinding()]
    [OutputType([Microsoft.Windows.PowerShell.ScriptAnalyzer.Generic.DiagnosticRecord[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Management.Automation.Language.ScriptBlockAst]$ScriptBlockAst
    )

    process {
        $function = $ScriptBlockAst.Parent
        if ($function -isnot [System.Management.Automation.Language.FunctionDefinitionAst]) {
            return
        }
        $attributes = @()
        if ($ScriptBlockAst.ParamBlock) {
            $attributes = @($ScriptBlockAst.ParamBlock.Attributes | ForEach-Object -Process { $_.TypeName.Name })
        }
        if (@($attributes -match '^(System\.Management\.Automation\.)?OutputType(Attribute)?$').Count -gt 0) {
            return
        }
        ConvertTo-RepoDiagnostic -RuleName 'PSRepoFunctionOutputType' -Extent $function.Extent -Message (
            "Function '$($function.Name)' must declare [OutputType()] ([OutputType([void])] if it returns nothing).")
    }
}

Export-ModuleMember -Function 'Measure-*'
