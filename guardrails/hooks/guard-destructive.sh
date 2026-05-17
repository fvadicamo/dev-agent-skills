#!/usr/bin/env bash
# PreToolUse hook on Bash: guard destructive commands.
#   Catastrophic patterns      -> exit 2 (hard block, stderr fed back to Claude).
#   Other destructive patterns -> permissionDecision "ask" (force a confirmation).
# For rm, operands are enumerated so the user sees WHAT would be deleted
# (folder contents can change between an earlier check and the deletion).
# An rm whose operands ALL resolve strictly under a temp dir (/tmp,
# /private/tmp, /var/tmp, /var/folders) is exempted: temp files are disposable.
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

# --- Catastrophic: hard block ---
echo "$cmd" | grep -qE 'rsync([[:space:]]|$)([^|;&]*--delete)' && \
  block "rsync with --delete*: risk of unintended remote deletions."

echo "$cmd" | grep -qE '(docker[[:space:]]+(container[[:space:]]+)?rm[^|;&]*-[^[:space:]]*v|docker[[:space:]]+volume[[:space:]]+rm)' && \
  block "docker rm with -v or docker volume rm: risk of losing persistent volumes."

echo "$cmd" | grep -qE 'rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+(/|~|\$HOME)([[:space:]]|$)' && \
  block "recursive rm on the root / or the home directory."

# --- Destructive: force a confirmation prompt ---

# True only for a path STRICTLY under a temp dir. A bare /tmp, a trailing-slash
# bare dir, or any path containing `..` (traversal) is never temp.
is_temp_path() {
  case "$1" in
    *..*) return 1 ;;
    /tmp/?*|/private/tmp/?*|/var/tmp/?*|/var/folders/?*) return 0 ;;
    *) return 1 ;;
  esac
}

# rm in any form: enumerate operands so the user can verify before approving.
if echo "$cmd" | grep -qE "${pre}rm([[:space:]]|\$)"; then
  seg=$(echo "$cmd" | grep -oE 'rm[[:space:]][^;&|]*' | head -1)
  listing=""
  operands=0
  nontemp=0
  for tok in ${seg#rm }; do
    [[ "$tok" == -* ]] && continue
    p=${tok%\"}; p=${p#\"}; p=${p%\'}; p=${p#\'}
    operands=$((operands + 1))
    is_temp_path "$p" || nontemp=$((nontemp + 1))
    if [[ -d "$p" ]]; then
      n=$(find "$p" -type f 2>/dev/null | wc -l | tr -d ' ')
      listing+=$'\n'"  [DIR]  $p  ($n files inside)"
    elif [[ -e "$p" ]]; then
      listing+=$'\n'"  [FILE] $p"
    else
      listing+=$'\n'"  [?]    $tok  (not resolved by the hook)"
    fi
  done
  # All operands under a temp dir: no confirmation needed.
  [[ "$operands" -gt 0 && "$nontemp" -eq 0 ]] && exit 0
  msg="'rm' command detected. RE-VERIFY that what you are about to delete is exactly what you expect: a folder's contents can change after an earlier check."
  [[ -n "$listing" ]] && msg+=$'\n'"Targets resolved now:$listing"
  ask "$msg"
fi

echo "$cmd" | grep -qE "${pre}rmdir([[:space:]]|\$)" && \
  ask "'rmdir' command detected. Confirm the directory removal."

echo "$cmd" | grep -qE 'git[[:space:]]+(reset[[:space:]]+--(hard|keep)|clean[[:space:]]+-[a-zA-Z]*[fdx]|checkout[[:space:]]+--[[:space:]]|restore([[:space:]]|$))' && \
  ask "Destructive git command for the working tree (reset --hard / clean -f / checkout -- / restore): uncommitted changes would be lost. Confirm before proceeding."

echo "$cmd" | grep -qE "${pre}(shred|truncate|mkfs[.a-zA-Z]*)([[:space:]]|\$)" && \
  ask "Destructive command (shred/truncate/mkfs) detected. Confirm before proceeding."

echo "$cmd" | grep -qE "${pre}dd[[:space:]]" && \
  ask "'dd' command detected. Check of= and parameters before proceeding."

exit 0
