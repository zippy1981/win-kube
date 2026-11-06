# PSScriptAnalyzer settings for every PowerShell file in this repo. CI runs them through
# scripts/Invoke-RepoScriptAnalyzer.ps1 (.github/workflows/powershell.yml), and so does the pre-commit hook.
# VS Code's PowerShell extension picks this file up from the repo root, and Invoke-Formatter accepts it to fix the
# formatting rules automatically.
@{
    # Every severity: Information findings (help, casing, quoting style) fail the build too
    Severity            = @('Error', 'Warning', 'Information')
    IncludeDefaultRules = $true
    # Scripts and functions are advanced and documented; see the rule help in the module
    CustomRulePath      = @('./tools/psscriptanalyzer/RepoRules.psm1')
    ExcludeRules        = @()
    Rules               = @{
        # Formatting: OTBS braces, 4-space indentation, consistent whitespace and aligned assignments
        PSPlaceOpenBrace                          = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSPlaceCloseBrace                         = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSUseConsistentIndentation                = @{
            Enable              = $true
            Kind                = 'space'
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
        }
        PSUseConsistentWhitespace                 = @{
            Enable                                  = $true
            CheckInnerBrace                         = $true
            CheckOpenBrace                          = $true
            CheckOpenParen                          = $true
            CheckOperator                           = $true
            CheckPipe                               = $true
            CheckPipeForRedundantWhitespace         = $true
            CheckSeparator                          = $true
            CheckParameter                          = $true
            IgnoreAssignmentOperatorInsideHashTable = $true
        }
        PSAlignAssignmentStatement                = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSUseCorrectCasing                        = @{
            Enable = $true
        }
        PSAvoidLongLines                          = @{
            Enable            = $true
            MaximumLineLength = 120
        }
        PSAvoidSemicolonsAsLineTerminators        = @{
            Enable = $true
        }
        PSAvoidUsingDoubleQuotesForConstantString = @{
            Enable = $true
        }
        PSAvoidExclaimOperator                    = @{
            Enable = $true
        }
        PSAvoidUsingCmdletAliases                 = @{
            allowlist = @()
        }

        # Comment-based help on every function, exported or not, before its body
        PSProvideCommentHelp                      = @{
            Enable                  = $true
            ExportedOnly            = $false
            BlockComment            = $true
            VSCodeSnippetCorrection = $false
            Placement               = 'begin'
        }

        # Windows PowerShell 5.1 and PowerShell 7 on Windows (ADR 0007)
        PSUseCompatibleSyntax                     = @{
            Enable         = $true
            TargetVersions = @('5.1', '7.0')
        }
        PSUseCompatibleCommands                   = @{
            Enable         = $true
            TargetProfiles = @(
                'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
            )
        }
        PSUseCompatibleTypes                      = @{
            Enable         = $true
            TargetProfiles = @(
                'win-48_x64_10.0.17763.0_5.1.17763.316_x64_4.0.30319.42000_framework'
                'win-4_x64_10.0.18362.0_7.0.0_x64_3.1.2_core'
            )
        }
    }
}
