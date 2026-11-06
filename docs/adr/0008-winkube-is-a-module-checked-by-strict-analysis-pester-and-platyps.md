# 0008. WinKube is a PowerShell module checked by strict analysis, Pester and PlatyPS

- Status: Accepted
- Date: 2026-11-05
- Deciders: Justin Dearing
- Related: [0006](0006-main-is-protected-by-a-ruleset-with-named-required-checks.md), [0007](0007-powershell-code-supports-windows-powershell-5-1-and-powershell-7.md), [`.github/workflows/powershell.yml`](../../.github/workflows/powershell.yml)

## Context

`winkube.ps1` started as one script with a `switch` over subcommands. That is hard to test (nothing can be mocked), returns text rather than objects, has no per-command help, and can't be used from other scripts. It also had no static analysis, so PowerShell 7-only syntax or 5.1 pitfalls were caught only by hand.

## Decision

- The code is the **WinKube** module in `src/WinKube`: one exported cmdlet per file in `Public/`, helpers in `Private/`, and a manifest that exports exactly the `Public/` functions. Cmdlets use approved verbs and the `WinKube` noun prefix, take `-ClusterProfile` (alias `Profile`), return typed objects, report progress with `Write-Information`, and support `-WhatIf` when they change state.
- `winkube.ps1` stays as a shim with the original subcommands, mapping each to a cmdlet.
- Every native command goes through `Invoke-WinKubeNative`, so Pester can mock them.
- **PSScriptAnalyzer** runs with `PSScriptAnalyzerSettings.psd1`: all default rules at every severity, the formatting rules, the 5.1/7 compatibility rules, no `Write-Host`, and repo rules requiring `[CmdletBinding()]`, `[OutputType()]` and comment-based help on every script and function. Suppressions need a justification.
- **Pester 5** tests in `tests/` check the module's contract (names, help for every parameter, `-WhatIf`) and its behaviour with mocks, under both PowerShell 7 (ubuntu-latest) and Windows PowerShell 5.1 (windows-latest).
- **PlatyPS** generates `docs/cmdlets/` from the help; `scripts/Update-WinKubeCmdletDoc.ps1 -Check` fails CI when it is stale.
- The checks run in the pre-commit hooks and as required jobs `psscriptanalyzer`, `pester-pwsh`, `pester-windows-powershell` and `cmdlet-docs`.

## Consequences

- Behaviour is tested without a cluster, and 5.1 differences (such as `ConvertFrom-Json` not enumerating arrays) are caught in CI.
- Contributors need pwsh with PSScriptAnalyzer, Pester and PlatyPS installed to run the hooks.
- Any help change needs the docs regenerated in the same commit.

## Alternatives considered

- **Keep the single script and add tests around it.** Without functions to mock, tests would need a real cluster.
- **Warning-and-error severity only, as in windows-nano-demos.** The maintainer asked for every rule; Information-level findings such as help and casing are cheap to fix up front.
- **Comment-based help only, no generated docs.** Rejected so the reference can be read on GitHub.
