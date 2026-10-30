# OpenCode Agent Doctrine

A small, auditable multi-agent setup for [OpenCode](https://opencode.ai) V2.

It is **not a plugin** and **not a framework**. It is a set of agent definitions, one doctrine file, and a config snippet you can read end-to-end in ten minutes.

## The problem

Most "multi-agent" setups fail in three ways:

1. The orchestrator can edit and run commands, so it does the work itself and never delegates.
2. Parallel agents write to the same working tree and overwrite each other.
3. "Review" is the same model re-reading its own diff and approving it.

This pack makes delegation structural, parallelism conditional, and review independent.

## What you get

| Piece | What it does |
|---|---|
| `orchestrator` | Reads, plans, delegates, adjudicates. Cannot edit files or run shell. |
| `worker` | Scoped implementation. Commits in its worktree. |
| `verifier` | Runs tests/build/lint; returns PASS/FAIL + diff stats + critical paths. |
| `reviewer-correctness` | Independent correctness review. |
| `reviewer-adversarial` | Independent adversarial review. |
| `scout` | Read-only git state probe. |
| `merger` | Merges worktree branches, resolves trivial conflicts, runs tests. |
| `researcher` | External docs/research with citations. |
| `AGENTS.md` | The doctrine: triage, delegation contract, parallelism, evidence. |

## The three rules

1. **Capability boundary**: the orchestrator has no `edit` and no `shell`. It cannot do the work, so it delegates.
2. **Risk-proportional review**: small change -> one correctness review; larger or critical -> two independent lenses in parallel.
3. **Git-gated parallelism**: parallel writes only when the repo is a git repo, has commits, has no tracked changes, and the scopes are disjoint. Otherwise serial.

## Architecture

```text
orchestrator (read / plan / delegate)
|- explore (built-in, read-only)
|- scout (git state)
|- worker (write, one owner)
|- verifier (tests + diff signal)
|- reviewer-correctness (read-only)
|- reviewer-adversarial (read-only)
|- merger (worktree merge)
`- researcher (external docs)
```

## Install

### Requirements

- OpenCode 2.2.3 (tested). Newer 2.2.x is expected to work but is untested. V1 is not supported.
- Git, for the parallel mode. Without git the pack runs serially.
- A model with reliable tool use. Tested with DeepSeek V4.1 Flash 1017; other models should work but are untested.

### Manual install

1. Copy `agents/*.md` to `~/.config/opencode/agents/`.
2. Merge `AGENTS.md` into your global `~/.config/opencode/AGENTS.md`. If you already have one, merge only the sections you want; do not overwrite your own rules.
3. Add the config snippet from `config/opencode.example.jsonc` to your `~/.config/opencode/opencode.jsonc`.
4. Reload OpenCode (`/reload` or restart the app).
5. Run `opencode debug agents` and confirm the eight agents appear.

### Script

```powershell
# Windows
powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

```bash
# macOS / Linux
bash ./install.sh --dry-run
bash ./install.sh
```

The installer backs up existing agent files, never overwrites `AGENTS.md`, and never edits `opencode.jsonc`. It prints the config snippet for you to merge.

## Configuration

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "default_agent": "orchestrator",
  "model": "provider/model",
  "experimental": {
    "subagent_depth": 2,
    "todo": true,
    "background_compaction": true
  },
  "compaction": { "keep": { "tokens": 30000 } },
  "worktree": { "directory": "../.opencode-worktrees" }
}
```

`provider/model` is a placeholder. Replace it with a model you actually have.

- `default_agent`: new sessions start as the orchestrator.
- `model`: use the strongest model you have; the pack is model-agnostic.
- `subagent_depth: 2`: lets a worker ask `explore` for help, but not spawn another writer.
- `todo: true`: gives the orchestrator a work graph.
- `worktree.directory`: keeps worktrees outside the repo.

## How it decides

```text
0. What kind of task?
   |- Q&A / explanation        -> answer directly, no agents
   |- read / locate            -> read/glob/grep or one explore
   |- single edit              -> one worker; verifier if there is a check
   `- multi-file / multi-module
        |- no parallel benefit -> serial workers
        `- parallel benefit    -> scout
             |- no git / no commit / tracked changes -> serial
             `- git clean + disjoint scopes -> worktrees -> merge -> verify -> review
```

## Review protocol

| Change | Review |
|---|---|
| <=2 files, <=80 lines, no critical path | one `reviewer-correctness` |
| >2 files or >80 lines | `reviewer-correctness` + `reviewer-adversarial` in parallel |
| auth / payments / migrations / public API / concurrency | A/B + full tests, regardless of size |

Independence rules:

- The two reviewers run in parallel with separate prompts and contexts.
- Do not pass one reviewer's findings to the other.
- The orchestrator deduplicates, ranks, and adjudicates conflicts with evidence.
- A BLOCKER goes back to the worker.

## Parallel protocol

Prerequisites:

1. Git repository with at least one commit.
2. No tracked uncommitted changes. Untracked files are listed; if they are in scope, handle them first or go serial.
3. Disjoint file scopes per worker.
4. At most 3 writers.

Flow:

1. `scout` reports `GIT`, `COMMITS`, `DIRTY_TRACKED`, `UNTRACKED_COUNT`.
2. `worktree_create` per module.
3. Each worker moves its session to its worktree, edits, commits, and reports the branch and SHA.
4. The orchestrator moves each worker session back.
5. `merger` merges in dependency order, runs tests, deletes merged branches, removes worktrees.
6. `verifier` runs the full check on the merged result.
7. Reviewers run on the merged diff.

## Verification

Tested on OpenCode 2.2.3, Windows 11, DeepSeek V4.1 Flash 1017. Four scenarios:

| Scenario | Result |
|---|---|
| Q&A | answered directly; no todo, no agents |
| single edit | one worker; read-back verification |
| 2-file parallel | scout -> 2 worktrees -> 2 workers -> merge -> verifier PASS -> reviewer APPROVE |
| 4-file change | one worker -> verifier PASS -> two reviewers in parallel, both APPROVE |

See [`docs/verification.md`](docs/verification.md) for commands and evidence.

**No benchmark.** This pack does not claim to be faster or cheaper than a single agent or than other orchestration projects. It claims to make delegation, isolation, and review explicit and auditable.

## Compatibility

| Surface | Status |
|---|---|
| OpenCode 2.2.3 (Windows 11) | tested |
| OpenCode 2.2.x (macOS/Linux) | expected, untested |
| OpenCode V1 | not supported |
| DeepSeek V4.1 Flash 1017 | tested |
| Other models | untested; behavior depends on tool use |

See [`docs/compatibility.md`](docs/compatibility.md).

## Limitations

- **Model-dependent.** A model that ignores the doctrine can still under-delegate. The permission boundary prevents it from editing, but it can still choose the wrong subagent.
- **No benchmark.** We have four behavior tests, not a SWE-bench run.
- **Windows worktree directories.** `worktree_remove` clears git metadata and branches, but empty directory shells can remain while a session holds a handle. They are harmless; delete them after a restart.
- **Dirty tracked changes fall back to serial.** The pack does not commit or stash your work.
- **Serial edits are not auto-committed.** Only worktree workers are required to commit.
- **Not affiliated with OpenCode.** This is a community configuration pack.
- **Chinese agent prompts.** The agent files are written in Chinese, which is the tested form. The doctrine and docs are in English. The structure is language-independent; an English translation is welcome and would ship under `agents/en/` after testing.

## Prior art

- [Solo](https://github.com/Dqz00116/opencode-solo) - closed-loop orchestrator + fast editors.
- [OAK](https://github.com/jcarlosrodicio/opencode-agent-orchestration-kit) - role-based workflow harness with adversarial review.
- [Swarm](https://github.com/ZaxbyHub/opencode-swarm) - architect-led team with gated review and disjoint worktree lanes.
- [Zenox](https://github.com/CyberBoyAyush/zenox) - specialist agents with a verification loop.

This pack differs in scope: it is deliberately small, has no runtime code, and focuses on the three failure modes above. If you want a full harness with a marketplace and a benchmark, use one of the projects above.

## License

MIT.
