---
name: rex-panes
description: Shows things beside the conversation in the user's Rex terminal instead of dumping them in chat. Use to show a diff before a push gate (difftastic at full width, or lazygit), open a tab in a worktree or directory the user has to look at, follow logs live in a split, or read the output of another pane the user points at ("mira el split de la derecha", "lee el error del otro pane"). Builds on the `rex` skill, which documents the CLI itself. Triggers: "rex", "ábreme un split", "ábreme un tab", "enséñame el diff", "enséñame los cambios", "mira el otro pane".
---

# rex-panes

The user works in Rex. `$REX_SESSION` is this session and `$REX_BLOCK` the pane Claude Code runs in; every recipe anchors on them. In the CLI a tab is a window and a pane is a block. For anything beyond these recipes, the `rex` skill (or `rex skill show`) has the CLI guide.

## Availability

Rex is usable only when `$REX_SESSION` is set and `rex whoami --json` succeeds. Otherwise work in chat as usual; mention it only if the user asked for Rex.

## Rules

- Never take focus: `--focus=false` on every `window new`, `run` and `split`. The user decides when to look.
- Name every tab and pane opened after its role (`diff`, `lazygit`, `logs`, `dir`...): the label of `window new`, `--label` on `split`. Keep the IDs each `--json` returns. Close only tabs and panes this session opened, and reuse a role (close the old one first) instead of stacking a second one.
- What runs in an opened pane bypasses Claude Code's permission checks, so launch only viewers (`git diff`, `lnav`, `tail -F`, a plain shell) or tools the user drives (`lazygit`, `hx`). Never a command that changes anything on its own.
- Never `send`, `send-key`, `block close` or `window close` on a pane or tab this session did not open, unless the user asks for that exact thing. Never `send` to `$REX_BLOCK`.
- `capture` reads the user's screens, which may hold secrets: only on a pane the user pointed at, and quote back only what the task needs.

## Recipes

**Diff in a tab** (before a push gate, or when the user asks to see a range). Git's `diff.external` is difftastic, which needs the full width for its side-by-side view: a tab, never a split, and never a pager. `--no-pager` prints it into the pane, whose scrollback scrolls it, and `--keep-open` keeps it after git exits. A tab opened with `--focus=false` is 80×24 until the user shows it, and difftastic measures the terminal once, so pass the width of a full tab in `DFT_WIDTH`; Rex reflows the lines when the tab gets its real size.

```bash
frac=$(rex session inspect "$REX_SESSION" --json | jq --arg b "$REX_BLOCK" '[.. | objects | select(.block_id? == $b and has("rect")) | .rect[2]][0]')
cols=$(rex block call -s "$REX_SESSION" -b "$REX_BLOCK" size | jq --argjson f "$frac" '.columns / $f | floor')
rex window new -s "$REX_SESSION" "diff <base>...<sha>" -c "<repo>" --keep-open --focus=false --json -- \
  env DFT_WIDTH="$cols" git --no-pager diff <base>...<sha>
```

**lazygit in a tab** for an interactive look (uncommitted changes file by file, staging, history). It redraws at the tab's real size and renders diffs with difftastic; `|` cycles to git's raw diff, the only renderer where hunk and line staging work. lazygit can't open on a `<base>...<sha>` range, so a push gate uses the diff tab above.

```bash
rex window new -s "$REX_SESSION" lazygit -c "<repo>" --focus=false --json -- lazygit
```

**Tab in a directory** (a worktree, a cherry-pick conflict, generated files). No command means the user's shell.

```bash
rex window new -s "$REX_SESSION" "dir <TICKET> <what>" -c "<dir>" --focus=false --json
```

**Live logs in a split** below this pane. Local file with `lnav <file>` (`butcher` keeps full logs on disk), remote with `ssh <host> tail -F <path>`.

```bash
rex split -s "$REX_SESSION" -b "$REX_BLOCK" --split=below --ratio 30 --label logs --focus=false -c "<dir>" --json -- lnav "<file>"
```

**Read another pane.** `rex block ls -s "$REX_SESSION" --json` lists every pane with its label and tab; `rex session inspect "$REX_SESSION" --json` gives each pane's `rect` (`[x, y, width, height]` as fractions of its tab) and each tab's `focused_block_id`. Pick the pane the user means by position, label, or `rex block call -s "$REX_SESSION" -b <block> process` (foreground program and cwd), and ask when it is ambiguous.

```bash
rex capture -s "$REX_SESSION" -b <block> --trim | tail -n 100
```

**Tab title for pipeline state** (`<TICKET> · review r2`), on the tab this session runs in:

```bash
rex window rename -s "$REX_SESSION" "$(rex block inspect "$REX_BLOCK" --json | jq -r .block.window_id)" "<title>"
```

**Clean up** when the user is done, or before reopening a role. Lost IDs come back from the labels in `rex window ls -s "$REX_SESSION" --json` and `rex block ls -s "$REX_SESSION" --json`.

```bash
rex window close -s "$REX_SESSION" <window_id>   # a tab this session opened
rex block close -s "$REX_SESSION" <block_id>     # a split this session opened
```
