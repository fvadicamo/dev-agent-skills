#!/usr/bin/env bash
# Are a repo's materialized copies of check_privacy.sh current with this skill?
#
#   check-sync.sh REPO...        (exit 0 all current, 1 any divergence, 2 usage)
#
# check_privacy.sh is COPIED into each repo on purpose: the repo has to stand on its own
# for external contributors and CI, which do not have this plugin installed. The cost of
# copying is drift, and drift here is invisible: a copy that is a month behind looks
# exactly like a current one. Observed, which is why this exists and why the copies carry
# a version line in their header.
#
# Copies are asked to GIT, not to the filesystem: `ls-files` answers "what this repo
# ships", which is the question, and it answers it wherever the copy lives. A hardcoded
# scripts/check_privacy.sh would be a second place to keep in sync with the first.

set -uo pipefail

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 REPO..." >&2
    exit 2
fi

CANONICAL="$(cd "$(dirname "$0")" && pwd)/check_privacy.sh"
if [ ! -f "$CANONICAL" ]; then
    echo "check-sync.sh: canonical copy not found next to this script ($CANONICAL)." >&2
    echo "Nothing was compared: a silent pass here would read as 'everything is current'." >&2
    exit 2
fi

# `# check_privacy.sh 1.1.1 -- canonical copy: ...` -> `1.1.1`, empty if the line is absent
# (a copy older than the version line itself, which is the drift this was built for).
versione() {
    sed -n 's/^# check_privacy\.sh \([0-9][0-9.]*\) --.*/\1/p' "$1" | head -1
}

vc="$(versione "$CANONICAL")"
status=0

for repo in "$@"; do
    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        echo "SKIP     $repo: not a git repository"
        status=1
        continue
    fi
    trovate=0
    while IFS= read -r rel; do
        [ -n "$rel" ] || continue
        trovate=$((trovate + 1))
        copia="$repo/$rel"
        vr="$(versione "$copia")"
        if cmp -s "$CANONICAL" "$copia"; then
            echo "OK       $repo/$rel (${vc:-no version})"
        elif [ -z "$vr" ]; then
            echo "BEHIND   $repo/$rel: no version line, predates ${vc:-the canonical copy}. Recopy."
            status=1
        elif [ "$vr" != "$vc" ]; then
            echo "BEHIND   $repo/$rel: $vr, canonical is $vc. Recopy."
            status=1
        else
            # Stessa versione, byte diversi: qualcuno ha modificato la copia. E' il caso
            # peggiore, perche' la versione dichiara "sono aggiornato" e non lo e': la
            # modifica va portata a monte, o il sync successivo la cancella in silenzio.
            echo "DIVERGED $repo/$rel: version $vr but content differs. Take the change"
            echo "         upstream and recopy, or the next sync silently reverts it:"
            diff -u "$CANONICAL" "$copia" | sed -n '4,13p' | sed 's/^/         /'
            status=1
        fi
    done < <(git -C "$repo" ls-files -- '*check_privacy.sh' 2>/dev/null)
    if [ "$trovate" -eq 0 ]; then
        echo "NONE     $repo: ships no check_privacy.sh (guard installed another way, or not"
        echo "         installed). Said out loud because silence here would read as 'current'."
    fi
done

exit "$status"
