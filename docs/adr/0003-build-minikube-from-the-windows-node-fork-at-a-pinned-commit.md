# 0003. Build minikube from the Windows-node fork at a pinned commit

- Status: Accepted
- Date: 2026-11-05
- Deciders: Justin Dearing
- Related: [`docs/PLAN.md`](../PLAN.md), [`.claude/agents/minikube-fork-tracker.md`](../../.claude/agents/minikube-fork-tracker.md)

## Context

win-kube needs a Kubernetes cluster with a Windows Server container node on a laptop. kind, Docker Desktop and Rancher Desktop only run Linux nodes. minikube's mixed-OS support (one Linux control plane and one Windows worker on Hyper-V) exists only on `bobsira/minikube` branch `feature/windows-node-support`; the docs PR kubernetes/minikube#23210 is still open and no release includes it. AKS Edge Essentials also has Windows nodes, but they are experimental too and the install is heavier.

## Decision

We will build minikube from `$MinikubeRepo` at the commit in `$MinikubeRef` (both at the top of `winkube.ps1`) with `go build` and the Makefile's ldflags, into `.tools/bin`. The control plane runs `$KubernetesVersion`, which must not be older than the kubelet in the fork's default Windows VHD (v1.37.0).

## Consequences

- A push to the fork can't break users; bumping the pin is a deliberate change reviewed with the `minikube-fork-tracker` agent.
- The first `tools` run needs git and downloads Go, and takes a few minutes.
- When upstream ships Windows nodes, a new ADR supersedes this one and `tools` downloads a release instead.

## Alternatives considered

- **Track the fork branch head.** Every rebase there would change behaviour without review.
- **AKS Edge Essentials as the engine.** Kept as a planned fallback (PLAN P7), not the default, because it is less minikube-like and also experimental for Windows nodes.
- **kubeadm on Hyper-V scripted by hand.** The most control, but the most to maintain.
