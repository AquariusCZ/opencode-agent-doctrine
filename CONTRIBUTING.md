# Contributing

Small, readable changes are preferred over large ones. This pack is meant to be auditable in one sitting; a contribution that triples the file count needs a strong reason.

## Adding an agent

1. Create `agents/<name>.md` with frontmatter:

   ```yaml
   ---
   description: one line, used by the orchestrator to choose the agent
   mode: subagent
   permissions:
     - action: edit
       resource: "*"
       effect: deny
     - action: subagent
       resource: "*"
       effect: deny
   ---
   ```

2. Start from the least privilege that works. Read-only unless the agent must write; no `shell` unless it must run commands; no `subagent: allow` unless it must delegate.
3. Write the body as: role, inputs it expects, procedure (numbered), output contract (what the orchestrator gets back), and what it must not do.
4. Add the agent to the roster table in `README.md` and the permission table in `docs/architecture.md`.
5. If the agent changes the delegation flow, update the triage section of `AGENTS.md`.

An agent that duplicates an existing role is usually a sign that the existing role's prompt is too vague. Tighten the prompt first.

## Running the checks

```powershell
pwsh -File ./tests/check-agents.ps1 -OpenCode opencode
```

The script runs `opencode debug agents`, parses the JSON, and asserts that all eight agents exist and that the expected `edit`/`shell` denials are present. It prints `PASS` or `FAIL` with the missing items and exits non-zero on failure. It does not modify files.

On a machine where OpenCode is not on `PATH`, pass the full path:

```powershell
pwsh -File ./tests/check-agents.ps1 -OpenCode "C:\path\to\opencode.exe"
```

Manual behaviour checks are in [`tests/manual-smoke.md`](tests/manual-smoke.md). Run at least Scenario 1 and Scenario 2 for a prompt-only change; run Scenario 3 for anything touching worktrees, `merger`, or the parallel protocol.

## Documentation style

- English, plain, present tense.
- One idea per paragraph; short sections with headings.
- Use `->` for flow, not arrows from a specific font.
- No personal absolute paths. Use `<repo>`, `<file>`, `<worktree>`, `<branch>`.
- No secrets, tokens, usernames, machine names, or internal URLs.
- No claims you cannot back with a scenario. "Faster" needs numbers; "works" needs a run.
- Prefer tables for matrices and short lists for procedures.
- Keep line lengths reasonable; do not hard-wrap prose at 80 columns.

## Pull requests

Include:

1. **Motivation.** The failure mode or gap this addresses. One paragraph is enough.
2. **Change summary.** Files touched and why.
3. **Test evidence.** Command run and result. For agent changes: which scenario, which model, which OpenCode version, and the verdicts (`verifier PASS`, reviewer `APPROVE`).
4. **Compatibility.** Anything version-specific, and whether macOS/Linux was exercised.
5. **Security impact.** Any change to a `permissions` block must be called out explicitly, even when it tightens a rule.

Keep PRs focused. A prompt tweak and a new agent are two PRs.

## Do not commit

- `.bak-*` files, editor backups, or `opencode.jsonc.bak-*`.
- Worktree directories or anything under `.opencode-worktrees/`.
- Personal configuration: your `opencode.jsonc`, model ids you use locally, API keys, `.env` files.
- Generated transcripts or logs from a session.
- OS metadata (`.DS_Store`, `Thumbs.db`).

If a file is useful as an example, put a redacted, minimal version under `config/` and name it `*.example.*`.

## Reporting bugs

Open an issue with the OpenCode version, OS, model, the scenario that failed, and the point where behaviour diverged from the doctrine. A transcript excerpt is more useful than a description of the outcome.
