# Verifying Codex event compatibility

postline's Codex adapter (`packages/cli/src/cc-worker/runner.ts`, `codexSpec`)
runs:

```
codex exec --json --skip-git-repo-check -s workspace-write -c model_reasoning_effort=low <prompt>
```

and expects each stdout line to be JSON of this minimal shape:

```typescript
interface CodexEvent {
  type: string; // thread.started | turn.started | item.started | item.completed | turn.completed
  item?: { type?: string; text?: string; command?: string };
}
```

Recognised cases:

| condition | effect |
|---|---|
| `type === "thread.started"` | progress: "worker started" |
| `item.type === "agent_message"` + string `item.text` | progress + final answer (last one wins) |
| `item.type === "command_execution"` + **string** `item.command` | tool progress line |

Anything else is ignored, and unparseable lines are skipped silently, so Codex's
own WARN/ERROR log lines are harmless.

## Gate command

Run this before wiring the bridge. It must print a `thread.started`, an
`item.completed` whose `item.type` is `agent_message`, and a
`turn.completed`:

```powershell
codex exec --json --skip-git-repo-check -s read-only -c model_reasoning_effort=low "Reply with exactly: hello"
```

To also exercise the tool path:

```powershell
codex exec --json --skip-git-repo-check -s workspace-write -c model_reasoning_effort=low "Run the shell command: echo abc123"
```

Expect an `item.type == "command_execution"` whose `command` field is a
**string** (not an array). If it is an array, tool-progress lines will not render
but the final answer still works — note it as a cosmetic degradation.

## Known benign warnings

On an API-key login, Codex prints warnings about remote plugin catalog sync
(401 Unauthorized) and an unknown model name. They are stderr noise, not a
blocker. A `Reading additional input from stdin...` line is also harmless.
