# postline-remote-agent

A Codex skill for setting up, operating, and troubleshooting a
**phone-to-home-PC bridge**: chat in Feishu / Lark, Telegram, or Slack and have
a coding agent (Codex or Claude Code) running on *your own machine* do the work.

No public IP, no port-forwarding, no cloud sandbox — the agent runs where your
code and tools already live.

```
phone IM  ──(long-lived WebSocket)──>  bridge on 127.0.0.1:9999
                                            │
                                            └─> cc-worker ──> codex exec --json
```

## Why this exists

[postline](https://github.com/Christianye/postline) is a capable but very young
project. Getting it running on Windows surfaced six non-obvious failures that
cost real debugging time. This skill captures them so the next attempt is
minutes instead of hours.

| # | Failure | Fix |
|---|---|---|
| 1 | `process.env.HOME` is undefined on Windows, so the memory/routing path silently becomes `undefined/.postline/memory` and routing never loads | Use `${process.env.USERPROFILE ?? process.env.HOME}` |
| 2 | PowerShell 5.1 decodes BOM-less UTF-8 `.ps1` as ANSI; a Chinese path inside breaks parsing | Save scripts as UTF-8 **with BOM**, or keep them ASCII |
| 3 | Nested `powershell -Command` expands `$env:X` in the parent, so the child receives `=` | Escape as `` `$env:X `` |
| 4 | A message resolves a working directory only via an override prefix or a project name; there is no default | Always include a project name |
| 5 | Project-name matching is `text.includes(name)`, so `work` also fires on `network` / `framework` | Pick a short, distinctive name |
| 6 | A Scheduled Task gets a minimal environment; `Get-Command node` can fail there | Resolve node with an absolute-path fallback |
| 7 | The Codex desktop app injects its `bin\<hash>` dir only into its own children, not the registry PATH, so a Scheduled-Task worker dies with `spawn codex ENOENT` | Scan `%LOCALAPPDATA%\OpenAI\Codex\bin\*\codex.exe` and prepend it to PATH |
| 8 | postline hard-codes `-s workspace-write`, so the agent cannot write to the Desktop or Downloads | Patch the runner to pass `-c sandbox_workspace_write.writable_roots=[...]` from `CC_WORKER_WRITABLE_ROOTS` |

## Contents

```
postline-remote-agent/
├── SKILL.md                         Workflow, constraints, security boundaries
├── agents/openai.yaml               UI metadata
├── references/
│   ├── feishu-app-setup.md          Feishu custom-app walkthrough (step by step)
│   ├── verify-codex-events.md       Confirm `codex exec --json` shape before wiring
│   └── verify-routing.md            Test routing without sending an IM message
└── scripts/
    ├── start-all.ps1                Bridge + worker, background
    ├── stop-all.ps1                 Stop both
    ├── start-bridge-only.ps1
    ├── start-worker-only.ps1
    ├── install-autostart.ps1        Register a logon Scheduled Task
    └── apply-writable-roots-patch.ps1   Let the agent write outside its cwd
```

The scripts are **templates** — replace the `D:\path\to\...` placeholders and
save them as UTF-8 with BOM.

## Requirements

- Windows (primary target; the pitfalls are Windows-specific)
- Node.js >= 22 and pnpm
- Codex CLI (or Claude Code)
- A Feishu team/organisation if you use the Feishu channel — Telegram and Slack
  are also supported by postline and skip the app-creation step

## Install

Copy the folder into your skills directory:

```powershell
Copy-Item -Recurse . "$env:USERPROFILE\.codex\skills\postline-remote-agent"
```

Then ask Codex to use it, e.g.
*"Use the postline-remote-agent skill to set up remote control from my phone."*

## Security notes

- The bridge exposes control of your machine to the configured IM account. Keep
  `allowlist.openIds` to yourself and leave `requesterOnly: true`.
- Secrets belong in a local, git-ignored file — never in the config, never in
  chat, never committed.
- Point the worker at a dedicated scratch directory, not your real project tree.
- Destructive verbs are refused while no worker is live.

## License

MIT — see [LICENSE](LICENSE).
