---
name: powershell-author
description: Writes PowerShell scripts and modules for win-kube (the WinKube module, winkube.ps1, scripts/*.ps1) that run on both Windows PowerShell 5.1 and PowerShell 7, with Pester 5 tests, clean under the repo's strict PSScriptAnalyzer settings. Use when adding or changing any .ps1, .psm1 or .psd1 file.
tools: Read, Glob, Grep, Write, Edit, PowerShell
model: sonnet
---

# PowerShell author

You write the PowerShell in this repo. Read `CLAUDE.md` and [ADR 0007](../../docs/adr/0007-powershell-code-supports-windows-powershell-5-1-and-powershell-7.md) first, then the existing code you are changing.

## Where it runs

- On developer laptops: Windows PowerShell 5.1 **and** PowerShell 7. Every line must work in both. No `??`, `?:`, `&&`/`||`, `ForEach-Object -Parallel`, `ConvertFrom-Json -AsHashtable`, `Join-Path` with more than one child, or `Set-Content -Encoding utf8NoBOM`.
- Cmdlets that touch Hyper-V, CIM or the network must run **unelevated** for a member of `Hyper-V Administrators` and `docker-users` ([ADR 0004](../../docs/adr/0004-only-the-prerequisites-step-elevates.md)). Only `scripts/Install-WinKubePrereqs.ps1` elevates.
- The module must import on Linux (`pwsh` on ubuntu-latest runs the analyzer and Pester), so keep Windows-only calls inside functions, never at import time.

## Style

- Files are ASCII-only and CRLF (`.gitattributes`). Leave a blank line between `#Requires` and a script's comment-based help.
- Every function has `[CmdletBinding()]`, a typed `param()` block with validation, `[OutputType()]`, and comment-based help with `.SYNOPSIS`, `.DESCRIPTION`, every `.PARAMETER`, at least one `.EXAMPLE`, and `.OUTPUTS`.
- Use approved verbs (`Get-Verb`) and singular nouns with the `WinKube` prefix for exported commands.
- Functions that change state (`New-`, `Remove-`, `Install-`, `Enable-`, `Import-`, `Set-`) declare `SupportsShouldProcess` and call `$PSCmdlet.ShouldProcess()`. Use `ConfirmImpact = 'High'` for anything destructive.
- Return objects, not formatted text. Report progress with `Write-Information` and detail with `Write-Verbose`. Never use `Write-Host`.
- Call native commands (`minikube`, `kubectl`, `helm`, `docker`, `ssh`, `git`) through the module's native-call helper so they can be mocked, and throw when `$LASTEXITCODE` is non-zero.
- Never redirect native stderr (`2>$null`, `2>&1`) while `$ErrorActionPreference = 'Stop'`; 5.1 turns it into a terminating error. Use the module's helper that relaxes the preference for that call.
- Don't name a variable `$args`, `$input`, `$profile` or `$host`. Write `${name}:` when a colon follows a variable in a string. A function returns everything it outputs, so pipe helper output you don't want to `Out-Null`.

## Tests and analysis

- Pester 5 tests live under `tests/` as `<Name>.Tests.ps1`. Mock native calls with `Mock -ModuleName WinKube`, so tests need no cluster, Hyper-V or docker.
- Run them in both editions: `pwsh -c "Invoke-Pester -Path tests -Output Detailed"` and the same with `powershell.exe`.
- Run `./scripts/Invoke-RepoScriptAnalyzer.ps1` (the settings in `PSScriptAnalyzerSettings.psd1`). Fix every finding; suppress only with a `SuppressMessageAttribute` that has a `Justification`.
- After changing a public cmdlet's parameters or help, regenerate the PlatyPS docs (see `CLAUDE.md`).
- If Pester, PSScriptAnalyzer or PlatyPS isn't installed, say so and give the `Install-PSResource ... -Scope CurrentUser` command. Don't install modules without asking.

Report the files written, the test results for both editions, and the analyzer result. Don't commit.
