#!/usr/bin/env bash
# SessionStart hook: gives a linked git worktree its own CodeGraph index.
# Without one, codegraph walks up to the main checkout's .codegraph/ and answers with
# that tree's code (another branch). Re-indexing from scratch costs minutes and ~1.3 GB,
# so the main index is cloned copy-on-write (APFS `cp -c`, instant, shares blocks) and
# `codegraph sync` re-indexes only the files that differ. Only seeds when the main
# checkout already has an index: indexing a repo stays an explicit decision.

set -uo pipefail

cwd=$(jq -r '.cwd // empty' 2>/dev/null)
cd "${cwd:-$PWD}" 2>/dev/null || exit 0

top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
common=$(cd "$(git rev-parse --git-common-dir)" && pwd -P) || exit 0
main=$(dirname "$common")
[[ "$(cd "$top" && pwd -P)" == "$main" ]] && exit 0   # main checkout, not a linked worktree

src="$main/.codegraph"
dst="$top/.codegraph"
[[ -f "$src/codegraph.db" ]] || exit 0
command -v codegraph >/dev/null || exit 0

fresh=0
if [[ ! -d "$dst" ]]; then
  fresh=1
  mkdir "$dst" || exit 0
  # The WAL goes along with the db so committed-but-uncheckpointed pages are not lost.
  files=("$src/codegraph.db" "$src/config.json" "$src/.gitignore")
  [[ -f "$src/codegraph.db-wal" ]] && files+=("$src/codegraph.db-wal")
  if ! cp -c "${files[@]}" "$dst/" 2>/dev/null; then
    rm -rf "$dst"
    exit 0
  fi
fi

# A failed sync on a fresh clone leaves a half-written index: drop it so codegraph
# falls back to the main checkout's index instead of answering from a broken one.
if ! codegraph sync -q "$top" >"$dst/seed.log" 2>&1; then
  (( fresh )) && rm -rf "$dst"
  exit 0
fi
