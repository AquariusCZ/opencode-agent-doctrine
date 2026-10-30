# Compatibility

## Matrix

| Surface | Version | Status |
|---|---|---|
| OpenCode | 2.2.3, Windows 11 | tested |
| OpenCode | 2.2.x, macOS / Linux | expected to work, untested |
| OpenCode | V1 (1.x) | **not supported** |
| DeepSeek V4.1 Flash 1017 | as shipped by provider | tested |
| Other models | any | untested; behavior depends on tool use |
| PowerShell | 7.x (`pwsh`) | tested |
| Windows PowerShell | 5.1 | expected; `tests/check-agents.ps1` avoids PS7-only syntax |
| bash | 5.x | expected; install script is unchanged from the tested layout |

"Tested" means the four scenarios in [`verification.md`](verification.md) were run end to end on that surface. It does not mean every OpenCode feature or every provider was exercised.

## Why V1 is not supported

The pack depends on V2 behaviour:

- `permissions` on agents, including `edit`/`shell` denial with `resource: "*"`.
- `worktree_create` / `worktree_remove` and session move semantics.
- The `experimental` config block (`subagent_depth`, `todo`).
- Subagent session isolation and `session_move`.

V1 has different agent frontmatter and no worktree tools. Some agents may load, but the capabilities the doctrine relies on are missing, so the behaviour would be undefined.

## `worktree_create` on 2.2.3

Observed behaviour, and the reason the protocol says "each worker creates a branch":

- A freshly created worktree is on a **detached HEAD**, not on a named branch.
- `git status` in the worktree reports a clean tree at the base commit.
- The worker must create its own branch before committing, e.g. `git switch -c work/<module>`.
- Without that step, commits land on a detached HEAD, are not referenced by any branch, and `merger` has nothing to merge.

The worker agent instructions state this explicitly. If a future OpenCode version creates worktrees on a branch automatically, the extra `git switch -c` is harmless only if the branch does not already exist; check before upgrading.

Other observations on 2.2.3:

- `worktree_create` accepts a name and returns a directory; it does not create a branch.
- `session_move` is required for the worker to actually operate inside the worktree. Editing by absolute path from the main session works but defeats the isolation guarantee.
- `worktree_remove` deletes git metadata and the registered worktree entry.

## Windows-specific issues

- **Empty directory shells.** After `worktree_remove`, the directory can remain on disk as an empty shell while a session still holds a handle. Git no longer knows about it, so it is harmless. Delete it after the session that held it ends, or after an app restart.
- **Long paths.** Worktrees under `../.opencode-worktrees` keep paths short. Deep nesting can still hit the Windows path limit; enable long paths if you nest repos deeply.
- **Locked files.** Antivirus or an editor indexer can hold handles in a worktree and make removal fail. Retry after the scan, or delete manually.

## Input shape drift

`opencode debug agents` output is parsed by `tests/check-agents.ps1`. The parser accepts:

- a top-level array of agents, or an object with an `agents` key (array or map keyed by id);
- agent identity under `id` or `name`;
- `permissions` as either a list of `{ action, resource, effect }` rules or a map of `action -> resource -> effect`.

If a future version changes that shape, the script fails loudly with the parse error rather than reporting a false PASS.

## Not official

This is a community configuration pack. It is not affiliated with, endorsed by, or supported by the OpenCode project. Bug reports about OpenCode itself belong upstream; issues about the agents, doctrine, or scripts belong here.

## Reporting a compatibility problem

Open an issue with:

- OpenCode version (`opencode --version`) and OS.
- Model and provider id.
- The scenario from `verification.md` that failed.
- The agent transcript section where behaviour diverged from the doctrine.
