# Security

## Permission model

| Agent | edit | shell | subagents | Notes |
|---|---|---|---|---|
| `orchestrator` | deny (`*`) | deny (`*`) | allow | Read-only primary agent |
| `worker` | allow | allow | deny | Writes and commits inside its worktree |
| `merger` | allow | allow | deny | Merges branches, runs tests, cleans worktrees |
| `verifier` | **deny** | allow | deny | Runs checks; must not fix code |
| `reviewer-correctness` | **deny** | allowed, instruction-restricted (read-only) | deny | Reads the diff; does not run tests |
| `reviewer-adversarial` | **deny** | allowed, instruction-restricted (read-only) | deny | Reads the diff; does not run tests |
| `scout` | **deny** | allowed, instruction-restricted | deny | `git status` / `git log` / `git diff --stat` only |
| `researcher` | **deny** | **deny** | deny | External docs and citations |

Only the `edit` and `shell` denials in the table are enforced by permissions. `scout` and both reviewers have `shell` allowed but instruction-restricted: scout is told to run only git state commands, reviewers are told to read the diff and not run tests or write files. Their shell tool is not limited by a rule. If you need that enforced, add a `shell` deny with a narrower allow rule, or remove `shell` entirely.

The intent:

- **One writer per file.** The orchestrator cannot write, so every change has a named author.
- **Reviewers cannot patch.** A reviewer that can edit can hide a finding by fixing it silently. Denying `edit` keeps findings explicit.
- **Verification is separate from implementation.** `verifier` can run commands but not change code, so a FAIL cannot be papered over.

## This is not a sandbox

The permission rules are capability checks inside OpenCode. They decide which tools an agent may call. They do **not** constrain the operating system process.

Any agent with `shell` runs with your user account's privileges:

- it can read and write files outside the repository;
- it can reach the network;
- it inherits environment variables, SSH agent sockets, cloud credentials, and git credential helpers;
- a command it runs can do anything you could do in a terminal.

A worker told to "run the tests" executes whatever the repository's test command is, including a malicious `postinstall` or a modified test script. Worktrees isolate file layout, not privileges.

If you need real isolation, run OpenCode in a container, a VM, or a dedicated OS user with limited access. Do not treat these permission blocks as a security boundary against untrusted code.

## Before you install

Read the agent files before copying them into `~/.config/opencode/agents/`. Check, for each file:

1. The `permissions` block matches the table above. A missing `edit: deny` on a reviewer or the orchestrator changes the threat model.
2. The `mode` is what you expect: `orchestrator` is `primary`; the rest are `subagent`.
3. No agent has `subagent: allow` unless it needs to delegate. In this pack only the orchestrator does.
4. Any `shell` scope is as narrow as the task allows. `scout` should not have a general shell.

Also review the config snippet you merge into `opencode.jsonc`. Do not blindly replace an existing config: merge keys, keep your own `permissions` and provider settings, and check `default_agent` before making the orchestrator the default.

The installer backs up existing files and never edits `opencode.jsonc`, but it does copy agent definitions into a directory OpenCode executes as instructions. Treat it as code.

## Do not put secrets in the repository

Agents read files and quote them into their context, which is then sent to the model provider. Anything an agent reads can leave your machine.

- No API keys, tokens, private keys, or `.env` contents in agent files, `AGENTS.md`, examples, or test fixtures.
- Keep secrets in environment variables or your OS keychain, not in `opencode.jsonc` committed to a repo.
- If a task requires reading a secret to debug, prefer a redacted sample.
- Worktree directories inherit the repo; a secret committed once will be copied into every worktree.

If a secret is exposed in a transcript, rotate it. Deleting the message is not enough; it has already been sent to the provider.

## Prompt injection

Subagents read repository content, and repository content can contain instructions. A reviewer reading a malicious file could be told to approve. Mitigations in this pack:

- reviewers have no `edit`, so injected instructions cannot change code;
- reviewers have a read-only shell instruction, but that is a prompt constraint, not a permission boundary; an injected instruction could still run a command. Treat reviewer output as untrusted and adjudicate it against the code;
- the orchestrator adjudicates findings against the code rather than accepting them at face value;
- workers have a narrow scope and commit to a branch, so damage is visible in a diff.

These reduce impact; they do not eliminate the risk. Do not run this pack on repositories you would not let a contractor with your account access read.

## Reporting a vulnerability

Use **GitHub Security Advisories** on this repository (Security tab -> "Report a vulnerability"). That opens a private channel.

Please do not open a public issue for:

- a permission block that can be bypassed;
- an agent that writes outside its declared scope;
- a script that deletes or overwrites files unexpectedly;
- prompt-injection paths that cause an agent to act outside its role.

Include: version, OS, the agent file involved, and a minimal reproduction. You will get an acknowledgement on a best-effort basis; this is a community project maintained on a best-effort basis, not a vendor product.

## Supported versions

Only the current release is considered for security fixes. OpenCode itself is out of scope; report OpenCode issues upstream.
