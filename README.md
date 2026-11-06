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

## Commands

| Command | What it does |
| --- | --- |
| `prereqs` | Elevated one-time setup (`scripts/Install-WinKubePrereqs.ps1`, PS 5.1 compatible) |
| `tools` | Downloads kubectl and helm, and builds minikube from the pinned fork (`-Force` rebuilds) |
| `up` | Creates the cluster and applies AKS-style labels. Options: `-Cpus`, `-MemoryMB`, `-KubernetesVersion`, `-WindowsVhdUrl`, `-Isolation` |
| `enable-hyperv-isolation` | Installs the Hyper-V role in the Windows node, then adds the containerd handler and RuntimeClass `windows-hyperv` |
| `load-images` | `docker save` → copy → `ctr import` on the Windows node (`-Images a:b,c:d`) |
| `deploy` | `load-images` followed by `helm upgrade --install` of `charts/wordpress-windows` (`-WindowsVersion`, `-HelmSet`, `-SkipImageLoad`) |
| `status` | Shows minikube status, nodes with labels, runtime classes and helm releases |
| `ssh-windows` | Opens an interactive SSH session to the Windows node (cmd.exe) |
| `down` | Deletes the cluster |

The kubectl context is the profile name (`winkube`; change it with `-Profile`).
`.tools\bin` is added to `PATH` only while a command runs. Add it to your own `PATH` to
use `kubectl` and `helm` directly.

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
winkube.ps1                       CLI (non-elevated)
scripts/Install-WinKubePrereqs.ps1  one-time elevated setup
charts/wordpress-windows/         sample chart (values.yaml, values-2022.yaml)
docs/PLAN.md                      roadmap, architecture, validation checklist
docs/adr/                         architecture decision records
plans/                            feature plans
scripts/*.py, tests/              CI triage / repo status helpers and their tests (uv)
.claude/agents/, .claude/skills/  Claude Code subagents and skills for this repo
.tools/ .cache/                   downloaded tools and image tarballs (git-ignored)
```

## Contributing

`main` only accepts squash-merged pull requests whose required checks pass
([ADR 0006](docs/adr/0006-main-is-protected-by-a-ruleset-with-named-required-checks.md)).
Install the hooks once per clone, which needs [uv](https://docs.astral.sh/uv/) and Node.js:

```powershell
uv run pre-commit install
uv run pre-commit run --all-files
```
