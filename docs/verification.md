# Verification

## What this document is

Four behavioural scenarios, run by hand on a temporary git repository. They check that the pack **does what the doctrine says**: direct answers for questions, one worker for one edit, isolated parallel workers for disjoint files, and independent A/B review for larger changes.

What this document is not:

- **Not a benchmark.** No timing, no token counts, no comparison against a single agent or against other packs. Four runs on one machine prove the wiring, not the economics.
- **Not a test suite.** The temporary repo had a trivial check (a script that exits non-zero on a broken fixture), not a real business test suite with meaningful coverage.
- **Not exhaustive.** Model behaviour varies between runs. A scenario passing once means the path is reachable, not that it is guaranteed.

Environment for all runs: OpenCode 2.2.3, Windows 11, DeepSeek V4.1 Flash 1017, PowerShell 7.

The transcripts below are summaries: agent counts, verdicts, branches, and where behaviour diverged. They are not raw terminal captures.

## Setup

```bash
mkdir <repo> && cd <repo>
git init
git commit --allow-empty -m "chore: init"
# add a small fixture: one module with two files, one test script
git add -A && git commit -m "test: fixture"
```

`<repo>` is a throwaway repository. Every scenario starts from a clean tree:

```bash
cd <repo>
git status --porcelain   # expect empty output
```

## Scenario 1 - pure question

**Purpose.** Confirm the orchestrator does not manufacture work for a question that needs no code change.

**Command template.**

```bash
cd <repo>
opencode
# select: orchestrator
# prompt: "Explain what this repository does. Do not modify anything."
```

**Expected.** A direct answer. No todo list, no subagent calls, no worktree, no commit.

**Observed.** Answered from `read`/`glob`/`grep` in the main session. Zero subagents created, no todo list, working tree unchanged.

**Known deviations.** On a repo large enough to exceed a comfortable read, the orchestrator may call `explore` once. That is within the doctrine ("read / locate -> one explore") and is not a failure.

## Scenario 2 - single edit

**Purpose.** Confirm a one-file change goes to exactly one worker and gets verified without a review ceremony.

**Command template.**

```bash
cd <repo>
opencode
# select: orchestrator
# prompt: "In src/<file>, rename <symbol> to <new_symbol> and update its call sites in the same file. Run the check script."
```

**Expected.** One `worker`, no worktree (serial path), optional `verifier` when a check command exists, then a report with the changed file and the verification result.

**Observed.** One worker edited the file in the main tree. The test fixture had no runnable check, so no `verifier` session was created; the orchestrator read the file back and labeled the result `read-back verified`. No reviewer was invoked, because the change was one file and under the review threshold.

**Known deviations.**

- No `verifier` when the repo has no runnable check; the orchestrator then does a read-back and must label it "read-back verified", not PASS.
- Serial worker edits are not auto-committed. The change stays uncommitted unless the user asks for a commit.

## Scenario 3 - two files, parallel

**Purpose.** Exercise the full git-gated parallel path: state probe, two worktrees, two workers committing independently, merge, verification, review.

**Command template.**

```bash
cd <repo>
opencode
# select: orchestrator
# prompt: "Add feature A in src/a.<ext> and feature B in src/b.<ext>. The files are independent. Run the check script after merging."
```

**Expected sequence.**

1. `scout` reports `GIT=yes`, `COMMITS>=1`, `DIRTY_TRACKED=0`, `UNTRACKED_COUNT=0`.
2. Two `worktree_create` calls, one per module, under the configured worktree directory.
3. Two `worker` sessions in parallel. Each moves into its worktree, runs `git switch -c work/<module>`, edits, commits, and reports branch + SHA.
4. Orchestrator moves both sessions back with `session_move`.
5. `merger` merges both branches into the base branch, runs the check script, deletes the merged branches, removes the worktrees.
6. `verifier` runs the full check on the merged result: PASS.
7. `reviewer-correctness` returns APPROVE.

**Observed.** All seven steps in order. Two distinct branches and two commits; the merge was fast-forward-free but conflict-free; verifier PASS; reviewer APPROVE. Total subagents: scout, 2 workers, merger, verifier, 1 reviewer.

**Known deviations.**

- **Detached HEAD.** Each new worktree started detached. Without the explicit `git switch -c`, the worker's commit would not be on a branch and the merge step would find nothing. This is the single most likely place for a new user to get stuck.
- **Empty directory shells.** After `worktree_remove`, the two worktree directories still existed as empty folders. Git state was clean. They can be deleted after the session that holds them ends or after an app restart.
- **Merge ordering.** The two branches touched disjoint files, so order did not matter. With overlapping files the orchestrator must go serial; the pack does not attempt semantic conflict resolution beyond trivial cases.

## Scenario 4 - four files, larger change

**Purpose.** Check the review escalation path: one worker for a multi-file change, then two independent reviewers in parallel.

**Command template.**

```bash
cd <repo>
opencode
# select: orchestrator
# prompt: "Refactor <module> across four files: <file1> <file2> <file3> <file4>. Keep behaviour identical. Run the full check."
```

**Expected.** One `worker` (the files are coupled, so parallel has no benefit), `verifier` PASS, then `reviewer-correctness` and `reviewer-adversarial` launched **in parallel** with separate prompts, both APPROVE, and a merged findings list.

**Observed.** One worker, one commit-less serial edit, verifier PASS, two reviewers launched in the same step. Both returned APPROVE with non-blocking notes. This run did not produce a BLOCKER, so the return-to-worker path was not exercised.

**Known deviations.**

- The reviewers ran on the working-tree diff (`git diff` against the base commit), not on a merge commit, because the change was serial. For worktree changes the diff base is the merge target.
- A reviewer may return APPROVE with notes. Only BLOCKER-level findings send work back to the worker.
- If the two reviewers disagree, the orchestrator adjudicates against the code and records the reasoning; it does not average verdicts.

## Deviation summary

| Symptom | Likely cause | Fix |
|---|---|---|
| Worker commits but merger sees no branch | Worktree was left on detached HEAD | Worker must run `git switch -c work/<module>` before committing |
| Parallel path silently becomes serial | `DIRTY_TRACKED > 0`, no commits, or overlapping scopes | Commit/stash your own work, or accept serial |
| No verifier verdict | Repo has no runnable check | Add a check command, or accept read-back verification |
| `worktree_remove` leaves folders | Windows handle held by a session | Restart, then delete the empty folders |
| Only one reviewer for a large diff | Change classified as small | Check the review table; escalate explicitly |

## Reproducing

Run the four scenarios in order on a fresh temporary repo. A pass means: the agent count and order match the "Expected" section, the verifier verdict is PASS, and no agent wrote outside its scope. Record your OpenCode version, OS, and model alongside the result; behaviour is model-dependent and the matrix in [`compatibility.md`](compatibility.md) is version-specific.
