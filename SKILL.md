---
name: postline-remote-agent
description: Set up, operate, or troubleshoot a phone-to-home-PC bridge that lets the user drive a local coding agent (Codex / Claude Code) from an IM app (Feishu/Lark, Telegram, Slack) while away from the computer. Use when the user wants to control their home machine's agent from a phone, mentions postline, Feishu bot + Codex, or asks why their remote agent bridge stopped working. Windows-focused.
---

# postline-remote-agent

Bridges a phone IM chat to a coding agent running on the user's own machine, via the
third-party OSS project [postline](https://github.com/Christianye/postline)
(MIT, ~2 stars - immature; expect to debug).

**Architecture.** IM app -> (long-lived WebSocket; no public IP or port-forward)
-> `postline feishu|telegram|slack` bridge on `127.0.0.1:9999` -> `cc-worker`
in a chosen repo dir -> spawns `codex exec --json` (or `claude -p`) per task.
Progress is edited in place into the same IM message.

## Hard-won constraints (these cost real debugging time)

1. **Windows + `process.env.HOME`**: postline's stock config uses
   `${process.env.HOME}`. Windows has no `HOME`, so the memory/routing path
   silently becomes `undefined/.postline/memory` and routing never loads.
   Replace every occurrence in `postline.config.ts` with
   `${process.env.USERPROFILE ?? process.env.HOME}`.
2. **PowerShell 5.1 + UTF-8 no BOM**: Windows PowerShell 5.1 decodes BOM-less
   UTF-8 `.ps1` as the ANSI codepage. A Chinese path inside the script is
   corrupted and parsing fails with `Array index expression is missing`.
   Write helper scripts as UTF-8 **with BOM**, or keep them pure ASCII.
3. **Nested `powershell -Command` swallows `$env:`**: building a child command
   string in a double-quoted here-string expands `$env:X` in the parent before
   it reaches the child, so the child receives `=`. Escape it as `` `$env:X ``.
4. **Routing needs a project name.** A message resolves a working directory
   only if it starts with `!<wake>@<project>` or mentions a name listed under
   `## projects`. Anything else is rejected with "No specific repo resolved".
   There is no default-cwd option.
5. **Short project names false-match.** Matching is `text.includes(name)`, so a
   project named `work` also fires on `network`, `framework`, `homework`.
   Prefer a short distinctive name.
6. **Auto-start needs an absolute node path.** A Scheduled Task gets a minimal
   environment; `Get-Command node` can fail there. Fall back to the known path.
## Before building anything

Confirm the user wants *their own machine* driven remotely (not a cloud agent),
then verify prerequisites rather than assuming them:

```powershell
node --version            # need >= 22
pnpm --version
codex --version
codex exec --json --skip-git-repo-check -s read-only -c model_reasoning_effort=low "reply: ok"
```

That last command is the **critical compatibility gate**. postline's Codex
adapter parses `thread.started`; `item.completed` with
`item.type == "agent_message"` + `item.text`; and `item.type ==
"command_execution"` + `item.command` (a **string**). If those shapes are
absent the bridge hangs or returns nothing. Non-JSON stderr lines are ignored
safely. See `references/verify-codex-events.md`.

## Setup outline

1. Fetch postline. If `git clone` is blocked, download
   `https://codeload.github.com/Christianye/postline/zip/refs/heads/main` and
   extract instead.
2. `pnpm install && pnpm -r build`, then
   `node packages/cli/dist/bin.js init --channel feishu`.
3. Apply constraint #1, enable the `feishu` and `doorbell` blocks in
   `postline.config.ts`, and keep the App Secret in a local `.secrets.ps1` -
   never inline in the config and never pasted into chat.
4. Walk the user through creating the Feishu app themselves; see
   `references/feishu-app-setup.md`. The agent must not log into the user's
   Feishu account.
5. Start the bridge, then a worker, then have the user send one message so the
   bridge logs their `open_id`. Add that id to `allowlist.openIds` and restart
   the bridge. Until then every dispatch is blocked by design.
6. Verify end to end; optionally register auto-start with
   `scripts/install-autostart.ps1`.

`scripts/start-all.ps1` and `scripts/stop-all.ps1` are templates: substitute the
install root and worker directory, and keep `logs/`.

## Routing config

Lives at `<memory.dir>/routing.md` (default
`%USERPROFILE%\.postline\memory\routing.md`); the bridge hot-reloads on save.

```markdown
## wake
pl

## projects
- pc
- 电脑

## worker_aliases
pc → D:/Documents/ChatGPT/远程工作区
电脑 → D:/Documents/ChatGPT/远程工作区
```

Worker cwd is canonicalized: git toplevel if available, else `process.cwd()`,
realpath'd, then **backslashes converted to forward slashes**. The alias value
must match that canonical form exactly - confirm it from the worker's
`cc_worker_registered` log line instead of guessing.

Verify a routing change without touching IM by running the parser and matcher
directly; see `references/verify-routing.md`. Adding several alias names that
point at the same cwd is supported and is how you make the trigger feel natural.

## Security boundaries to preserve

- `allowlist.openIds` should contain only the requesting user; keep
  `requesterOnly: true`.
- Secrets live in a local file. Never echo them, never paste them into the
  conversation, never commit them.
- Default the worker to a dedicated scratch directory rather than the user's
  real project tree unless the user explicitly asks otherwise.
- Destructive verbs are refused when no worker is live; leave that list intact.

## Operating notes

- Bridge and worker are independent processes and both must run. The worker
  re-registers automatically after a bridge restart.
- Everything stops if the machine sleeps. Advise disabling sleep for
  long-running use.
- Logs: `<install>\logs\bridge.out.log`, `worker.out.log` (structured JSON),
  plus `start-all.diag.log` when auto-start is in play.
- The bridge exits with `invalid config: feishu.appSecret is required` when the
  secret env var is missing - that almost always means the launcher forgot to
  dot-source `.secrets.ps1`, not that the secret is wrong.
