# Claude Code agents

This folder holds the [Claude Code subagents](https://docs.claude.com/en/docs/claude-code/sub-agents) for win-kube. Each file's YAML front matter sets the agent's `name`, `description`, `tools`, and `model`. The body is its system prompt. Most of the general-purpose agents are adapted from [zippy1981/windows-nano-demos](https://github.com/zippy1981/windows-nano-demos).

## Agents

| Agent | Purpose | Model | Tools |
| --- | --- | --- | --- |
| `planning` | Writes plans in `plans/` and names the agent that owns each step. Writes only under `plans/`. | haiku | Read, Glob, Grep, Write, Edit, Agent |
| `adr` | Writes MADR-style decision records in `docs/adr/` and keeps the index. Writes only under `docs/adr/`. | sonnet | Read, Glob, Grep, Write, Edit |
| `governance` | Read-only audit of agents, workflows, PowerShell, charts, plans, ADRs, and docs. Returns a ranked gap report. | opus | Read, Glob, Grep |
| `powershell-author` | Writes PowerShell for 5.1 and 7 (the WinKube module, `winkube.ps1`, scripts) with Pester tests, clean under the strict analyzer settings. | sonnet | Read, Glob, Grep, Write, Edit, PowerShell |
| `workflow-author` | Writes GitHub Actions YAML for GitHub-hosted runners and checks it with actionlint. Flags required-check changes. | sonnet | Read, Glob, Grep, Write, Edit, Bash |
| `windows-chart-author` | Writes and reviews Helm charts for Windows container nodes. | sonnet | Read, Grep, Glob, Edit, Write, PowerShell |
| `minikube-fork-tracker` | Checks the minikube fork, upstream and the Windows VHD, and recommends pin and Kubernetes version bumps. | sonnet | Bash, Read, Grep, WebFetch, WebSearch |
| `winkube-cluster-doctor` | Diagnoses a running or failed win-kube cluster (nodes, networking, image import, Hyper-V isolation). | sonnet | PowerShell, Read, Grep, Glob |
| `windows-host-doctor` | Diagnoses the laptop's prerequisites (Hyper-V, groups, dockerd, resources) before or after `prereqs`. | haiku | PowerShell, Read, Glob, Grep |
| `markdown-reviewer` | Read-only review of Markdown against the lint config. Hands fixes to `markdown-fixer`. | haiku | Bash, Read, Glob, Grep, Agent |
| `markdown-fixer` | Fixes markdownlint errors by editing content. | haiku | Bash, Read, Edit, Glob, Grep |
| `ci-watcher` | Waits for a run or a PR's checks to finish, then reports the outcome and, for failures, `scripts/ci_triage.py`'s compact output. | haiku | Bash, Read |

## How models were chosen

- **haiku** for cheap, mechanical, or read-mostly work with a fixed procedure: watching CI (`ci-watcher`), running markdownlint and fixing what it says, host diagnostics, and `planning`, which fills in a fixed template and hands real work to other agents.
- **sonnet** for authoring and bounded diagnosis: PowerShell, workflows, charts, ADRs, the fork review, and cluster troubleshooting.
- **opus** for `governance`, a cross-cutting audit where missing something is expensive.

## How tools were chosen

- Reviewers and auditors (`governance`) have no shell and no write tools, so they can't change anything. `markdown-reviewer` keeps Bash only to run markdownlint, and has no Edit tool: it changes files only through `markdown-fixer`.
- Agents that drive Windows (Hyper-V, the Windows node, `powershell.exe` 5.1) get PowerShell; agents that drive `gh`, git, npx or uv get Bash. None gets both.
- `planning` and `adr` can write, but their prompts restrict them to `plans/` and `docs/adr/`. That is enforced by the prompt, not by Claude Code, so `governance` checks it.

## Delegation

```text
planning ──► powershell-author, windows-chart-author, workflow-author, adr, minikube-fork-tracker, ...
workflow-author ──► (caller updates the main ruleset when required checks change, ADR 0006)
windows-host-doctor / winkube-cluster-doctor ──► report only (the caller dispatches fixes)
markdown-reviewer ──► markdown-fixer
governance ──► report only (the caller dispatches fixes)
```

`planning` and `markdown-reviewer` have the Agent tool, so they can start the agents they hand off to. Claude Code subagents can't start other subagents, though, so this only works when they run as the main agent. Running as a subagent, `planning` returns the plan with an owner on every task, and `markdown-reviewer` ends its report by naming the files for `markdown-fixer`. Every other hand-off is a recommendation in the agent's report.
