# 0007. PowerShell code supports Windows PowerShell 5.1 and PowerShell 7

- Status: Accepted
- Date: 2026-11-05
- Deciders: Justin Dearing
- Related: [`CLAUDE.md`](../../CLAUDE.md), [`.claude/agents/powershell-author.md`](../../.claude/agents/powershell-author.md)

## Context

win-kube runs on developer laptops. Every Windows machine has Windows PowerShell 5.1; not all have PowerShell 7. The prerequisites script in particular runs before anything else is installed. windows-nano-demos targets PowerShell 7.4 because its scripts run in nanoserver containers, which have no 5.1.

## Decision

We will write all PowerShell in this repo (scripts and modules) to run on both Windows PowerShell 5.1 and PowerShell 7: no `??`, `?:`, `&&`/`||` or other 7-only syntax, `Invoke-WebRequest -UseBasicParsing`, ASCII-only files, and no redirection of native stderr under `$ErrorActionPreference = 'Stop'`. Module manifests declare `PowerShellVersion = '5.1'` and `CompatiblePSEditions = @('Desktop', 'Core')`. PSScriptAnalyzer's compatibility rules and CI on both editions enforce it.

## Consequences

- The tools work out of the box on any supported Windows install.
- Authors give up newer syntax and some cmdlet parameters; the analyzer flags them.
- Tests must run under both `powershell.exe` (windows-latest) and `pwsh`.

## Alternatives considered

- **PowerShell 7.4 only, like windows-nano-demos.** Nicer syntax, but users would have to install pwsh first, and the prerequisites script would still need 5.1.
