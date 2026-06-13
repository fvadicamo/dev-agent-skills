#!/usr/bin/env bash
# PreToolUse hook on Bash: guard destructive commands.
#   Catastrophic patterns      -> exit 2 (hard block, stderr fed back to Claude).
#   Other destructive patterns -> permissionDecision "ask" (force a confirmation).
#
# COMMAND-vs-DATA: pattern matching runs on a normalized view of the command, not
# the raw string, so a command that merely *mentions* a destructive pattern (in a
# heredoc body, a commit message, an echo/grep argument, a comment) is NOT flagged.
# Normalization (see strip_heredocs + transform):
#   - heredoc bodies are removed (data, never executed); a `<<` sitting inside an
#     open quote is NOT treated as a heredoc;
#   - comments are removed (quote-aware, so `#` inside a string is preserved);
#   - quoted strings are NEUTRALIZED, EXCEPT a quoted string that is the argument
#     of an interpreter (ssh / sh -c / bash -c / zsh -c / eval / su / doas /
#     runuser / $VAR -c), whose content is EXPOSED because it is a real command.
# So `git commit -m "...rm -rf..."` is inert, while `ssh host 'rm -rf /data'`,
# `sh -c "rsync --delete ..."` and `su -c 'rm -rf /'` are still caught.
#
# rm / rmdir are SCOPE-AWARE: an operation whose operands ALL resolve strictly
# inside the allowed workspace runs SILENTLY (no prompt). The allowed workspace is
#   - the Claude session project root ($CLAUDE_PROJECT_DIR, else the cwd), unless
#     that root is "/", $HOME, or a shallow top-level dir (too broad to trust),
#   - the temp dirs (/tmp, /private/tmp, /var/tmp, /var/folders),
#   - any colon-separated extra roots in $GUARD_ALLOWED_EXTRA (per-node scratch),
#   - a variable provably assigned from a bare `mktemp`/`mktemp -d` earlier in the
#     SAME command (the "create temp workspace ... rm -rf it" idiom); see
#     collect_temp_vars. Variables in general stay unresolvable -> prompt.
# Anything OUTSIDE that space, or any operand the hook cannot resolve before
# execution (glob *.o, variable $BUILD, ~ path, backslash escape, {} placeholder),
# is treated as OUTSIDE -> a single confirmation carrying the reflective question.

input=$(cat)
cmd_raw=$(printf '%s' "$input" | jq -r '.tool_input.command // empty')
[[ -z "$cmd_raw" ]] && exit 0

cwd=$(printf '%s' "$input" | jq -r '.cwd // empty')
[[ -n "$cwd" && -d "$cwd" ]] && cd "$cwd" 2>/dev/null

# --- Normalization ---------------------------------------------------------

# Drop heredoc bodies. A `<<DELIM` is only a heredoc when it is NOT inside an open
# quote (balanced quotes before it). Here-strings (<<<) and `<<N` are not heredocs.
strip_heredocs() {
  awk '
  BEGIN{ SQ=sprintf("%c",39); DQ=sprintf("%c",34) }
  {
    line=$0
    if (innh) { t=line; if (dash) sub(/^\t+/,"",t); if (t==delim) innh=0; next }
    if (match(line, /<<-?[ \t]*[^ \t]+/)) {
      p=substr(line,1,RSTART-1); nd=gsub(DQ,"\\&",p)
      p=substr(line,1,RSTART-1); ns=gsub(SQ,"\\&",p)
      third=substr(line,RSTART+2,1)
      if (third!="<" && nd%2==0 && ns%2==0) {
        dash=(third=="-")?1:0
        d=substr(line,RSTART,RLENGTH); sub(/<<-?[ \t]*/,"",d); gsub(/[^A-Za-z0-9_]/,"",d)
        if (d ~ /^[A-Za-z_][A-Za-z0-9_]*$/) { delim=d; innh=1 }
      }
      print line; next
    }
    print line
  }'
}

# mode=clean -> strip comments, keep quoted CONTENT (so rm operands survive).
# mode=scan  -> strip comments, NEUTRALIZE non-interpreter quotes, EXPOSE
#               interpreter-quoted content. Used for all pattern detection.
transform() {
  awk -v mode="$1" '
  BEGIN{ SQ=sprintf("%c",39); DQ=sprintf("%c",34) }
  { buf=buf $0 "\n" }
  END{
    n=length(buf); out=""; word=""; prev=""; pending=0; state=0; q=""; pc=""
    for(i=1;i<=n;i++){
      c=substr(buf,i,1)
      if(state==3){ if(c=="\n"){state=0; out=out c; pc="\n"} continue }
      if(state==0){
        if(c==SQ){ flush(); state=1; q=""; continue }
        if(c==DQ){ flush(); state=2; q=""; continue }
        if(c=="#" && (pc==""||pc==" "||pc=="\t"||pc=="\n"||pc==";"||pc=="|"||pc=="&"||pc=="("||pc=="{")){ flush(); state=3; continue }
        if(c==";"||c=="|"||c=="&"||c=="\n"||c=="("||c==")"||c=="{"||c=="}"||c=="`"){ flush(); out=out c; pending=0; prev=""; pc=c; continue }
        if(c==" "||c=="\t"){ flush(); out=out c; pc=c; continue }
        word=word c; pc=c; continue
      }
      if(state==1){ if(c==SQ){ closeq(); state=0; pc=SQ } else q=q c; continue }
      if(state==2){ if(c==DQ){ closeq(); state=0; pc=DQ } else q=q c; continue }
    }
    flush()
    printf "%s", out
  }
  function flush(){
    if(word!=""){
      out=out word
      if(word=="ssh"||word=="eval"||word=="su"||word=="doas"||word=="runuser") pending=1
      else if(word ~ /^-[A-Za-z]*c$/ && (prev ~ /(^|\/)[a-z]*sh$/ || prev ~ /^\$/)) pending=1
      prev=word; word=""
    }
  }
  function closeq(){
    if(mode=="clean") out=out q
    else { if(pending) out=out q; else out=out " " }
    pending=0; prev=""
  }'
}

cmd_clean=$(printf '%s' "$cmd_raw" | strip_heredocs | transform clean)
scan=$(printf '%s' "$cmd_raw" | strip_heredocs | transform scan)
# Fail safe: if normalization yields nothing, fall back to the raw command.
[[ -z "${scan//[[:space:]]/}" ]] && scan="$cmd_raw"
[[ -z "${cmd_clean//[[:space:]]/}" ]] && cmd_clean="$cmd_raw"

# Variables provably assigned from a bare mktemp in this same command. Their value
# is a fresh path under $TMPDIR, so `rm` of "$VAR" is a safe temp cleanup. Only
# bare `mktemp`/`mktemp -d` (flags -d/-q/-u, no positional template, no -p) and
# only single-assignment names (no reassignment) qualify. Result: ":NAME:NAME2:".
collect_temp_vars() {
  local caps cap name args cnt out=":"
  caps=$(printf '%s' "$cmd_clean" | grep -oE '[A-Za-z_][A-Za-z0-9_]*=("?)(\$\(|`)mktemp[^)`]*' 2>/dev/null)
  [[ -z "$caps" ]] && { printf '%s' "$out"; return; }
  while IFS= read -r cap; do
    [[ -z "$cap" ]] && continue
    name=${cap%%=*}
    args=${cap##*mktemp}
    [[ "$args" =~ ^[[:space:]]*(-[dqu]+[[:space:]]*)*$ ]] || continue
    cnt=$(printf '%s' "$cmd_clean" | grep -oE "(^|[^A-Za-z0-9_])${name}=" | wc -l | tr -d ' ')
    [[ "$cnt" == "1" ]] || continue
    case "$out" in *":$name:"*) : ;; *) out="${out}${name}:" ;; esac
  done <<< "$caps"
  printf '%s' "$out"
}
TEMP_VARS=$(collect_temp_vars)

pre="(^|[;&|(]|[[:space:]])"

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
echo "$scan" | grep -qE 'rsync([[:space:]]|$)([^|;&]*--delete)' && \
  block "rsync with --delete*: risk of unintended remote deletions."

echo "$scan" | grep -qE '(docker[[:space:]]+(container[[:space:]]+)?rm[^|;&]*-[^[:space:]]*v|docker[[:space:]]+volume[[:space:]]+rm)' && \
  block "docker rm with -v or docker volume rm: risk of losing persistent volumes."

echo "$scan" | grep -qE 'rm[[:space:]]+-[a-zA-Z]*[rR][a-zA-Z]*[[:space:]]+\\?(/|~|\$HOME)([[:space:]]|$)' && \
  block "recursive rm on the root / or the home directory."

# --- Allowed-workspace resolution (used by rm / rmdir) ---

project_root="${CLAUDE_PROJECT_DIR:-$cwd}"
case "$project_root" in
  ""|"/"|"$HOME") project_root="__none__" ;;
esac
# A trustworthy project root is not a shallow top-level dir (/Users, /mnt, /opt...).
case "$project_root" in
  __none__) : ;;
  */*/*) : ;;
  *) project_root="__none__" ;;
esac

abspath() {
  case "$1" in
    /*) printf '%s' "$1" ;;
    *)  printf '%s/%s' "$PWD" "$1" ;;
  esac
}

is_allowed_operand() {
  local vn
  # Operand rooted at a variable provably holding a fresh mktemp path -> temp.
  case "$1" in
    '$'*)
      vn=${1#\$}; vn=${vn#\{}; vn=${vn%%/*}; vn=${vn%\}}
      case "$TEMP_VARS" in *":$vn:"*) return 0 ;; esac
      ;;
  esac
  case "$1" in
    *'*'*|*'?'*|*'['*|*'$'*|*'`'*|*'~'*|*'\'*|*'{}'*) return 1 ;;  # glob/var/home/escape/placeholder
    *..*) return 1 ;;                                              # traversal
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

# Detection runs on $scan; operands are enumerated from $cmd_clean (real paths).
scoped_check() {
  local verb=$1 seg listing="" operands=0 outside=0 tok p
  seg=$(echo "$cmd_clean" | grep -oE "${verb}[[:space:]][^;&|]*" | head -1)
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
        listing+=$'\n'"  [UNRESOLVED]    $tok  (glob/var/escape/missing: treated as outside)"
      fi
    fi
  done
  [[ "$operands" -gt 0 && "$outside" -eq 0 ]] && exit 0
  local msg="'$verb' touches paths OUTSIDE the allowed workspace. Before you confirm, re-check: is this deletion part of the process you were following and expected? Could it destroy pre-existing user data, or anything outside the work area? Re-verify the targets and parameters."
  [[ -n "$listing" ]] && msg+=$'\n'"Targets resolved now:$listing"
  ask "$msg"
}

echo "$scan" | grep -qE "${pre}rm([[:space:]]|\$)"    && scoped_check rm
echo "$scan" | grep -qE "${pre}rmdir([[:space:]]|\$)" && scoped_check rmdir

# --- Destructive on non-file state / rare: still force a confirmation ---

echo "$scan" | grep -qE 'git[[:space:]]+(reset[[:space:]]+--(hard|keep)|clean[[:space:]]+-[a-zA-Z]*[fdx]|checkout[[:space:]]+--[[:space:]]|restore([[:space:]]|$))' && \
  ask "Destructive git command for the working tree (reset --hard / clean -f / checkout -- / restore): uncommitted changes would be lost. Confirm before proceeding."

echo "$scan" | grep -qE "${pre}(shred|truncate|mkfs[.a-zA-Z]*)([[:space:]]|\$)" && \
  ask "Destructive command (shred/truncate/mkfs) detected. Confirm before proceeding."

echo "$scan" | grep -qE "${pre}dd[[:space:]]" && \
  ask "'dd' command detected. Check of= and parameters before proceeding."

exit 0
