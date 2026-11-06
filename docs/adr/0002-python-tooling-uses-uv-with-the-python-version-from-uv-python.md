# 0002. Python tooling uses uv, with the Python version set by the `UV_PYTHON` environment variable

- Status: Accepted
- Date: 2026-11-05
- Deciders: Justin Dearing
- Related: windows-nano-demos ADR 0010, [`pyproject.toml`](../../pyproject.toml), [`.github/workflows/python.yml`](../../.github/workflows/python.yml)

## Context

The repo's product is PowerShell and Helm. It also carries a few Python helper scripts ported from windows-nano-demos (`scripts/ci_triage.py`, `scripts/repo_status.py`, `scripts/union_merge.py`) that keep CI triage and PR shepherding cheap for agents, and the pre-commit framework is Python. Developer machines are Windows, where `python` is often only the Microsoft Store stub.

## Decision

- [uv](https://docs.astral.sh/uv/) manages Python and the packages. The root `pyproject.toml` declares them, with `[tool.uv] package = false`, and `uv.lock` is committed.
- The interpreter version comes from `UV_PYTHON` together with `UV_PYTHON_PREFERENCE=only-managed`, so uv downloads exactly that CPython and never uses one already on the machine. CI sets both at workflow level, and `.claude/settings.json` sets them for Claude Code sessions.
- Commands run through `uv run`, for example `uv run pytest` and `uv run pre-commit run --all-files`.
- Coverage of `scripts/*.py` stays at 95% or more (`[tool.coverage.report] fail_under`).

## Consequences

- One tool installs Python, creates the environment and runs the tests on Windows and Linux. CI needs only `astral-sh/setup-uv`, pinned to a commit.
- Contributors need uv (`winget install astral-sh.uv`) to run the hooks, even if they only touch PowerShell.

## Alternatives considered

- **Rewrite the helpers in PowerShell.** They are proven in windows-nano-demos with tests, and keeping them identical lets fixes flow between the repos.
- **pip and venv with `requirements.txt`.** It needs a system Python first and has no lock file with hashes.
