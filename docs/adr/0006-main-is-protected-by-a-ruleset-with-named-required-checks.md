# 0006. main is protected by a ruleset with named required checks and squash-only merges

- Status: Accepted
- Date: 2026-11-05
- Deciders: Justin Dearing
- Related: [`.github/workflows/`](../../.github/workflows/), [`.claude/skills/pr-shepherd/SKILL.md`](../../.claude/skills/pr-shepherd/SKILL.md)

## Context

Changes reach `main` through pull requests, often opened by agents. GitHub has no "require every check" setting: a ruleset lists required checks by name. A required check from a workflow with path filters never starts on PRs outside those paths, and then blocks the merge forever.

## Decision

- The `main` ruleset requires a pull request (0 approvals, since a solo maintainer can't approve their own PR), resolved conversations, and squash merges only. It blocks force pushes and deletion, and has no bypass actors, administrators included.
- Required status checks are listed by job name and must pass on a branch that is up to date with `main` (strict).
- Workflows that provide a required check have **no path filters**. A job's name is its check name, so renaming a job or adding a required job means updating the ruleset in the same PR.
- The repository allows only squash merges, uses the PR title and body as the commit message, and deletes head branches after merging.
- CI runs on GitHub-hosted `ubuntu-latest`, or `windows-latest` when it needs Windows (for example Windows PowerShell 5.1).

## Consequences

- `main` history is one commit per PR.
- Every PR runs every required workflow, which costs a little more CI time.
- Nobody, including agents with admin tokens, can merge a red PR or push to `main` directly.

## Alternatives considered

- **A single aggregating `ci-ok` job as the only required check.** It covers new jobs automatically, but was not chosen; the maintainer prefers each check listed explicitly.
- **Classic branch protection.** Rulesets are the current mechanism and can be read by anyone with access to the repo.
