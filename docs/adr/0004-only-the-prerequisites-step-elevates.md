# 0004. Only the prerequisites step elevates

- Status: Accepted
- Date: 2026-11-05
- Deciders: Justin Dearing
- Related: [`scripts/Install-WinKubePrereqs.ps1`](../../scripts/Install-WinKubePrereqs.ps1), [`winkube.ps1`](../../winkube.ps1)

## Context

The scripts should be easy to share and to run day to day without UAC prompts. Hyper-V VM management normally needs an administrator, but the fork's Hyper-V driver accepts membership in the built-in `Hyper-V Administrators` group (SID S-1-5-32-578). The OSS Docker engine can grant its named pipe to a group with `"group"` in `daemon.json`.

## Decision

We will keep every action that needs an administrator in `scripts/Install-WinKubePrereqs.ps1`, which self-elevates once to enable Hyper-V and Containers, install dockerd into `C:\docker`, enable long paths, and add the user to `Hyper-V Administrators` and `docker-users`. Every other command runs unelevated and must not call cmdlets that need an administrator (for example `Resize-VHD` or `New-VMSwitch`).

## Consequences

- After one UAC prompt, a sign-out and possibly a reboot, the daily workflow never prompts.
- Membership in `Hyper-V Administrators` is powerful; the README says so.
- New features that need elevation go into the prerequisites script, not into the CLI.

## Alternatives considered

- **Run everything elevated.** Simpler to write, but every command prompts, and an elevated shell is a worse default for sharing.
- **A scheduled task or service that runs elevated work.** More moving parts, and harder to audit than a one-time script.
