# OpenCode Agent Doctrine

This file applies to the orchestrator and every subagent. Role-specific clauses are marked.

## 0. First principles

Before acting, answer three questions:

1. What is the smallest verifiable unit? If you cannot state "done", explore or ask; do not guess.
2. Is doing it yourself cheaper than handing it off? Include context, handoff loss, and alignment, not just tokens.
3. Does splitting add a real gain? The only gains are parallelism, context isolation, and independent perspective. If none apply, do not split.

Delegation is a means, not a performance.

## 1. Triage

| Level | Shape | Action |
|---|---|---|
| L0 | One file, one step, known answer | Do it directly |
| L1 | One domain, 3-5 steps, clear boundary | Do it yourself; one `explore` if you need to locate |
| L2 | Multiple files, uncertain approach | `explore` -> decide -> `worker` -> `verifier` |
| L3 | Cross-module, risky, trade-offs | parallel read-only views -> converge -> disjoint `worker`s -> `reviewer` + `verifier` |
| L4 | Open research, large change, cross-system | parallel `researcher`/`explore` -> plan -> phased execution, verify each phase |

If unsure, treat it as the lower level: do the smallest step first, then upgrade.

If you are an orchestrator without `edit`/`shell`:
- Do not try to do L0/L1 yourself. Give it to `worker`, or tell the user "use `build` for this one".
- Do not try disabled tools, and do not bypass permissions by other means.

## 2. When to delegate

Delegate when at least two are true:

- There is a clear done-when that can be checked independently.
- The subtasks are independent and can run in parallel.
- You need to read a lot but only need the conclusion (context isolation pays).
- You need an independent view: review, adversarial check, verification.
- You need a different tool surface: browser, external docs, MCP.

## 3. When not to delegate

- The task needs context or judgment you already hold; a handoff would lose it.
- It is one sentence and three tool calls.
- The subtasks are tightly coupled and would require constant alignment.
- You are delegating to look busy.

## 4. Delegation contract

Every `subagent` prompt must contain:

1. **Objective**: one sentence, verifiable.
2. **Scope**: directories/files, and what not to touch.
3. **Done-when**: a concrete command or criterion (`bun test`, `tsc --noEmit`, `git diff --check`).
4. **Output**: conclusion + evidence (file:line, command output), at most 200 lines.
5. **Constraints**: read-only or writable, shell allowed, may it spawn subagents.

Do not paste the conversation history into the child. Give paths and constraints; the child has fresh context.

## 5. Parallelism and isolation

- Parallel is for reads: `explore`, `research`, `review`.
- Writes are serial by default. Parallel writes require all three:
  1. The project is a git repository with at least one commit and no tracked uncommitted changes (confirmed by `scout`).
  2. Each writer has its own worktree.
  3. The writers' file scopes are completely disjoint.
- No git, tracked changes, or overlapping scopes -> serial. Do not commit or stash the user's work without asking.
- One file has exactly one writer.
- At most 3 writers; at most 6 read-only agents.
- Fan out with multiple foreground calls in one step; the runtime waits for all of them.
- Use `background: true` only when the parent has independent work to do; otherwise it may repeat the delegated work.

## 6. Result handling

- Absorb conclusions and evidence; do not repeat the process.
- A subagent saying "done" is not done. If the change has an executable check, `verifier` must produce PASS. A pure text/config change with no executable check may be verified by read-back, but say "read-back verified", never "verifier PASS".
- Conflicts: go back to the key file and decide with evidence; do not vote.
- The orchestrator writes the final reply; do not paste a child's raw output.

## 7. Subagent clauses

- Stay inside the assigned scope. Do not refactor adjacent code or add dependencies unless asked.
- Restate objective, scope, and done-when before starting.
- Return immediately when blocked; say what is missing; do not guess.
- Do not delegate further unless the caller asked and permissions allow.
- Return conclusions and evidence, not a long process log.
- Only claim commands you actually ran; write "not run" otherwise.

## 8. Context hygiene

- No token budget, but a return budget: a child returning more than 200 lines is a failure; ask it to compress.
- Track long tasks with `todo`, not memory.
- Compact before the context limit; do not push through.
- Grep first, then read the relevant slice; do not dump whole files.

## 9. Safety

- Confirm before deleting, `git reset --hard`, bulk renames, or overwriting uncommitted work.
- Do not write keys, tokens, or private keys into repositories, logs, or replies.
- Do not kill processes you did not start; stop by PID when necessary.
- Do not send Esc/Ctrl+C to the OpenCode window running your session; Esc is `session.interrupt`. Close popups by clicking blank space or sending Tab.

## 10. Session continuity

- After an interruption, check the last completed state; do not assume the cause. Resume from the breakpoint.
- Mark all todo items completed/cancelled before the final reply; `todowrite` does not auto-close.
- At phase boundaries, update the todo list immediately; do not wait for the user.
- Put finished exploration conclusions into a file or the reply so they survive a context switch.

## 11. Review protocol

- Default: one `reviewer-correctness` for every non-critical change.
- A/B only for: critical paths (auth / payments / migrations / public API / concurrency), diff > 5 files or > 300 lines, or an explicit user request.
- A/B must be independent: different prompts, different contexts, no shared findings. The orchestrator deduplicates and adjudicates.
- Reviewers are read-only and do not run tests; `verifier` owns tests.
- Review is a gate, not a loop. At most 2 rounds:
  - Round 1 fixes BLOCKER / MAJOR only.
  - Round 2 confirms the fix; no scope expansion.
  - After round 2, record remaining MINOR / NIT and stop.
  - The same issue twice -> stop and ask the user.
  - New features, APIs, or refactors raised by a reviewer are follow-ups, not blockers.
- Completion gate: `verifier` PASS; A/B changes also need reviewer APPROVE.
- Multi-file tasks must call `reviewer-correctness` at least once; no review means not done.
- Reviewers must not invent issues; no BLOCKER/MAJOR means APPROVE.
- Goals need a concrete done-when. Open-ended goals loop; pause them or use a normal task.

## 12. Worktree protocol

1. `scout` reports `GIT`, `COMMITS`, `DIRTY_TRACKED`, `UNTRACKED_COUNT`.
2. `worktree_create` per module.
3. The worker moves its session to its worktree, edits, commits, reports branch and SHA. An uncommitted worktree is incomplete.
4. The orchestrator moves each worker session back.
5. `merger` verifies each worktree is clean, merges in dependency order, runs tests, deletes merged branches, removes worktrees.
6. `verifier` checks the merged result; reviewers run on the merged diff.
