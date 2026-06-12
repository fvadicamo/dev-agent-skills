#!/usr/bin/env bash
# PreToolUse hook on Bash: guard destructive commands.
#   Catastrophic patterns      -> exit 2 (hard block, stderr fed back to Claude).
#   Other destructive patterns -> permissionDecision "ask" (force a confirmation).
#
# rm / rmdir are SCOPE-AWARE: an operation whose operands ALL resolve strictly
# inside the allowed workspace runs SILENTLY (no prompt). The allowed workspace is
#   - the Claude session project root ($CLAUDE_PROJECT_DIR, else the cwd), unless
#     that root is "/" or $HOME (too broad to trust as a blanket allow),
#   - the temp dirs (/tmp, /private/tmp, /var/tmp, /var/folders),
#   - any colon-separated extra roots in $GUARD_ALLOWED_EXTRA (per-node scratch,
#     e.g. "/mnt/scratch:/mnt/ai/tmp" on Kalypso).
# Anything OUTSIDE that space, or any operand the hook cannot resolve before
# execution (a glob like *.o, a variable like $BUILD, a ~ path), is treated as
# OUTSIDE -> a single confirmation prompt is raised, carrying the reflective
# question. The danger is deleting user data outside the work area, not build
# artifacts inside it.
#
# The "preceding char" class includes quotes, so destructive commands wrapped
# in ssh '...' / sh -c "..." are caught too.

input=$(cat)
cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[[ -z "$cmd" ]] && exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[[ -n "$cwd" && -d "$cwd" ]] && cd "$cwd" 2>/dev/null

# Token boundary that may precede a command word: line start, separators,
# whitespace, or an opening quote (covers `ssh host 'rm ...'`).
pre="(^|[;&|('\"]|[[:space:]])"

block() {
  echo "BLOCKED by guard-destructive: $1" >&2
  echo "Ask the user for confirmation before proceeding." >&2
  exit 2
}

ask() {
  printf '%s' "$1" | jq -R -s \
    '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"ask",permissionDecisionReason:.}}'
  exit 0
}

# --- Catastrophic: hard block (unchanged) ---
echo "$cmd" | grep -qE 'rsync([[:space:]]|$)([^|;&]*--delete)' && \
  block "rsync with --delete*: risk of unintended remote deletions."

echo "$cmd" | grep -qE '(docker[[:space:]]+(container[[:space:]]+)?rm[^|;&]*-[^[:space:]]*v|docker[[:space:]]+volume[[:space:]]+rm)' && \
  block "docker rm with -v or docker volume rm: risk of losing persistent volumes."

echo "$cmd" | grep -qE 'rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+(/|~|\$HOME)([[:space:]]|$)' && \
  block "recursive rm on the root / or the home directory."

# --- Allowed-workspace resolution (used by rm / rmdir) ---

# Session project root; ignored if it is too broad to trust as a blanket allow.
project_root="${CLAUDE_PROJECT_DIR:-$cwd}"
case "$project_root" in
  ""|"/"|"$HOME") project_root="__none__" ;;
esac

# Absolute path WITHOUT requiring the target to exist (it is about to be deleted).
abspath() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$PWD" "$1" ;;
  esac
}

# True only for an operand we can resolve AND that sits strictly under an allowed
# root. Globs / variables / ~ / traversal are unresolvable pre-exec -> NOT allowed.
is_allowed_operand() {
  case "$1" in
    *'*'*|*'?'*|*'['*|*'$'*|*'`'*|*'~'*) return 1 ;;  # glob / var / home: cannot resolve
    *..*) return 1 ;;                                  # traversal
  esac
  local ap; ap=$(abspath "$1")
  case "$ap" in
    /tmp/?*|/private/tmp/?*|/var/tmp/?*|/var/folders/?*) return 0 ;;
  esac
  [[ "$project_root" != "__none__" ]] && case "$ap" in "$project_root"/?*) return 0 ;; esac
  local IFS=: root
  for root in $GUARD_ALLOWED_EXTRA; do
    [[ -n "$root" ]] && case "$ap" in "$root"/?*) return 0 ;; esac
  done
  return 1
}

# Enumerate rm/rmdir operands; list each with where it lands so the user (on the
# rare out-of-scope prompt) sees exactly what is at stake.
scoped_check() {
  local verb=$1 seg listing="" operands=0 outside=0 tok p
  seg=$(echo "$cmd" | grep -oE "${verb}[[:space:]][^;&|]*" | head -1)
  for tok in ${seg#${verb} }; do
    [[ "$tok" == -* ]] && continue
    p=${tok%\"}; p=${p#\"}; p=${p%\'}; p=${p#\'}
    operands=$((operands + 1))
    if is_allowed_operand "$p"; then
      if [[ -d "$p" ]]; then
        n=$(find "$p" -type f 2>/dev/null | wc -l | tr -d ' ')
        listing+=$'\n'"  [in-scope DIR]  $p  ($n files inside)"
      else
        listing+=$'\n'"  [in-scope]      $p"
      fi
    else
      outside=$((outside + 1))
      if [[ -d "$p" ]]; then
        n=$(find "$p" -type f 2>/dev/null | wc -l | tr -d ' ')
        listing+=$'\n'"  [OUTSIDE DIR]   $p  ($n files inside)"
      elif [[ -e "$p" ]]; then
        listing+=$'\n'"  [OUTSIDE]       $p"
      else
        listing+=$'\n'"  [UNRESOLVED]    $tok  (glob/var/missing: treated as outside)"
      fi
    fi
  done
  # All operands inside the allowed workspace: run silently.
  [[ "$operands" -gt 0 && "$outside" -eq 0 ]] && exit 0
  local msg="'$verb' touches paths OUTSIDE the allowed workspace. Before you confirm, re-check: is this deletion part of the process you were following and expected? Could it destroy pre-existing user data, or anything outside the work area? Re-verify the targets and parameters."
  [[ -n "$listing" ]] && msg+=$'\n'"Targets resolved now:$listing"
  ask "$msg"
}

echo "$cmd" | grep -qE "${pre}rm([[:space:]]|\$)"    && scoped_check rm
echo "$cmd" | grep -qE "${pre}rmdir([[:space:]]|\$)" && scoped_check rmdir

# --- Destructive on non-file state / rare: still force a confirmation ---

echo "$cmd" | grep -qE 'git[[:space:]]+(reset[[:space:]]+--(hard|keep)|clean[[:space:]]+-[a-zA-Z]*[fdx]|checkout[[:space:]]+--[[:space:]]|restore([[:space:]]|$))' && \
  ask "Destructive git command for the working tree (reset --hard / clean -f / checkout -- / restore): uncommitted changes would be lost. Confirm before proceeding."

echo "$cmd" | grep -qE "${pre}(shred|truncate|mkfs[.a-zA-Z]*)([[:space:]]|\$)" && \
  ask "Destructive command (shred/truncate/mkfs) detected. Confirm before proceeding."

echo "$cmd" | grep -qE "${pre}dd[[:space:]]" && \
  ask "'dd' command detected. Check of= and parameters before proceeding."

exit 0
