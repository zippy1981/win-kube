# Architecture decision records

These records explain why this repo is built the way it is. Each one covers a single decision in MADR style: status, context, decision, consequences, and alternatives considered. To add one, use the `adr` agent or copy the layout of an existing record into the next number, and add it to this table. To change a decision, write a new record that supersedes the old one.

| Number | Title | Status | Date |
| --- | --- | --- | --- |
| 0001 | [Record architecture decisions](0001-record-architecture-decisions.md) | Accepted | 2026-11-05 |
| 0002 | [Python tooling uses uv, with the Python version set by `UV_PYTHON`](0002-python-tooling-uses-uv-with-the-python-version-from-uv-python.md) | Accepted | 2026-11-05 |
| 0003 | [Build minikube from the Windows-node fork at a pinned commit](0003-build-minikube-from-the-windows-node-fork-at-a-pinned-commit.md) | Accepted | 2026-11-05 |
| 0004 | [Only the prerequisites step elevates](0004-only-the-prerequisites-step-elevates.md) | Accepted | 2026-11-05 |
| 0005 | [ltsc2025 node, with Hyper-V isolation for older images](0005-ltsc2025-node-with-hyper-v-isolation-for-older-images.md) | Accepted | 2026-11-05 |
| 0006 | [main is protected by a ruleset with named required checks and squash-only merges](0006-main-is-protected-by-a-ruleset-with-named-required-checks.md) | Accepted | 2026-11-05 |
| 0007 | [PowerShell code supports Windows PowerShell 5.1 and PowerShell 7](0007-powershell-code-supports-windows-powershell-5-1-and-powershell-7.md) | Accepted | 2026-11-05 |
| 0008 | [WinKube is a PowerShell module checked by strict analysis, Pester and PlatyPS](0008-winkube-is-a-module-checked-by-strict-analysis-pester-and-platyps.md) | Accepted | 2026-11-05 |
