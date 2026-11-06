# win-kube plan

Goal: a minikube-style, AKS-shaped Kubernetes cluster with a **Windows Server container
node** on a developer laptop, scripted so it can be shared and run without elevation, plus
a sample Helm chart that proves Windows workloads end to end.

## Decisions

| Topic | Decision | Why |
| --- | --- | --- |
| Workloads | Windows Server containers | The point of the repo. Rules out kind, Docker Desktop and Rancher Desktop (Linux nodes only). |
| Engine | minikube, built from the experimental Windows-node fork at a pinned SHA | Closest to the "minikube vein"; upstream PR kubernetes/minikube#23210 is open and nothing has shipped in a release. AKS Edge Essentials remains the fallback (its Windows nodes are also experimental). |
| Topology | 1 Linux control plane + 1 Windows Server 2025 worker, Hyper-V, Flannel, containerd | The only mixed-OS shape the fork supports today. |
| Kubernetes version | `v1.37.0` | The fork's default VHD ships kubelet v1.37.0 while the default control plane is v1.36.x; a kubelet newer than the API server is unsupported. |
| Elevation | Only `prereqs` elevates | The fork's Hyper-V driver accepts membership in `Hyper-V Administrators` (S-1-5-32-578). Docker access comes from the `docker-users` pipe group. |
| Images | ltsc2025 by default; ltsc2022 through Hyper-V isolation | Process isolation needs image build == node build. Older images run on a newer node only with Hyper-V isolation. |
| Image delivery | `docker save` → `scp` → `ctr -n k8s.io images import` | The sample images live only in the local Docker engine; no registry to set up and no insecure-registry config on the node. |
| Reboots | Not a concern | The user rarely reboots. The fork does not support restarting Windows nodes, so `down` + `up` is the reset path. |
| Sample app | WordPress on `windows-nano-php:<ver>` + `mysql-spike:<ver>` | Uses the user's existing images; a Helm post-install hook finishes the WordPress installer. |
| AKS parity | AKS-style node labels (`agentpool`, `kubernetes.azure.com/mode`, `kubernetes.azure.com/os-sku`) and an `os=windows:NoSchedule` toleration | Lets manifests shared with real AKS clusters schedule the same way. |

## Architecture

```text
winkube.ps1 (non-elevated)                         scripts/Install-WinKubePrereqs.ps1 (UAC, once)
  tools  -> .tools/bin/{kubectl,helm,minikube}.exe     Hyper-V + Containers features
            minikube built from bobsira/minikube@SHA   Hyper-V Administrators + docker-users
  up     -> minikube start --driver=hyperv              OSS dockerd in C:\docker (+ service)
            --node role=control-plane                    long paths
            --node role=worker,os=windows
            + AKS labels, optional Hyper-V isolation
  load-images -> docker save | scp | ctr import (Windows node, over minikube's SSH key)
  deploy -> helm upgrade --install charts/wordpress-windows
```

The Windows node is reached as `Administrator@<node IP>` using `minikube ssh-key`; its
SSH default shell is `cmd.exe`, so remote work is done by copying a `.ps1` and running it.

### Hyper-V isolation (ltsc2022 on the ltsc2025 node)

`up -Isolation hyperv` (or `enable-hyperv-isolation` on an existing cluster):

1. Creates the VMs with static memory (`--hyperv-disable-dynamic-memory`); the fork
   already exposes virtualization extensions when `--cpus` > 1.
2. Installs the `Hyper-V` role inside the Windows node and power-cycles the VM.
3. Adds a `runhcs-wcow-hypervisor` containerd runtime handler (`SandboxIsolation = 1`).
4. Creates RuntimeClass `windows-hyperv`. The chart sets `runtimeClassName` automatically
   when `windows.version` < `windows.nodeVersion`.

## Phases

- [x] **P0: Research and decisions.** See the table above.
- [x] **P1: Prereqs script.** PS 5.1, idempotent, self-elevating.
- [x] **P2: CLI.** `tools`, `up`, `down`, `status`, `load-images`, `deploy`, `ssh-windows`, `enable-hyperv-isolation`.
- [x] **P3: Sample chart.** MySQL + WordPress + install hook + helm test.
- [x] **P4: Agents and docs.** `.claude/agents/*`, `CLAUDE.md`, this plan.
- [ ] **P5: First real run.** Execute the validation checklist below on a laptop and fix what breaks.
- [ ] **P6: Platform add-ons.** A `charts/platform` umbrella with ingress-nginx (Linux), metrics-server, and an in-cluster registry standing in for ACR.
- [ ] **P7: Fallback engine.** `-Engine aksee` that drives AKS Edge Essentials behind the same commands.
- [ ] **P8: Track upstream.** Switch `$MinikubeRepo`/`$MinikubeRef` to a kubernetes/minikube release once Windows nodes merge.

## Validation status

Verified while authoring:

- Both scripts parse under Windows PowerShell 5.1 and PowerShell 7; comment-based help works.
- Fork flags (`--node role=…,os=…`, `--windows-vhd-url`, `--hyperv-disable-dynamic-memory`),
  the Hyper-V Administrators check, nested-virt exposure, and the VHD contents
  (WS2025, kubelet v1.37.0, containerd 2.2.3 at `C:\Program Files\containerd`) were read from source.
- Image contents: `windows-nano-php` has PHP 8.5 with `ext\php_mysqli.dll` available but not
  enabled; `mysql-spike` is a bare MySQL 8.4 extract at `C:\mysql` with no entrypoint.

**Not yet executed** (this laptop had no Hyper-V and no helm when the repo was written):

- [ ] `.\winkube.ps1 prereqs` → reboot → sign out/in
- [ ] `.\winkube.ps1 tools` (fork clone + go build)
- [ ] `helm lint charts/wordpress-windows` and `helm template` with both values files
- [ ] `.\winkube.ps1 up` → both nodes Ready, labels applied
- [ ] `.\winkube.ps1 deploy` → install hook succeeds, `helm test` passes, site loads via NodePort
- [ ] `.\winkube.ps1 up -Isolation hyperv` + `deploy -WindowsVersion 2022`

## Known risks

| Risk | Mitigation |
| --- | --- |
| Fork rebased or abandoned | Pinned SHA; P7 fallback; P8 upstream switch. |
| Windows node restart unsupported by minikube | Don't stop the cluster; `down` + `up` to reset. The Hyper-V isolation step power-cycles the VM directly through Hyper-V, which bypasses minikube; the Default Switch normally keeps the DHCP lease. |
| ltsc2022 import/unpack on a 2025 node | `ctr import --platform windows/amd64` (no OS version) to avoid host-build filtering. If kubelet still rejects it, enable the `RuntimeClassInImageCriApi` kubelet feature gate or add a containerd `runtime_platforms` entry. This is the least-proven path. |
| Windows kube-proxy flaps during HNS setup | `up` waits for Ready with a 20 minute timeout. |
| `php -S` is single-threaded | Fine for dev. WP-Cron is disabled to avoid loopback stalls. |
| No Windows storage provisioner | emptyDir by default; `*.persistence.existingClaim` for a PVC you create. |
