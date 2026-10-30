# Prior art

Several OpenCode projects solve adjacent problems. This page says what each one is, how this pack differs, and when you should pick them instead. The intent is orientation, not ranking: they are larger and more capable in areas this pack deliberately avoids.

| Project | Shape | Best known for |
|---|---|---|
| [Solo](https://github.com/Dqz00116/opencode-solo) | agent pack | Closed-loop orchestrator with fast editing agents |
| [OAK](https://github.com/jcarlosrodicio/opencode-agent-orchestration-kit) | workflow kit | Role-based workflow with adversarial review |
| [Swarm](https://github.com/ZaxbyHub/opencode-swarm) | plugin | Architect-led team, gated pipeline, disjoint worktree lanes |
| [Zenox](https://github.com/CyberBoyAyush/zenox) | plugin | Specialist agents, background tasks, verification loop |
| [Mission Control](https://github.com/nigel-dev/opencode-mission-control) | plugin | Parallel sessions in worktrees + tmux, plan system, merge train |

## Solo

**What it is.** An agent configuration built around a closed loop: plan, implement, check, repeat, with editing agents tuned for speed. It is a configuration rather than a runtime, closer in spirit to this pack than the plugins below.

**Our difference.** Solo optimises the loop inside one session. This pack optimises the boundary between sessions: a read-only orchestrator that cannot act, and named subagents that each own one scope. The review step here is a separate agent with a separate context, not a re-check by the same loop.

**When to use Solo.** You want a single strong session that iterates quickly and you do not need worktree isolation or an independent review trail.

## OAK

**What it is.** A role-based orchestration kit: defined roles, a workflow that moves work between them, and an adversarial review step before completion.

**Our difference.** OAK and this pack share the adversarial reviewer idea. OAK encodes the workflow in a harness with more moving parts; this pack encodes it in a doctrine file plus permission blocks, with no runtime code. If OAK's workflow matches how your team already works, its structure will fit better than eight generic agents.

**When to use OAK.** You want an opinionated, multi-role process with more stages than triage/delegate/verify/review, and you are comfortable maintaining the harness.

## Swarm

**What it is.** An architect-centric plugin with a large roster of specialised agents (architect, coder, reviewer, test engineer, critics, curators), a gated pipeline where code does not ship until review and tests pass, and parallel coder lanes in isolated worktrees for provably file-disjoint task groups.

**Our difference.** Swarm is a full harness with runtime code, state under `.swarm/`, resumable sessions, and many optional gates. This pack is the opposite trade: eight agent files, one doctrine, no plugin, no state directory. Swarm's parallel lanes and this pack's worktree protocol solve the same problem; Swarm does it with more machinery and more features (epic waves, PR feedback loops, skill curation).

**When to use Swarm.** You want gates enforced by code rather than by instructions, need resumable multi-phase projects, or want the breadth of specialised roles. If you are choosing between the two for a real team, Swarm is the more complete product.

## Zenox

**What it is.** A plugin that ships a team of specialist agents (explorer, librarian, oracle, ui-planner, inspector), background task execution, keyword-triggered research modes, and a verification loop.

**Our difference.** Zenox targets breadth of capability per agent and parallel background research. This pack targets the delegation boundary and review independence, and keeps every agent generic enough to be read in a few minutes. Zenox's background execution is a feature this pack does not have at all.

**When to use Zenox.** You want richer specialist agents, external research integrations, and background tasks out of the box.

## Mission Control

**What it is.** A plugin for parallel AI coding sessions, each in its own git worktree and tmux session, with monitoring, capture/attach, a plan system with dependency graphs, a merge train that tests after each merge, and PR creation.

**Our difference.** Mission Control is infrastructure: it manages long-running jobs, tmux panes, and integration branches. This pack assumes interactive sessions and a single orchestrator that merges with a subagent. If you need to run several agents unattended for hours and watch them from a dashboard, Mission Control is built for that; this pack is not.

**When to use Mission Control.** You want supervised parallel jobs, merge trains with rollback, and PR automation, and you are willing to run tmux.

## What this pack borrows

- Worktree-per-writer isolation, as in Swarm and Mission Control.
- An adversarial reviewer separate from the correctness reviewer, as in OAK and Swarm.
- The idea that review must be a different context, which all of the above enforce in some form.

## What this pack adds

Very little that is new. Its only distinct choices are:

1. **Capability denial as the delegation mechanism.** The orchestrator cannot edit or run shell, so delegation is not a prompt request.
2. **Git-gated parallelism with an explicit refusal path.** No git, no commits, or dirty tracked files means serial, stated up front.
3. **No runtime.** Everything is markdown plus a config snippet, so the whole system is auditable in one sitting.

If those three choices are not what you need, one of the projects above is likely a better fit.
