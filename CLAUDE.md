# win-kube

A minikube-based local cluster (Linux control plane + Windows Server 2025 node on Hyper-V)
plus a sample Windows-container Helm chart. Decisions, risks and roadmap live in
`docs/PLAN.md`; keep it updated when a decision changes or a phase completes.

## Rules

- **PowerShell 5.1 compatibility** for everything in `winkube.ps1` and `scripts/`. That means:
  - no `??`, ternaries, `&&`/`||`, `ForEach-Object -Parallel` or `-AsHashtable`
  - use `Invoke-WebRequest -UseBasicParsing`
  - keep files ASCII-only (5.1 reads BOM-less files as ANSI)
  - put a blank line between `#Requires` and the comment-based help block
  - never redirect native stderr (`2>$null`, `2>&1`) while `$ErrorActionPreference = 'Stop'`; use `Test-Native`
- **Only `prereqs` elevates.** Every other command must work for a member of
  `Hyper-V Administrators` + `docker-users`. Don't add `-Verb RunAs`, and don't call
  cmdlets that need admin (e.g. `Resize-VHD`, `New-VMSwitch`) outside the prereqs script.
- The minikube fork is pinned by `$MinikubeRepo`/`$MinikubeRef` in `winkube.ps1`. Bump the
  SHA only after checking the kubelet version in the fork's default VHD against
  `$KubernetesVersion` (a kubelet must not be newer than the API server).
- Windows node access goes through `Invoke-WindowsNode` / `Copy-ToWindowsNode` (SSH as
  Administrator, default shell cmd.exe).

## Chart conventions (`charts/wordpress-windows`)

- Every Windows pod includes `wpwin.windowsPodSpec`, which sets the os/build nodeSelector,
  the tolerations and the automatic Hyper-V `runtimeClassName`.
- Never put paths containing spaces (e.g. `%PHP_DIR%`) in a pod `command` array. Put them
  in a `.cmd` script under `files/`; `wpwin.filesAsConfig` converts those to CRLF.
- Generated secrets must be read back with `lookup` so upgrades keep them.
- The images are side-loaded and never pulled: `windows-nano-php:<2025|2022>` and
  `mysql-spike:<2025|2022>` (MySQL 8.4 at `C:\mysql`, no entrypoint).

## Validate changes

```powershell
# Parse both scripts under 5.1 (and pwsh)
powershell -NoProfile -Command "foreach($f in 'winkube.ps1','scripts\Install-WinKubePrereqs.ps1'){$e=$null;[void][Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f),[ref]$null,[ref]$e);\"$f $($e.Count) errors\"}"
.\.tools\bin\helm.exe lint charts\wordpress-windows
.\.tools\bin\helm.exe template t charts\wordpress-windows -f charts\wordpress-windows\values-2022.yaml
```

Subagents in `.claude/agents/`: `winkube-cluster-doctor` (diagnose cluster and node
problems), `windows-chart-author` (write and review charts for Windows nodes), and
`minikube-fork-tracker` (evaluate fork/upstream bumps).
