# Limitations

The README lists these in short form. This page is the longer version, including what each limitation means in practice and what would have to change to remove it.

## 1. The pack is model-dependent

The doctrine tells the orchestrator when to delegate, which subagent to use, and when to escalate review. A model with weak instruction-following will still take shortcuts inside those rules:

- It may answer a multi-module task directly, then claim it was a single edit.
- It may pick `worker` for research or `researcher` for an edit.
- It may skip `verifier` when a check exists, or call it and ignore a FAIL.
- It may summarize a reviewer's finding instead of passing it through.

The permission boundary removes exactly one failure: the orchestrator cannot edit or run shell, so it cannot do the implementation itself. It cannot force good judgement about which subagent to pick.

Tested with DeepSeek V4.1 Flash 1017. Other models are untested. If you switch models, re-run the four scenarios in [`verification.md`](verification.md) before relying on the pack.

## 2. There is no benchmark

Four behavioural scenarios on a temporary repository are not a benchmark. The pack makes no claim about:

- wall-clock speed versus a single `build` session;
- token cost, including the overhead of subagent contexts and reviewer duplication;
- pass rate on real tasks, SWE-bench, or any public suite.

What the four scenarios show is that the wiring is reachable: worktrees get created, workers commit on branches, merges land, reviewers run independently. That is a different claim from "this makes you faster." For small tasks it probably does not.

## 3. Windows worktree directories can linger

`worktree_remove` unregisters the worktree from git and deletes its metadata. On Windows, the directory itself can remain as an empty shell when a session or an indexer still holds a handle to a file inside it.

Practical impact: none for git. `git worktree list` no longer shows it, and `git status` is clean. The folders are empty and can be deleted manually after the session ends or after an app restart. Repeated runs can accumulate a handful of empty folders under the worktree directory.

If removal fails with a permission error, close editors and let the antivirus scan finish, then delete the folder. Do not run `git worktree prune` while a session is still attached; that is the one case where cleanup can confuse a live worker.

## 4. Dirty tracked changes force the serial path

Parallel mode requires a clean tracked tree, because a worktree branches from `HEAD` and would silently not contain uncommitted edits. The orchestrator checks this via `scout` and falls back to serial workers in the main tree when the check fails.

The pack will **not** commit or stash your changes to make the check pass. That is deliberate: your uncommitted work is yours, and an agent that commits it to "enable parallelism" is a worse outcome than a slower run.

Consequence: if you habitually keep a dirty tree, you will rarely see the parallel path. Untracked files are reported but not automatically disqualifying; if they are inside a worker's scope, handle them first or go serial.

## 5. Serial edits are not auto-committed

Only worktree workers are required to commit before reporting, because the merge step needs a branch. Serial workers edit the working tree and stop.

This is intentional (it keeps the main tree's history under your control) but it has two effects:

- After a serial change, the orchestrator's report describes a diff that is not in git history. If the session is lost, the change is only on disk.
- `verifier` sees the working-tree state, so its PASS refers to uncommitted code. A later checkout or reset silently invalidates that verdict.

If you want every change committed, add that to your own global `AGENTS.md`; the pack does not enforce it.

## 6. Permissions are not a sandbox

`edit: "*" -> deny` and `shell: "*" -> deny` are capability rules inside OpenCode. They stop the orchestrator from using those tools. They do not restrict the process, the filesystem, or the network.

Any subagent with `shell` (worker, verifier, merger, scout's restricted git calls) runs commands as your user account. That means:

- it can read files outside the repository;
- it can write outside the repository if a command does so;
- it can reach the network unless your environment blocks it;
- it inherits your credentials, environment variables, and SSH agent.

A worker told to "run the tests" runs whatever the repository's test command is. Treat installing this pack the same as running any third-party script with your privileges: read `agents/*.md`, check the permission blocks, and prefer a container or a VM for untrusted repositories.

## 7. `worktree_create` behaviour can change between versions

The protocol documents what 2.2.3 does: create a worktree on a detached HEAD, no branch. Workers therefore create their own branch with `git switch -c`. If a later version starts creating a branch automatically, the worker instruction becomes either redundant (branch exists, switch fails) or subtly wrong (branch name mismatch with what `merger` expects).

There is no version negotiation in the pack. After an OpenCode upgrade, re-run Scenario 3 and check:

- `git -C <worktree> status` shows a branch, not "HEAD detached";
- `git branch --list 'work/*'` shows the worker branches;
- `merger` reports the merged branches by name.

The same applies to `session_move` and `worktree_remove` semantics. The pack depends on tool behaviour that is not part of a stable public contract.

## 8. This is not an official project

No affiliation with the OpenCode team. No support commitment. Issues are handled on a best-effort basis, and the API surface this pack depends on (agent frontmatter `permissions`, worktree tools, `experimental.subagent_depth`) is explicitly experimental upstream.

If an OpenCode release breaks the pack, the fix is a change to agent files or the doctrine, not a patch to OpenCode.

## 9. Smaller caveats

- **Review cost.** A/B review doubles reviewer tokens on large diffs. The threshold (2 files / 80 lines) is a heuristic, not a measurement.
- **Reviewer quality.** Two reviewers with the same model share the same blind spots. Different prompts reduce, but do not eliminate, correlated misses.
- **No background job management.** If a worker session dies mid-task, its worktree and branch remain. Cleanup is manual.
- **No dependency graph between modules.** Merge order is decided by the orchestrator, not by a build graph; coupled modules must be merged in the order the orchestrator chooses.
- **Docs are English-only.** Translations are welcome but not maintained here.
