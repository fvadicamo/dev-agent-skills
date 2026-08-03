#!/usr/bin/env bash
# Block a commit that changes a file a plugin SHIPS without bumping that plugin's version.
#
#   check-version-bump.sh        (exit 0 nothing to report, 1 a plugin is short a bump)
#
# Why this exists. `claude plugin update` compares the version in plugin.json, so a shipped
# file that changes under a frozen number never reaches an installed copy, and nothing says
# so: the node keeps running the old content while the number claims it is current. That is
# the DIVERGED case check-sync.sh was written to catch for the materialized copies of
# check_privacy.sh, one level up, where nothing was watching.
#
# Measured in this repo, twice, neither noticed by anyone at the time:
#   - guardrails, four commits to guard-destructive.sh after the bump to 1.7.4;
#   - privacy-guard, SKILL.md rewritten after the bump to 1.2.0, leaving two different
#     contents both called 1.2.0 (repo vs installed cache, 12 lines apart).
#
# Everything under plugins/<name>/ is shipped: the installed copy under
# ~/.claude/plugins/cache/<marketplace>/<name>/<version>/ is the whole directory, tests
# included (verified against a real cache). So the rule is "any staged change under a
# plugin bumps that plugin", not a hand-kept list of which subdirectories count. A list
# like that is wrong the day someone adds a directory nobody thought of, and it fails
# silently, which is the failure mode this check exists to remove.

set -uo pipefail

root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
cd "$root" || exit 0

version_at() {  # $1 = HEAD | index, $2 = plugin name
    case "$1" in
        HEAD)  git show "HEAD:plugins/$2/.claude-plugin/plugin.json" 2>/dev/null ;;
        index) git show ":plugins/$2/.claude-plugin/plugin.json"     2>/dev/null ;;
    esac | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1
}

rc=0
for p in $(git diff --cached --name-only -- plugins/ | cut -d/ -f2 | sort -u); do
    [ -n "$p" ] || continue
    old="$(version_at HEAD "$p")"
    new="$(version_at index "$p")"

    # No version in HEAD: the plugin is being added, there is nothing to bump from.
    # No version in the index: the plugin is being removed.
    [ -n "$old" ] && [ -n "$new" ] || continue
    [ "$old" = "$new" ] || continue

    echo "pre-commit: plugins/$p ships changed files but plugin.json is still $new." >&2
    echo "  Everything under plugins/$p/ is shipped, tests included. Without a bump," >&2
    echo "  'claude plugin update' compares the number, sees no change, and never fetches" >&2
    echo "  this content: installed copies stay on the old files under the same version." >&2
    echo "  Bump plugins/$p/.claude-plugin/plugin.json (and its marketplace entry)." >&2
    rc=1
done

exit $rc
