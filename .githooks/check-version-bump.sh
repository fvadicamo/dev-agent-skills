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

# "name<TAB>version" for every marketplace entry that carries a version, read from the
# INDEX. One call, not one per plugin. Needs python3; when it is missing the caller says so
# rather than passing in silence, because a check that evaporates quietly reads as a pass.
entry_map() {
    command -v python3 >/dev/null 2>&1 || { echo "__nopython__"; return; }
    git show ":.claude-plugin/marketplace.json" 2>/dev/null | python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
for e in d.get("plugins", []):
    if e.get("name") and e.get("version"):
        print("%s\t%s" % (e["name"], e["version"]))
' 2>/dev/null
}

rc=0
changed="$(git diff --cached --name-only -- plugins/ | cut -d/ -f2 | sort -u)"

# Which plugins get their entry verified. The set is NOT just the plugins with staged
# changes: editing only .claude-plugin/marketplace.json is exactly how a version gets
# "fixed" by hand, and that edit touches no plugin directory at all. Checking only the
# changed plugins let it through -- measured, this is the hole the first version shipped.
entries="$(entry_map)"
if [ "$entries" = "__nopython__" ]; then
    echo "pre-commit: python3 not found - the marketplace-entry check did NOT run." >&2
    entries=""
elif git diff --cached --name-only -- .claude-plugin/marketplace.json | grep -q .; then
    to_verify="$(printf '%s\n' "$entries" | cut -f1)"     # marketplace touched: verify all
else
    to_verify="$changed"
fi

# The marketplace entry advertises a version to the browser UI before anything is fetched,
# so a stale one misinforms exactly the reader who has no way to check. `claude plugin tag`
# refuses on a mismatch, but only at tag time: without this the pair drifts until someone
# tags.
for p in ${to_verify:-}; do
    [ -n "$p" ] || continue
    ev="$(printf '%s\n' "$entries" | awk -F'\t' -v n="$p" '$1==n {print $2; exit}')"
    [ -n "$ev" ] || continue                     # no entry, or an entry with no version
    pv="$(version_at index "$p")"
    [ -n "$pv" ] || continue                     # entry for a plugin not in this tree
    [ "$ev" = "$pv" ] && continue
    echo "pre-commit: plugins/$p is $pv but its marketplace.json entry says $ev." >&2
    echo "  plugin.json wins at install time, so the entry misinforms the plugin" >&2
    echo "  browser, which is the only place that version is read before a fetch." >&2
    echo "  Set the entry to $pv." >&2
    rc=1
done

for p in $changed; do
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
