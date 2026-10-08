# Feishu / Lark app setup (user does this; agent guides)

The agent must not log into the user's Feishu account. Open
`https://open.feishu.cn/app` for the user and walk them through it, asking them
to send screenshots when the UI differs from these steps.

The user needs a Feishu **team/organisation**. A personal account must create a
free team first, otherwise app creation is unavailable.

## Steps

1. **Create the app.** Developer console -> create a self-built app. An existing
   unused app is fine; reuse it rather than creating a duplicate.
2. **Add the Bot capability.** Left nav "应用能力" -> "添加应用能力" -> on the
   "机器人" card click "添加". Without this, message events are not offered.
3. **Permissions.** Left nav "权限管理" -> "开通权限". Add exactly two:
   - `im:message` - receive/read user messages
   - `im:message:send_as_bot` - reply as the bot
   The `docx:` / `drive:` / `sheets:` / `bitable:` / `wiki:` scopes are only
   needed for the optional `lark_docs` tool. Do not add them by default.
4. **Event subscription.** Left nav "事件与回调" -> "事件配置".
   - Subscription mode: **使用长连接接收事件** (long-connection WebSocket).
     This is what removes the need for a public IP or port-forward. If the
     console offers only "send to developer server", stop and report it.
   - Add event `im.message.receive_v1` (接收消息). Searches for "卡片" or
     "接收消息" sometimes return nothing; searching `im.message` or the exact
     event code works better.
   - Optional: `card.action.trigger` for in-chat approve/deny buttons. Its
     absence is not a blocker - the user can type `/approve <id>` instead.
5. **Credentials.** Left nav "凭证与基础信息": copy the App ID (`cli_...`) and
   the App Secret. The App ID is not sensitive; the Secret is.
6. **Publish, then set availability.** Left nav "版本管理与发布" -> create a
   version -> publish. The console banner "应用发布后，当前配置方可生效" means
   permissions and events are inert until this happens. If the app is not
   discoverable by the user afterwards, set "可用范围" to include them and
   publish again.

## Getting the user's open_id

Do not guess it. Start the bridge with an empty allowlist, have the user send
any message to the bot, then read the bridge log:

```
"msg":"feishu_inbound" ... "from":"ou_...."
```

That `from` value is the user's open_id. Add it to `allowlist.openIds` and
restart the bridge. The bot's own id (`feishu_bot_identified`, also `ou_...`)
is different and must not be used.
