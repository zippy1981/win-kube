"""Tests for the scripts' I/O edges and main() functions: gh and git are faked, so these run offline."""

from __future__ import annotations

import json
import subprocess
from pathlib import Path
from types import SimpleNamespace

import ci_triage
import pytest
import repo_status
import union_merge


def completed(stdout: str = "", returncode: int = 0) -> SimpleNamespace:
    return SimpleNamespace(stdout=stdout, returncode=returncode)


# --- the thin subprocess wrappers ---


@pytest.mark.parametrize(
    ("module", "args", "command"),
    [
        (ci_triage, ["run", "list"], ["gh", "run", "list"]),
        (repo_status, ["git", "status"], ["git", "status"]),
    ],
    ids=["ci_triage.gh", "repo_status.run"],
)
def test_subprocess_wrappers_return_stdout(monkeypatch, module, args, command) -> None:
    seen = []
    monkeypatch.setattr(subprocess, "run", lambda cmd, **kw: seen.append(cmd) or completed("out"))
    runner = getattr(module, "gh", None) or module.run
    assert runner(args) == "out"
    assert seen == [command]


# --- ci_triage ---


RUN = {"name": "PowerShell", "headBranch": "main", "headSha": "abcdef0123", "conclusion": "failure", "url": "u"}


class TestCiTriageMain:
    def _gh(self, jobs: list[dict], log: str | Exception = "E  boom\n", runs: str = "[]"):
        def fake(args: list[str]) -> str:
            if args[:2] == ["run", "view"] and "--json" in args:
                return json.dumps(dict(RUN, jobs=jobs))
            if args[:2] == ["run", "view"]:
                if isinstance(log, Exception):
                    raise log
                return log
            return runs

        return fake

    def test_report_lists_failed_jobs_with_their_errors(self) -> None:
        jobs = [{"databaseId": 7, "name": "pester (windows)", "conclusion": "failure", "steps": []}]
        text = ci_triage.report(1, self._gh(jobs))
        assert "### pester (windows): failure at step '(no failed step)'" in text and "E  boom" in text

    def test_report_survives_a_missing_log(self) -> None:
        jobs = [{"id": 7, "name": "b", "conclusion": "timed_out", "steps": []}]
        failure = subprocess.CalledProcessError(1, "gh")
        assert "(no log available yet)" in ci_triage.report(1, self._gh(jobs, log=failure))

    def test_report_says_when_nothing_failed(self) -> None:
        assert "No failed jobs." in ci_triage.report(1, self._gh([]))

    def test_main_with_a_run_exits_1(self, capsys) -> None:
        assert ci_triage.main(["--run", "5"], run_gh=self._gh([])) == 1
        assert "## PowerShell" in capsys.readouterr().out

    def test_main_with_a_green_pr_exits_0(self, capsys) -> None:
        assert ci_triage.main(["--pr", "3"], run_gh=self._gh([], runs="[]")) == 0
        assert "No failed runs." in capsys.readouterr().out

    def test_main_with_a_branch_uses_its_latest_failed_run(self) -> None:
        assert ci_triage.main(["--branch", "main"], run_gh=self._gh([], runs='[{"databaseId": 9}]')) == 1


# --- repo_status ---


def test_repo_status_lists_prs_ci_queue_and_dirty_worktrees(capsys) -> None:
    def fake(args: list[str]) -> str:
        if args[:2] == ["gh", "pr"]:
            return json.dumps(
                [
                    {"number": 2, "isDraft": True, "headRefName": "b", "baseRefName": "a", "statusCheckRollup": []},
                    {
                        "number": 1,
                        "isDraft": False,
                        "headRefName": "a",
                        "baseRefName": "main",
                        "statusCheckRollup": [{"conclusion": "SKIPPED"}],
                    },
                ]
            )
        if args[:2] == ["gh", "repo"]:
            return "o/r\n"
        if args[:2] == ["gh", "api"]:
            return json.dumps({"total_count": 3 if "in_progress" in args[2] else 4})
        if args[:2] == ["git", "worktree"]:
            return "worktree /a\nbranch refs/heads/main\n\nworktree /b\ndetached\n"
        if args[2] == "/b":
            raise subprocess.CalledProcessError(128, "git")
        return " M x\n"

    assert repo_status.main([], run_cmd=fake) == 0
    out = capsys.readouterr().out
    assert "- #1 a: 1 skip" in out and "- #2 (draft) b -> a: no checks" in out
    assert "workflow runs: 3 in progress, 4 queued" in out
    assert "/a [main] 1 dirty" in out and "/b [(detached)] -1 dirty" in out


# --- union_merge ---


class TestUnionMergeMain:
    def test_needs_a_file(self, capsys) -> None:
        assert union_merge.main([]) == 2
        assert "usage" in capsys.readouterr().err

    def test_resolves_a_file_in_place(self, tmp_path: Path, capsys) -> None:
        path = tmp_path / "README.md"
        path.write_text("<<<<<<< HEAD\nours\n=======\ntheirs\n>>>>>>> b\n", encoding="utf-8")
        assert union_merge.main([str(path)]) == 0
        assert path.read_text(encoding="utf-8") == "ours\ntheirs\n"
        assert "resolved 1 conflict(s)" in capsys.readouterr().out
