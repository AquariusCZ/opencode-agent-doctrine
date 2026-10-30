# Manual smoke tests

Four scenarios to run by hand after installing the pack. They check behaviour, not performance. Use a throwaway git repository and a model you intend to use in practice.

Placeholders:

- `<repo>` - path to the throwaway repository.
- `<file>`, `<module>`, `<branch>` - names you choose.
- `<check>` - a command that fails on a broken change, e.g. `pwsh -File ./check.ps1` or `npm test`.

Do not run these on a repository with uncommitted work you care about.

## Preconditions

1. Agents installed and visible:

   ```bash
   opencode debug agents
   ```

   Expect all eight: orchestrator, worker, verifier, reviewer-correctness, reviewer-adversarial, scout, merger, researcher.

2. Config loaded: new sessions default to `orchestrator`.

3. Fixture repo is a git repo with at least one commit and a runnable `<check>`:

   ```bash
   cd <repo>
   git init
   git add -A && git commit -m "test: fixture"
   git status --porcelain
   ```

   Expect empty output from the last command.

## Scenario 1 - pure question

**Steps**

1. Open OpenCode in `<repo>` and select `orchestrator`.
2. Send: `Explain what this repository does. Do not modify anything.`
3. Do not answer follow-up prompts yourself; observe only.

**Expected**

- One assistant answer, based on `read`/`glob`/`grep` or a single `explore`.
- No todo list.
- No `worker`, `verifier`, `scout`, or reviewer sessions.
- `git status --porcelain` is empty afterwards.

**Failure signs**

- A todo list appears for a question.
- A worker is spawned "to look around".
- Any file changes.

## Scenario 2 - single edit

**Steps**

1. In `<repo>`, note the current commit: `git rev-parse --short HEAD`.
2. Select `orchestrator` and send:
   `In <file>, rename <symbol> to <new_symbol> and update its call sites in the same file. Run <check>.`
3. Wait for the final report.

**Expected**

- Exactly one `worker` session.
- No worktree is created (serial path).
- The worker edits only `<file>`.
- If `<check>` exists, `verifier` runs it and reports PASS; otherwise the orchestrator does a read-back and says "read-back verified", not PASS.
- The change remains uncommitted (serial edits are not auto-committed).

**Failure signs**

- More than one worker for one file.
- A claim of "tests pass" with no verifier session and no command output.
- Edits outside `<file>`.

## Scenario 3 - two files in parallel

**Steps**

1. Confirm a clean tree and at least one commit:

   ```bash
   cd <repo>
   git status --porcelain
   git log --oneline -1
   ```

2. Select `orchestrator` and send:
   `Add feature A in <file1> and feature B in <file2>. The files are independent. Run <check> after merging.`
3. Watch the sessions panel. Do not interrupt.
4. When it finishes, inspect:

   ```bash
   git worktree list
   git branch --list 'work/*'
   git log --oneline --graph -5
   ```

**Expected**

1. `scout` runs first and reports `GIT=yes`, `COMMITS>=1`, `DIRTY_TRACKED=0`, `UNTRACKED_COUNT=0`.
2. Two worktrees are created outside the repo (under the configured worktree directory).
3. Two workers run concurrently. Each moves into its worktree, creates a branch (`git switch -c work/<module>`), edits one file, commits, and reports branch + SHA.
4. Each worker session is moved back to the main directory.
5. `merger` merges both branches, runs `<check>`, deletes merged branches, removes worktrees.
6. `verifier` runs `<check>` on the merged result: PASS.
7. One `reviewer-correctness` returns APPROVE.

**Failure signs**

- Workers edit in the main tree instead of worktrees.
- A worker commits on a detached HEAD and `merger` reports nothing to merge.
- Merge happens before both workers report.
- Verifier runs before the merge.

**Cleanup if it fails**

```bash
cd <repo>
git worktree list
git worktree remove <worktree-path> --force
git branch -D work/<module>
```

## Scenario 4 - four files, larger change

**Steps**

1. Confirm a clean tree.
2. Select `orchestrator` and send:
   `Refactor <module> across <file1> <file2> <file3> <file4>. Keep behaviour identical. Run <check>.`
3. After the verifier reports, watch for the review phase.

**Expected**

- One `worker` (the files are coupled; parallel is not attempted).
- `verifier` PASS with the `<check>` output summarized.
- `reviewer-correctness` and `reviewer-adversarial` start in the **same step**, with different prompts.
- Both return APPROVE, or one returns findings that the orchestrator routes back to the worker.
- The final report lists deduplicated findings.

**Failure signs**

- Only one reviewer for a four-file change.
- The second reviewer receives the first reviewer's findings before producing its own.
- A reviewer edits files (it should have no edit permission).
- APPROVE without a verifier PASS.

## Post-run checks

```bash
cd <repo>
git status --porcelain
git worktree list
```

- Working tree contains only intended changes.
- No worktrees remain registered.
- On Windows, empty worktree folders may remain; delete them after closing the sessions.

Record the OpenCode version, OS, and model with the results. Behaviour is model-dependent; a scenario that passes on one model may need a stronger prompt on another.
