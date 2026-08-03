#!/usr/bin/env bash
# Bench for .githooks/check-version-bump.sh.
#
#   bash .githooks/tests/run.sh
#   BUMP_SCRIPT=/path/to/candidate.sh bash .githooks/tests/run.sh
#
# The override is what makes this provable rather than decorative: point it at a script
# that always exits 0 and the bench must go red. A bench nobody has seen fail says nothing.
#
# Each case builds a throwaway repo with a plugin at a known version, stages a change, and
# asserts the exit code. Nothing touches the repo this file lives in.

set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="${BUMP_SCRIPT:-$here/../check-version-bump.sh}"
[ -f "$SCRIPT" ] || { echo "missing script: $SCRIPT" >&2; exit 2; }
SCRIPT="$(cd "$(dirname "$SCRIPT")" && pwd)/$(basename "$SCRIPT")"

pass=0; fail=0
work="$(mktemp -d)" || exit 2
trap 'rm -rf "$work"' EXIT

# Builds a repo with plugin `foo` at $1, committed, then leaves it as $PWD.
# $2, when given, is the version its marketplace entry advertises.
scaffold() {
    local ver="$1" entry="${2:-}" dir
    dir="$work/case-$((pass + fail))-$RANDOM"
    mkdir -p "$dir/plugins/foo/.claude-plugin" "$dir/plugins/foo/skills/bar" "$dir/plugins/foo/tests" "$dir/.claude-plugin"
    cd "$dir" || return 1
    git init -q .
    git config user.email t@example.invalid; git config user.name t
    printf '{ "name": "foo", "version": "%s" }\n' "$ver" > plugins/foo/.claude-plugin/plugin.json
    printf -- '---\nname: bar\ndescription: bench.\n---\nbody\n' > plugins/foo/skills/bar/SKILL.md
    printf 'case\n' > plugins/foo/tests/cases.txt
    printf '# repo\n' > README.md
    set_entry "$entry"
    git add -A && git -c commit.gpgsign=false commit -qm init
}

set_version() { printf '{ "name": "foo", "version": "%s" }\n' "$1" > plugins/foo/.claude-plugin/plugin.json; }

# No argument: an entry without a version, which is legitimate and must not be flagged.
set_entry() {
    if [ -n "${1:-}" ]; then
        printf '{ "name": "m", "plugins": [ { "name": "foo", "source": "./plugins/foo", "version": "%s" } ] }\n' "$1"
    else
        printf '{ "name": "m", "plugins": [ { "name": "foo", "source": "./plugins/foo" } ] }\n'
    fi > .claude-plugin/marketplace.json
}

check() {  # $1 expected exit, $2 label
    local got
    bash "$SCRIPT" >/dev/null 2>&1; got=$?
    if [ "$got" = "$1" ]; then
        printf '  ok    %s      %s\n' "$1" "$2"; pass=$((pass + 1))
    else
        printf '  FAIL  exp=%s got=%s  %s\n' "$1" "$got" "$2"; fail=$((fail + 1))
    fi
}

echo "== a shipped file that changes under a frozen version is blocked =="

scaffold 1.2.0
printf 'changed\n' >> plugins/foo/skills/bar/SKILL.md && git add -A
check 1 "SKILL.md edited, version left at 1.2.0 (the privacy-guard case)"

scaffold 1.2.0
printf 'changed\n' >> plugins/foo/skills/bar/SKILL.md && set_version 1.2.1 && git add -A
check 0 "same edit with the version bumped to 1.2.1"

echo "== tests/ is shipped too, so it counts =="

scaffold 1.7.4
printf 'more\n' >> plugins/foo/tests/cases.txt && git add -A
check 1 "only tests/ changed, version frozen (the guardrails case)"

echo "== and what a plugin does not ship does not count =="

scaffold 1.0.0
printf 'docs\n' >> README.md && git add -A
check 0 "a repo-level file changed, no plugin touched"

scaffold 1.0.0
set_version 1.0.1 && git add -A
check 0 "only the version changed, nothing else"

echo "== the marketplace entry must not advertise a version the plugin does not have =="

scaffold 1.2.0 1.2.0
printf 'changed\n' >> plugins/foo/skills/bar/SKILL.md && set_version 1.2.1 && git add -A
check 1 "plugin bumped to 1.2.1, entry left at 1.2.0"

scaffold 1.2.0 1.2.0
printf 'changed\n' >> plugins/foo/skills/bar/SKILL.md && set_version 1.2.1 && set_entry 1.2.1 && git add -A
check 0 "both moved together"

scaffold 1.2.0
printf 'changed\n' >> plugins/foo/skills/bar/SKILL.md && set_version 1.2.1 && git add -A
check 0 "an entry carrying no version at all is legitimate, not a mismatch"

echo "== the lifecycle edges must not block =="

scaffold 1.0.0
mkdir -p plugins/newone/.claude-plugin
printf '{ "name": "newone", "version": "0.1.0" }\n' > plugins/newone/.claude-plugin/plugin.json
git add -A
check 0 "a plugin being ADDED has no version to bump from"

scaffold 1.0.0
git rm -rq plugins/foo
check 0 "a plugin being REMOVED is not short a bump"

echo
if [ "$fail" -eq 0 ]; then
    echo "-- $pass passed, 0 failed --"
else
    echo "-- $pass passed, $fail FAILED --"
fi
[ "$fail" -eq 0 ]
