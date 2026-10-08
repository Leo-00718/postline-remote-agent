# Verifying routing without sending an IM message

The router is a pure function; test it directly instead of round-tripping
through the phone. Write this to a .js file and run it with node (relative
requires break if the script lives outside the postline root).

```javascript
const R = 'D:/path/to/postline/packages/core/dist/router/';
const { parseRoutingMarkdown } = require(R + 'parser.js');
const { matchRoute } = require(R + 'matcher.js');
const fs = require('fs');
const cfg = parseRoutingMarkdown(
  fs.readFileSync(process.env.USERPROFILE + '/.postline/memory/routing.md', 'utf8'),
);
const mk = (t) => ({ text: t, hasActiveWorkerForCwd: () => true, embeddedLlmEnabled: false });
for (const c of ['pc 列出文件', '电脑 帮我改文件', '帮我列出文件', 'network 配置有问题']) {
  const r = matchRoute(cfg, mk(c));
  console.log(JSON.stringify({ input: c, kind: r.decision.kind, reason: r.decision.reason, cwd: r.decision.cwd ?? null }));
}
```

Interpretation:

- `kind: "dispatch_to_mac"` **with a non-null cwd** — will dispatch. Good.
- `kind: "dispatch_to_mac"` **with cwd null** — matched a dispatch token but
  no project name; the bridge replies "No specific repo resolved" instead.
- `kind: "reject_no_worker"` — nothing matched; also rejected.

Always include a deliberate near-miss (an English word containing the project
name) to catch substring false-positives when choosing a project name.

Note: `loader.js` exports `startRoutingLoader`, not a parse helper. The
parser is `parseRoutingMarkdown` in `parser.js`.
