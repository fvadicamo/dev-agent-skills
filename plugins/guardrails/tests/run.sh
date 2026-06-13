#!/usr/bin/env bash
# Regression tests for the guard-destructive PreToolUse hook.
# Run after ANY change to hooks/guard-destructive.sh.
#
#   bash tests/run.sh                      # all cases/*.txt
#   bash tests/run.sh cases/03-mktemp.txt  # specific file(s)
#
# Overrides (for development):
#   GUARD_HOOK=/path/to/hook.sh   test a candidate hook instead of the shipped one
#   GUARD_TEST_CWD=/deep/dir      project root used as the session cwd
#
# Case format (one per line in cases/*.txt):
#   EXPECTED ::: EXTRA ::: COMMAND
#     EXPECTED  one of SILENT | ASK | BLOCK
#     EXTRA     value for $GUARD_ALLOWED_EXTRA, or "-" for none
#     COMMAND   the Bash command; use <NL> for an embedded newline
#   Lines starting with # and blank lines are ignored.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="${GUARD_HOOK:-$here/../hooks/guard-destructive.sh}"
# A trustworthy project root: deep, not a temp dir, not $HOME. The tests dir fits.
CWD="${GUARD_TEST_CWD:-$here}"

[[ -f "$HOOK" ]] || { echo "hook not found: $HOOK" >&2; exit 2; }
command -v jq >/dev/null || { echo "jq is required" >&2; exit 2; }

files=("$@")
[[ ${#files[@]} -eq 0 ]] && files=("$here"/cases/*.txt)

tp=0; tf=0
for data in "${files[@]}"; do
  [[ -f "$data" ]] || { echo "no such cases file: $data" >&2; exit 2; }
  p=0; f=0; fails=""
  while IFS= read -r raw; do
    [[ -z "$raw" || "$raw" == \#* ]] && continue
    exp=${raw%%' ::: '*}; rest=${raw#* ::: }
    extra=${rest%%' ::: '*}; cmd=${rest#* ::: }
    [[ "$extra" == "-" ]] && extra=""
    cmd=${cmd//<NL>/$'\n'}
    json=$(jq -nc --arg c "$cmd" --arg w "$CWD" '{tool_input:{command:$c},cwd:$w}')
    out=$(printf '%s' "$json" | GUARD_ALLOWED_EXTRA="$extra" bash "$HOOK" 2>&1); rc=$?
    if   [[ $rc -eq 2 ]]; then got=BLOCK
    elif printf '%s' "$out" | grep -qE '"permissionDecision":[[:space:]]*"ask"'; then got=ASK
    elif [[ $rc -eq 0 && -z "$out" ]]; then got=SILENT
    else got="ERR(rc=$rc)"; fi
    if [[ "$got" == "$exp" ]]; then
      p=$((p+1))
    else
      f=$((f+1)); fails+=$'\n'"    exp=$exp got=$got | ${cmd//$'\n'/ <NL> }"
    fi
  done < "$data"
  printf '%-32s PASS=%-3d FAIL=%d%s\n' "$(basename "$data")" "$p" "$f" "$fails"
  tp=$((tp+p)); tf=$((tf+f))
done
echo "--------------------------------------------------------------"
echo "TOTAL  PASS=$tp  FAIL=$tf"
[[ $tf -eq 0 ]]
