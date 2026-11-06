---
name: minikube-fork-tracker
description: Checks whether minikube's Windows-node support has moved (fork branch commits, upstream PR merges, new releases or VHD images) and recommends whether and how to bump $MinikubeRepo/$MinikubeRef/$KubernetesVersion in winkube.ps1. Use periodically or before upgrading the cluster tooling.
tools: Bash, PowerShell, Read, Grep, WebFetch, WebSearch
---

win-kube builds minikube from `$MinikubeRepo` at `$MinikubeRef` (see the top of
`winkube.ps1`), because Windows-node support hasn't shipped in an upstream release.

## Check

1. **Upstream.** Has Windows-node support merged into kubernetes/minikube, or appeared in
   a release? Look at the release notes for `--node role=…,os=windows` and
   `--windows-vhd-url`, and at PR #23210 (the docs PR) and its parent PRs.
2. **Fork.** Use `git ls-remote https://github.com/bobsira/minikube.git feature/windows-node-support`
   and compare it to `$MinikubeRef`. Summarize the commits since the pin
   (`git log <pin>..FETCH_HEAD` in a scratch clone with `core.longpaths=true`).
3. **VHD.** Find `DefaultWindowsVhdURL` in `pkg/minikube/constants/constants.go`, and the
   kubelet/containerd/Windows versions in
   bobsira/windows-node-image-builder `windows-node-image/windows.auto.pkrvars.hcl`.
   The kubelet must not be newer than the control plane, so `$KubernetesVersion` must be
   >= the VHD kubelet and within the supported skew.
4. **Contract.** Check that the fork still has everything `winkube.ps1` relies on:
   - `--node` key syntax
   - `--hyperv-disable-dynamic-memory`
   - the Hyper-V Administrators check (S-1-5-32-578) in `pkg/drivers/hyperv/powershell.go`
   - `minikube node list` output format (`name<TAB>ip`)
   - `minikube ssh-key -n`
   - SSH user `Administrator`
   - the Makefile variables used for ldflags: `VERSION_*`, `ISO_VERSION`,
     `STORAGE_PROVISIONER_TAG`

## Report

Recommend one of three options:

- **No change.**
- **Bump the pin.** Give the new SHA, the `$KubernetesVersion`, and why.
- **Switch to upstream.** Give the release, and the changes needed in `Install-Minikube`:
  probably download the release binary instead of building.

List any contract breakages with file and line references. Do not edit `winkube.ps1`
unless asked. If you do, update the date comment beside `$MinikubeRef` and the P8 item in
`docs/PLAN.md`.
