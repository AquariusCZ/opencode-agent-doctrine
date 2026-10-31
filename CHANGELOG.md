# Changelog

## 0.1.4 - 2026-10-30

- Add a task graph convention with `depends_on` dependencies.
- Add a spawn circuit breaker and rate-limit backoff.
- Add merge overlap checks, branch preservation, and WIP commits before cleanup.
- Document the scheduling protocol and the overlapping-branches test.

## 0.1.3 - 2026-10-30

- Add a concrete adversarial checklist (deleted tests, weakened CI, new dependencies, network calls, permission widening, destructive commands).
- Require workers to verify `pwd` after `session_move` and report it; reject mismatched worktrees.

## 0.1.2 - 2026-10-30

- Tighten review: default single correctness review; A/B only for critical paths, >5 files/300 lines, or explicit request.
- Cap review at two rounds; only BLOCKER/MAJOR are actionable; new features/APIs/refactors are follow-ups.
- Require a concrete reproducible failure for BLOCKER; speculative findings are NIT.
- Workers do not expand scope while fixing review findings.
- Document that goals need a concrete done-when.

## 0.1.1 - 2026-10-30

- Add GitHub Actions publish workflow with npm trusted publishing (OIDC).
- Add `docs/publishing.md`.

## 0.1.0 - 2026-10-30

- npm installer: `npx opencode-agent-doctrine install`.
- Initial release: orchestrator, worker, verifier, scout, merger, researcher, reviewer-correctness, reviewer-adversarial.
- Doctrine for triage, delegation contract, git-gated worktree parallelism, and risk-proportional A/B review.
- Install/uninstall scripts for PowerShell and bash.
- Verified on OpenCode 2.2.3, Windows 11, DeepSeek V4.1 Flash 1017.
