# Architecture

## Design goal

The pack has one job: make delegation, isolation, and review **structural** instead of aspirational. Every mechanism below exists to remove a choice that a model would otherwise get wrong under time pressure.

## Agent roster

| Agent | Mode | Read | Write | Shell | Subagents | Purpose |
|---|---|---|---|---|---|---|
| `orchestrator` | primary | yes | **no** | **no** | allow (depth 2) | Triage, plan, delegate, adjudicate, report |
| `worker` | subagent | yes | yes | yes | deny | Scoped implementation in one worktree |
| `verifier` | subagent | yes | **no** | yes | deny | Run tests/build/lint; report PASS/FAIL |
| `reviewer-correctness` | subagent | yes | **no** | allowed, instruction-restricted (read-only) | deny | Find correctness bugs in the diff |
| `reviewer-adversarial` | subagent | yes | **no** | allowed, instruction-restricted (read-only) | deny | Try to break the change; find missing cases |
| `scout` | subagent | yes | **no** | allowed, instruction-restricted (git state only) | deny | Report repo state before parallel writes |
| `merger` | subagent | yes | yes | yes | deny | Merge branches, run tests, clean up worktrees |
| `researcher` | subagent | yes | **no** | **no** | deny | External docs and citations |

`explore` is the built-in OpenCode agent and is used read-only. No agent in this pack has both an unrestricted write scope and the ability to spawn writers.

Only `edit` and `shell` denials are permission-enforced. `scout` and the two reviewers have `shell` allowed but instruction-restricted (git state for scout, read-only diff inspection for reviewers); their shell scope is a prompt constraint, not a permission rule. `researcher` has `shell: deny` and `edit: deny`.

## Why the orchestrator cannot edit or run shell

A model that can do the work will do the work. Not because it is lazy, but because the shortest path to "done" is to make the edit yourself. Prompt instructions ("you must delegate") are advisory; they lose to the path of least resistance on long tasks.

Denying `edit` and `shell` turns delegation from a policy into the only available action. The orchestrator still reads, greps, plans, and talks to subagents - it keeps every decision and every piece of context. What it loses is the ability to bypass its own process.

The boundary also improves the review trail. When the orchestrator never touches files, the only writer for any given file is a named worker session, and the only way that work enters the main branch is through `merger`. Attribution stays intact.

Two caveats:

- This is a **permission boundary, not a sandbox.** A subagent that has `shell` still runs with your user account's privileges.
- A weak model can still under-delegate or pick the wrong subagent. The boundary removes one failure mode (doing the work itself), not all of them.

## Why reviewers need independent contexts

Self-review is a known failure: given its own diff, a model reads what it intended to write, not what it actually wrote. A second pass in the same context inherits the same assumptions, the same summary of the task, and often the same blind spots.

The protocol therefore separates reviewers at three levels:

1. **Separate sessions.** Each reviewer is a subagent with its own context window and no memory of the worker's reasoning.
2. **Separate prompts.** Correctness asks "does this do what was specified, and does it break existing behavior?" Adversarial asks "what input, state, or ordering breaks this?" Same diff, different questions.
3. **No cross-contamination.** The orchestrator does not pass one reviewer's findings to the other before both return. Findings are merged afterwards, with duplicates collapsed and conflicts resolved against the code, not by vote.

Reviewers have no `edit`. They do have `shell` for reading the diff, but it is instruction-restricted, not a hard boundary; if you need the stronger guarantee, deny `shell` and pass the diff in the prompt. They cannot fix what they find, so their output is a verdict and a list of findings, which is easier to audit than a silent patch.

## Why parallel writes require git state, worktrees, and disjoint scopes

Three conditions, each closing a different failure:

- **Git repository with at least one commit.** `worktree_create` needs a commit to branch from. A repo with no history has nothing to isolate.
- **No tracked uncommitted changes.** A worktree branches from `HEAD`, not from your working tree. Uncommitted tracked edits would silently not exist in the worktree, and the merge would produce a diff that does not match what the worker saw. The pack refuses to stash or commit on your behalf, so it falls back to serial.
- **Disjoint file scopes.** Worktrees isolate the filesystem, not semantics. Two workers editing the same file will conflict at merge time, and conflict resolution is where parallel gains evaporate. Disjoint scopes make the merge mechanical.

A fourth condition is operational: at most three writers. Beyond that, merge order, review load, and the orchestrator's own attention become the bottleneck.

If any condition fails, the orchestrator uses serial workers in the main tree. Serial is the default; parallel is the exception that has to be earned.

## Flow

```text
user request
   |
   v
orchestrator (read-only): triage
   |
   +-- Q&A / explanation ------------------------------> answer
   +-- locate code ---------> read/glob/grep or explore -> answer
   +-- one edit ------------> worker -> (verifier) -----> report
   |
   `-- multi-file
         |
         +-- no parallel benefit --> worker -> worker -> verifier -> review
         |
         `-- parallel benefit --> scout
                                   |
                                   +-- dirty / no commits --> serial path
                                   |
                                   `-- clean + disjoint --> worktrees
                                                              |
                                          worker A (commit)   |   worker B (commit)
                                                              v
                                                           merger
                                                              |
                                                           verifier
                                                              |
                                                    reviewer(s) -> orchestrator report
```

## Relationship to the built-in `build` and `plan` agents

`plan` and `build` remain the right tools for most work, and this pack does not replace them:

- `plan` is a read-only planning mode for a single session. The orchestrator is similar in capability but its output is a delegation plan for subagents, not an implementation plan for the user.
- `build` is the normal single-agent mode with full tools. For a one-file change, `build` is faster than orchestrating a worker and a verifier, and the doctrine says so.
- The pack sits one level up: it is what you switch to when a task spans modules, needs parallel isolation, or needs a review trail that a single session cannot provide.

`explore` is reused as-is. There is no reason to reimplement a read-only search agent.

## What this design does not solve

- It does not verify that the chosen subagent was the right one.
- It does not make `shell` safe; subagents inherit host permissions.
- It does not benchmark itself against a single agent.
- It does not manage long-running background jobs; worktree cleanup is manual after a crash.
