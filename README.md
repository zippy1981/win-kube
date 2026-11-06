# win-kube

An AKS-shaped Kubernetes cluster on your laptop, minikube-style, with a **Windows Server 2025
container node**. It includes a sample WordPress Helm chart that runs entirely on Windows
containers.

Under the hood it uses minikube's experimental mixed-OS support (one Linux control plane and
one Windows worker on Hyper-V), built from a pinned commit until upstream ships it. See
[docs/PLAN.md](docs/PLAN.md) for the decisions and risks.

## Requirements

- Windows 10/11 Pro, Enterprise or Education (or Server) with VT-x/AMD-V enabled
- About 12 GB of free RAM (two 6 GB VMs) and about 40 GB of disk
- git
- Windows PowerShell 5.1 or PowerShell 7

## Quick start

```powershell
# 1. One time, elevated (UAC prompt). Enables Hyper-V + Containers, installs OSS dockerd
#    to C:\docker, and adds you to "Hyper-V Administrators" and "docker-users".
.\winkube.ps1 prereqs
#    Reboot if asked, then sign out and back in so the group memberships apply.

# 2. Everything from here on runs WITHOUT elevation.
.\winkube.ps1 tools     # kubectl, helm, and the Windows-node minikube build -> .tools\bin
.\winkube.ps1 up        # ~20+ min the first time (downloads the Windows VHDX)
.\winkube.ps1 deploy    # side-loads images, installs WordPress, prints URL + admin password
```

## ltsc2022 images (Hyper-V isolation)

The node runs Windows Server 2025. Images built on ltsc2022 can run there only with Hyper-V
isolation:

```powershell
.\winkube.ps1 up -Isolation hyperv          # or: .\winkube.ps1 enable-hyperv-isolation
.\winkube.ps1 deploy -WindowsVersion 2022   # uses :2022 tags + runtimeClassName windows-hyperv
```

This path is experimental; see the risks in [docs/PLAN.md](docs/PLAN.md).

## Commands and cmdlets

`winkube.ps1` is a thin shim over the **WinKube** PowerShell module in `src/WinKube`. Each
command calls one cmdlet. Use the cmdlets directly for scripting: they return objects,
support `-WhatIf` where they change state, and have full help (`Get-Help New-WinKubeCluster -Full`,
or the [cmdlet reference](docs/cmdlets/WinKube.md)).

```powershell
Import-Module ./src/WinKube
New-WinKubeCluster -InformationAction Continue
(Install-WinKubeChart).Url
```

| Command | Cmdlet | What it does |
| --- | --- | --- |
| `prereqs` | `Install-WinKubePrerequisite` | Elevated one-time setup (`scripts/Install-WinKubePrereqs.ps1`) |
| `tools` | `Install-WinKubeTool` | Downloads kubectl and helm, and builds minikube from the pinned fork (`-Force` rebuilds) |
| `up` | `New-WinKubeCluster` | Creates the cluster and applies AKS-style labels (`-CpuCount`, `-MemoryMB`, `-KubernetesVersion`, `-WindowsVhdUrl`, `-Isolation`) |
| `enable-hyperv-isolation` | `Enable-WinKubeHyperVIsolation` | Installs the Hyper-V role in the Windows node, then adds the containerd handler and RuntimeClass `windows-hyperv` |
| `load-images` | `Import-WinKubeImage` | `docker save` → copy → `ctr import` on the Windows node (`-Image`, pipeline input) |
| `deploy` | `Install-WinKubeChart` | Side-loads images, then `helm upgrade --install` (`-Chart`, `-WindowsVersion`, `-Set`, `-SkipImageLoad`) |
| `status` | `Get-WinKubeCluster` | Shows minikube status, nodes with labels, runtime classes and helm releases |
| `ssh-windows` | `Enter-WinKubeWindowsNode` | Opens an interactive SSH session to the Windows node (cmd.exe) |
| `down` | `Remove-WinKubeCluster` | Deletes the cluster (the shim skips the confirmation prompt) |
| | `Get-WinKubeWindowsNode` | Returns the Windows node: name, IP, build, release, minikube machine |
| | `Invoke-WinKubeWindowsNode` | Runs a script block on the Windows node over SSH |

The shim keeps the original parameter names (`-Cpus`, `-Images`, `-HelmSet`) as aliases.
The kubectl context is the profile name (`winkube`; change it with `-Profile`). The tools
live in `.tools\bin`; add it to your `PATH` to use `kubectl` and `helm` directly.

## Sample chart

`charts/wordpress-windows` contains:

- **MySQL** on `mysql-spike:<ver>`. A startup script runs `mysqld --initialize-insecure`
  on first start, and an idempotent `--init-file` creates the database and user.
- **WordPress** on `windows-nano-php:<ver>`. An init container downloads WordPress with
  nanoserver's `curl.exe`/`tar.exe`, and the main container serves it with `php -S`,
  enabling `mysqli` and other extensions through `-d`.
- **Install hook** (`post-install,post-upgrade` Job). It waits for the site and MySQL, then
  completes the WordPress installer, so `helm install` returns a working site.
- **helm test** checks that the front page renders.

Credentials and salts are generated once and preserved across upgrades. Data uses
`emptyDir` (minikube has no Windows storage provisioner). Set `*.persistence.existingClaim`
to keep it.

## Layout

```text
winkube.ps1                         CLI shim (non-elevated) over the module
src/WinKube/                        the WinKube module: Public/ (one cmdlet per file), Private/
scripts/Install-WinKubePrereqs.ps1  one-time elevated setup
scripts/Invoke-RepoScriptAnalyzer.ps1, Update-WinKubeCmdletDoc.ps1   lint and docs tooling
PSScriptAnalyzerSettings.psd1, tools/psscriptanalyzer/              strict analyzer settings and rules
tests/*.Tests.ps1                   Pester tests (5.1 and 7); tests/*.py: Python helper tests
docs/cmdlets/                       generated cmdlet reference (PlatyPS)
charts/wordpress-windows/           sample chart (values.yaml, values-2022.yaml)
docs/PLAN.md, docs/adr/, plans/     roadmap, decisions, feature plans
.claude/agents/, .claude/skills/    Claude Code subagents and skills for this repo
.tools/ .cache/                     downloaded tools and image tarballs (git-ignored)
```

## Contributing

`main` only accepts squash-merged pull requests whose required checks pass
([ADR 0006](docs/adr/0006-main-is-protected-by-a-ruleset-with-named-required-checks.md)).
The hooks need [uv](https://docs.astral.sh/uv/), Node.js, and pwsh with three modules:

```powershell
Install-PSResource -Name PSScriptAnalyzer, Pester, Microsoft.PowerShell.PlatyPS -Scope CurrentUser
uv run pre-commit install
uv run pre-commit run --all-files
```

After changing a cmdlet's help or parameters, regenerate the reference with
`./scripts/Update-WinKubeCmdletDoc.ps1`; CI fails when it is stale.
