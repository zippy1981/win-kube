---
name: pr-shepherd
description: Move pull requests in win-kube through rebase, conflict resolution and squash merge safely - including stacked PRs and list-like files such as the ADR index. Use when a PR conflicts with main, when a stack needs retargeting, or when asked to merge once checks pass.
---

# PR shepherd

`main` is protected by a ruleset (ADR 0006): pull requests only, squash merges only, resolved conversations, and named required checks that must pass on a branch up to date with `main`. Nobody bypasses it.

## Bring a branch up to date with main

Work in the branch's own worktree. Never use the user's main checkout.

```bash
git fetch origin
git merge origin/main        # or: git rebase origin/main
git diff --name-only --diff-filter=U   # files still in conflict
```

- **List-like files**, where both sides only add lines (`docs/adr/README.md`, the agents table in `.claude/agents/README.md`), are resolved by keeping both sides:

  ```bash
  uv run python scripts/union_merge.py docs/adr/README.md && git add docs/adr/README.md
  ```

- **Anything else**, such as PowerShell, workflows or chart templates, needs reading and resolving by hand. Never union code.
- **Before any push**, check that the merge or rebase actually finished. `git status` must not say "rebase in progress" or "You have unmerged paths".
- After resolving, run `uv run pre-commit run --all-files`, then push. Use `--force-with-lease`, never `--force`, after a rebase.
- Because checks are strict, a PR goes stale whenever `main` moves. `gh pr update-branch <n>` merges `main` into it on GitHub when there are no conflicts.

## Stacked pull requests

- A PR based on another PR's branch shows only its own diff. When the lower PR merges, its branch is deleted automatically and GitHub retargets the upper PR to `main`. Check with `gh pr view <n> --json baseRefName`.
- After a squash merge, the upper branch still contains the lower branch's original commits. Rebase it onto `main` (`git rebase --onto origin/main <old-lower-tip>`) so its diff stays clean.

## Merging

- Merge only when every check on the current head commit has passed (`gh pr checks <n>`), and only when the user asked for it. Never use `--admin`.
- Squash is the only method the repo allows:

  ```bash
  gh pr merge <n> --squash --match-head-commit "$(gh pr view <n> --json headRefOid -q .headRefOid)"
  ```

  Pinning the head commit makes the merge fail if someone pushed after the checks ran. `gh pr merge <n> --squash --auto` queues the same merge for when the checks pass.
- The squash commit uses the PR title and body, so keep them accurate before merging.
- `gh pr merge` may print `'main' is already used by worktree`. The merge on GitHub still happened; only the local cleanup step failed.
