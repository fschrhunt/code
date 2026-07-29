# Agents and editors

Workframe keeps branch ownership explicit and editor choice configurable.

## Agent identities

List configured agents:

```bash
workframe agents list
```

Add an identity:

```bash
workframe agents add codex
```

Remove an unused identity:

```bash
workframe agents remove codex
```

Removal is refused while the identity still owns active worktrees. Agent names
may contain letters, numbers, dots, underscores, and hyphens; they may not
contain whitespace or path separators.

Use an agent for new work:

```bash
workframe new repo feature --agent codex
```

Automation may provide `WORKFRAME_AGENT=codex`. The identity must still appear
in the configured `agents` list.

## Why there is no silent default

The agent becomes the first segment of the branch name. Choosing it implicitly
would make ownership easy to misattribute, so non-interactive calls must pass
`--agent` or `WORKFRAME_AGENT`.

Interactive terminals can show a configured-agent picker.

## Editor

The default editor command is `cursor`. Change it interactively:

```bash
workframe config
```

Or edit:

```ini
editor = code
```

Open a workspace:

```bash
workframe ide <selector>
```

`workframe open` is an alias. Cursor and VS Code are opened with a new-window
flag so an existing agent session is not reused.

## Shell navigation

Without shell integration:

```bash
cd "$(workframe cd <selector>)"
```

Interactive `setup` and `config` can offer a shell wrapper. The wrapper handles
`workframe cd` in the current shell and delegates every other command to the
installed executable.
