# win-kube

A minikube-based local cluster (Linux control plane + Windows Server 2025 node on Hyper-V) plus a sample Windows-container Helm chart. The roadmap and risks live in [docs/PLAN.md](docs/PLAN.md), feature plans in `plans/`, and decisions in the [ADRs](docs/adr/README.md). Read the ADRs before changing CI, elevation, Kubernetes versions or conventions.

## Environment (Windows host)

- **Python:** always through uv ([ADR 0002](docs/adr/0002-python-tooling-uses-uv-with-the-python-version-from-uv-python.md)): `uv run pytest`, `uv run python scripts/<x>.py`. `.claude/settings.json` sets `UV_PYTHON=3.14` and `UV_PYTHON_PREFERENCE=only-managed`. `python` on this host is only the Microsoft Store stub.
- **Before committing:** run `uv run pre-commit run --all-files` (ruff, markdownlint, pytest; install the hook once with `uv run pre-commit install`). Never weaken a test or a lint rule to make it pass. Coverage of `scripts/*.py` must stay at 95% or more.
- **Line endings:** Markdown, YAML, Python, TOML, JSON and PHP are LF. `.cmd`, `.bat` and `.ps1` are CRLF (`.gitattributes`). In a CRLF working copy, `sed` and `perl` edits anchored at line ends silently miss, so use the Edit tool.
- **PowerShell quirks:** don't name a variable `$args`. Write `${name}:` when a colon follows a variable in a string. A function returns everything it outputs, so send command output you don't want returned to `Out-Null`.

## PowerShell rules

- **The code is the WinKube module** ([ADR 0008](docs/adr/0008-winkube-is-a-module-checked-by-strict-analysis-pester-and-platyps.md)) in `src/WinKube`: one exported cmdlet per file in `Public/` (approved verb, `WinKube` noun prefix, `-ClusterProfile` with alias `Profile`, typed output objects, `-WhatIf` when it changes state), helpers in `Private/`. Add new public cmdlets to `FunctionsToExport` in `WinKube.psd1`. `winkube.ps1` is only a shim that maps subcommands to cmdlets.
- Call native commands only through `Invoke-WinKubeNative` (or `Test-WinKubeNative` for exit-code checks) so tests can mock them. Report progress with `Write-WinKubeStep`; never `Write-Host`.
- **5.1 and 7 compatibility** ([ADR 0007](docs/adr/0007-powershell-code-supports-windows-powershell-5-1-and-powershell-7.md)) for every PowerShell file:
  - no `??`, ternaries, `&&`/`||`, `ForEach-Object -Parallel` or `-AsHashtable`
  - use `Invoke-WebRequest -UseBasicParsing`
  - keep files ASCII-only (5.1 reads BOM-less files as ANSI)
  - put a blank line between `#Requires` and the comment-based help block
  - never redirect native stderr (`2>$null`, `2>&1`) while `$ErrorActionPreference = 'Stop'`; use `Test-WinKubeNative`
  - parse JSON that may be an array with `ConvertFrom-WinKubeJsonArray`; 5.1's `ConvertFrom-Json` doesn't enumerate arrays
- **Strict analysis:** `PSScriptAnalyzerSettings.psd1` turns on every rule at every severity. Fix findings instead of suppressing them; a suppression needs a `Justification`. `Invoke-Formatter -Settings ./PSScriptAnalyzerSettings.psd1` fixes the formatting rules.
- **Only `prereqs` elevates** ([ADR 0004](docs/adr/0004-only-the-prerequisites-step-elevates.md)). Every other command must work for a member of `Hyper-V Administrators` + `docker-users`. Don't add `-Verb RunAs`, and don't call cmdlets that need admin (e.g. `Resize-VHD`, `New-VMSwitch`) outside the prereqs script.
- The minikube fork is pinned by `$script:MinikubeRepo`/`$script:MinikubeRef` in `src/WinKube/WinKube.psm1` ([ADR 0003](docs/adr/0003-build-minikube-from-the-windows-node-fork-at-a-pinned-commit.md)). Bump the SHA only after checking the kubelet version in the fork's default VHD against `$script:DefaultKubernetesVersion` (a kubelet must not be newer than the API server). The `minikube-fork-tracker` agent does this review.
- Windows node access goes through `Invoke-WinKubeWindowsNode` (a script block plus `-ArgumentList`, with no `"` or cmd.exe metacharacters) and `Copy-WinKubeFileToWindowsNode`: SSH as Administrator, default shell cmd.exe, Windows PowerShell 5.1 on the node.

## Chart conventions (`charts/wordpress-windows`)

- Every Windows pod includes `wpwin.windowsPodSpec`, which sets the os/build nodeSelector, the tolerations and the automatic Hyper-V `runtimeClassName` ([ADR 0005](docs/adr/0005-ltsc2025-node-with-hyper-v-isolation-for-older-images.md)).
- Never put paths containing spaces (e.g. `%PHP_DIR%`) in a pod `command` array. Put them in a `.cmd` script under `files/`; `wpwin.filesAsConfig` converts those to CRLF.
- Generated secrets must be read back with `lookup` so upgrades keep them.
- The images are side-loaded and never pulled: `windows-nano-php:<2025|2022>` and `mysql-spike:<2025|2022>` (MySQL 8.4 at `C:\mysql`, no entrypoint).

## Validate changes

```powershell
# One-time: pwsh modules the hooks and CI use
Install-PSResource -Name PSScriptAnalyzer, Pester, Microsoft.PowerShell.PlatyPS -Scope CurrentUser

./scripts/Invoke-RepoScriptAnalyzer.ps1              # strict analyzer (CI job psscriptanalyzer)
Invoke-Pester -Path tests                            # PowerShell 7 (CI job pester-pwsh)
# Windows PowerShell 5.1 (CI job pester-windows-powershell): import Pester 5 by path, then Invoke-Pester -Path tests
./scripts/Update-WinKubeCmdletDoc.ps1                # regenerate docs/cmdlets (CI job cmdlet-docs checks it)
.\.tools\bin\helm.exe lint charts\wordpress-windows
.\.tools\bin\helm.exe template t charts\wordpress-windows -f charts\wordpress-windows\values-2022.yaml
uv run pre-commit run --all-files                    # everything above except helm
```

Required checks on `main`: `markdownlint`, `pytest`, `psscriptanalyzer`, `pester-pwsh`, `pester-windows-powershell`, `cmdlet-docs`.

## GitHub workflow

- **Branch from `origin/main` in a worktree** (`git worktree add ../wt-<name> -b <branch> origin/main`). The main checkout belongs to the user.
- **`main` is protected** ([ADR 0006](docs/adr/0006-main-is-protected-by-a-ruleset-with-named-required-checks.md)): PRs only, squash merges only, conversations resolved, and the named required checks green on an up-to-date branch. No bypass, so never try `--admin`. Workflows that provide a required check have no path filters; adding or renaming such a job means updating the ruleset in the same PR.
- **Commits** end with the attribution trailers the session gives you. PR bodies end with the Claude Code line. The PR title and body become the squash commit, so keep them accurate.
- **CI status:** use the `repo-status` and `ci-triage` skills, or the `ci-watcher` agent, instead of polling or reading whole logs.
- **Conflicts, stacks and merges:** follow the `pr-shepherd` skill. Merge only when the user asked and every check on the head commit passed.
- **Parallel agents:** at most about 3 at once. Use haiku for watching and fixing, sonnet for implementing, and opus for design and audit. The roster is in [.claude/agents/README.md](.claude/agents/README.md).
