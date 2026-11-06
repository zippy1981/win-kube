# 0005. ltsc2025 node, with Hyper-V isolation for older images

- Status: Accepted
- Date: 2026-11-05
- Deciders: Justin Dearing
- Related: [`charts/wordpress-windows/templates/_helpers.tpl`](../../charts/wordpress-windows/templates/_helpers.tpl), [0003](0003-build-minikube-from-the-windows-node-fork-at-a-pinned-commit.md)

## Context

The fork's Windows node image is Windows Server 2025. Process-isolated Windows containers need the image build to match the node build, but the user's images exist for ltsc2019, ltsc2022 and ltsc2025 (`windows-nano-php:<ver>`, `mysql-spike:<ver>`). An older image can run on a newer host only with Hyper-V isolation.

## Decision

We will default to ltsc2025 images and process isolation. ltsc2022 images run through Hyper-V isolation: `up -Isolation hyperv` (or `enable-hyperv-isolation`) installs the Hyper-V role in the node, adds a `runhcs-wcow-hypervisor` containerd handler with `SandboxIsolation = 1`, and creates RuntimeClass `windows-hyperv`. Charts set `runtimeClassName` automatically when `windows.version` is older than `windows.nodeVersion`, and refuse to render when it is newer.

## Consequences

- The default path is the simple, proven one.
- The Hyper-V isolation path needs nested virtualization, static VM memory, and a VM power cycle that bypasses minikube; it is the least-tested part of the repo.
- Images are side-loaded with `ctr import --platform windows/amd64` so older builds aren't filtered out.

## Alternatives considered

- **A Windows Server 2022 node image.** Possible with a custom VHD, but then ltsc2025 images (the default) would not run at all.
- **One node per Windows version.** The fork supports exactly one Windows worker.
