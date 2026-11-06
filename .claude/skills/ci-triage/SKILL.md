---
name: ci-triage
description: Find out why a GitHub Actions run, PR or branch failed in win-kube, cheaply. It prints only each failed job's failing step and error lines instead of whole logs. Use whenever a check is red, before reading any log, and when waiting for CI to finish.
---

# CI triage

Whole job logs are tens of thousands of tokens, almost all noise. Always start with the triage script:

```bash
uv run python scripts/ci_triage.py --pr 42           # every failed check on a pull request
uv run python scripts/ci_triage.py --run 42080211633 # one workflow run
uv run python scripts/ci_triage.py --branch main     # the latest failed run on a branch
```

For each failed job it prints the job, the step that failed, and the lines that look like errors, plus the last few lines, with timestamps and checkout noise removed. Exit code 1 means something failed; 0 means nothing did.

Only if that isn't enough, read one job's failed-step log, and only its tail:

```bash
gh run view --job <job-id> --log-failed | tail -60
```

## Waiting for CI

Don't poll in a tight loop, and don't stream logs while waiting. Either:

- start the `ci-watcher` agent, which waits and reports only the outcome, or
- run one background command and wait for its notification:

  ```bash
  until [ "$(gh run view <run-id> --json status -q .status)" = completed ]; do sleep 60; done; uv run python scripts/ci_triage.py --run <run-id>
  ```

## Known failure patterns in this repo

| Symptom | Usual cause |
| --- | --- |
| A required check shows "Expected - waiting for status" and never runs | Its workflow has a path filter, or the job was renamed without updating the ruleset (ADR 0006). |
| `PSScriptAnalyzer: N finding(s)` | Run `./scripts/Invoke-RepoScriptAnalyzer.ps1` locally; the `::error` lines name file, line and rule. |
| `PSUseCompatibleSyntax` or `PSUseCompatibleCommands` | PowerShell 7-only syntax or a parameter missing in 5.1 (ADR 0007). |
| Pester passes on ubuntu but fails on windows-latest | A 5.1 difference: `ConvertFrom-Json` output shape, `Set-Content` encoding, or native stderr under `ErrorActionPreference = 'Stop'`. |
| The cmdlet docs check fails with a diff | Comment-based help changed without regenerating `docs/cmdlets/`. |
| `Required test coverage of 95% not reached` | A new branch in `scripts/*.py` without a test. |
| markdownlint fails only in CI | The PR merged with main brings in a new file; run `uv run pre-commit run --all-files`. |
