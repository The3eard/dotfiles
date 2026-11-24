---
name: kitty-panes
description: Shows things beside the conversation in the user's kitty terminal instead of dumping them in chat, through kitty's remote control (`kitten @`). Use to show a diff before a push gate (delta at full width, or lazygit), open a tab in a worktree or directory the user has to look at, follow logs live in a split, or read the output of another pane the user points at ("mira el split de la derecha", "lee el error del otro pane"). Triggers: "kitty", "ábreme un split", "ábreme un tab", "enséñame el diff", "enséñame los cambios", "mira el otro pane".
---

# kitty-panes

The user works in kitty. `$KITTY_WINDOW_ID` is the pane Claude Code runs in; `kitten @` talks to the kitty instance in `$KITTY_LISTEN_ON` by itself. In kitty a pane is a *window* and a tab is a *tab*. `kitten @ --help` and `kitten @ <command> --help` cover anything beyond these recipes.

## Availability

kitty is usable only when `$KITTY_LISTEN_ON` is set and `kitten @ ls >/dev/null` succeeds; that needs `allow_remote_control socket-only` and `listen_on` in `kitty.conf`. Otherwise work in chat as usual; mention it only if the user asked for kitty.

## Rules

- Every `launch` carries `--match "window_id:$KITTY_WINDOW_ID"`: after a background tab is opened, remote control targets that tab, and a split would land there instead of beside this pane.
- Every `launch` that runs a command carries `--env "PATH=$PATH"`: programs kitty starts don't get the shell's PATH, so Homebrew tools (delta, lazygit, lnav) are not found.
- Never take focus: `--keep-focus` on every `launch`. The user decides when to look.
- Name every tab and pane opened after its role (`diff`, `lazygit`, `logs`, `dir`...): `--tab-title` for a tab, `--title` for a pane. Keep the window ID each `launch` prints. Close only what this session opened, and reuse a role (close the old one first) instead of stacking a second one.
- What runs in an opened pane bypasses Claude Code's permission checks, so launch only viewers (`git diff`, `lnav`, `tail -F`, a plain shell) or tools the user drives (`lazygit`, `hx`). Never a command that changes anything on its own.
- Git output shown in a pane (`git diff`, `git show`, `git log -p`) is always rendered with delta, the way the diff recipe does it; never git's default pager or difftastic.
- Never `send-text`, `send-key`, `close-window` or `close-tab` on a pane or tab this session did not open, unless the user asks for that exact thing. Never `send-text` to `$KITTY_WINDOW_ID`.
- `get-text` reads the user's screens, which may hold secrets: only on a pane the user pointed at, and quote back only what the task needs.

## Recipes

**Diff in a tab** (before a push gate, or when the user asks to see a range). Always rendered with delta, side by side, which needs the full width: a tab, never a split. Git's `diff.external` is difftastic, so `--no-ext-diff` hands delta git's own unified diff. delta runs as git's pager with `--paging=never`, which prints into the pane, whose scrollback scrolls it; `--hold` leaves a shell there after git exits. A background tab already has the window's full size, so delta measures it by itself.

```bash
kitten @ launch --match "window_id:$KITTY_WINDOW_ID" --type=tab --keep-focus --tab-title "diff <base>...<sha>" \
  --cwd "<repo>" --env "PATH=$PATH" --hold -- \
  git -c core.pager="delta --side-by-side --paging=never" diff --no-ext-diff <base>...<sha>
```

**lazygit in a tab** for an interactive look (uncommitted changes file by file, staging, history). It renders diffs with difftastic; `|` cycles to git's raw diff, the only renderer where hunk and line staging work. lazygit can't open on a `<base>...<sha>` range, so a push gate uses the diff tab above.

```bash
kitten @ launch --match "window_id:$KITTY_WINDOW_ID" --type=tab --keep-focus --tab-title lazygit \
  --cwd "<repo>" --env "PATH=$PATH" -- lazygit
```

**Tab in a directory** (a worktree, a cherry-pick conflict, generated files). No command means the user's login shell, which sets its own PATH.

```bash
kitten @ launch --match "window_id:$KITTY_WINDOW_ID" --type=tab --keep-focus --tab-title "dir <TICKET> <what>" --cwd "<dir>"
```

**Live logs in a split** below this pane, taking 30% of it. Local file with `lnav <file>`, remote with `ssh <host> tail -F <path>`.

```bash
kitten @ launch --match "window_id:$KITTY_WINDOW_ID" --type=window --location=hsplit --bias 30 \
  --next-to "id:$KITTY_WINDOW_ID" --keep-focus --title logs --cwd "<dir>" --env "PATH=$PATH" -- lnav "<file>"
```

**Read another pane.** `kitten @ ls` is a JSON tree of OS windows → tabs → windows; each window has `id`, `title`, `cwd`, `foreground_processes`, `is_focused` and `is_self`. Pick the pane the user means by title, program or cwd, or by position with `--match neighbor:left|right|top|bottom` (relative to the active pane, which is this one while the user types here), and ask when it is ambiguous. `--extent last_cmd_output` gives just the last command's output.

```bash
kitten @ get-text --match id:<window_id> --extent screen | tail -n 100
```

**Clean up** when the user is done, or before reopening a role. Closing a tab's only pane closes the tab. Lost IDs come back from the titles in `kitten @ ls`.

```bash
kitten @ close-window --match id:<window_id>   # a pane or tab this session opened
```
