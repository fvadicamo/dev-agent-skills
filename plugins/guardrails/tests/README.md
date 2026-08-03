# guard-destructive tests

Behavior tests for `../hooks/guard-destructive.sh`. Run them after **any** change
to the hook to confirm no regressions.

```sh
bash tests/run.sh                       # all suites
bash tests/run.sh cases/03-mktemp.txt   # one suite
```

The runner exits non-zero if any case fails (usable in pre-commit / CI). It works
on both macOS (bash 3.2 / BSD awk) and Linux (bash 4+ / mawk|gawk).

## What it does

For each case the runner builds the JSON a `PreToolUse` hook receives
(`{tool_input:{command}, cwd}`), pipes it to the hook, and classifies the result:

| Verdict | How the hook signalled it |
|---------|---------------------------|
| `BLOCK`  | exit code 2 (catastrophic hard block) |
| `ASK`    | `permissionDecision: "ask"` on stdout (confirmation) |
| `SILENT` | exit 0 with no output (allowed, no prompt) |

`cwd` defaults to this `tests/` directory: a deep, non-temp path, so the
project-root scope logic is exercised for real (relative operands resolve under
it). Temp paths (`/tmp/...`) and `$GUARD_ALLOWED_EXTRA` roots are tested via the
per-case EXTRA column. No real files are created or deleted: the hook only
analyses the command string.

## Case format

One case per line in `cases/*.txt`:

```
EXPECTED ::: EXTRA ::: COMMAND
```

- `EXPECTED` — `SILENT` | `ASK` | `BLOCK`
- `EXTRA` — value for `$GUARD_ALLOWED_EXTRA`, or `-` for none
- `COMMAND` — the Bash command; use `<NL>` for an embedded newline (heredocs, multi-line)

Lines starting with `#` and blank lines are ignored.

## Suites

| File | Covers |
|------|--------|
| `01-scope.txt` | scope-aware rm/rmdir (in-workspace silent, outside prompts), catastrophic hard-blocks, the always-prompt set (git/dd/shred) |
| `02-command-vs-data.txt` | the normalized command view: a destructive pattern merely *mentioned* (heredoc, commit message, echo/grep arg, comment) stays inert, while interpreter-wrapped commands (ssh / sh -c / su / eval) are still caught |
| `03-mktemp.txt` | a variable assigned from a bare `mktemp` in the same command counts as temp (the create-workspace / clean-up idiom), with the conservative guards |
| `04-mktemp-adversarial.txt` | attacks on the temp-var path: loop/read rebinding, `..` traversal out of a temp dir, lookalikes — must not pass silently |
| `05-static-vars.txt` | a variable assigned a static literal path in the same command resolves to that path and runs the normal scope check |
| `06-docker-rm-flag.txt` | `docker run --rm` is the container flag, not the `rm` command: the operand scan anchors on a real `rm`/`rmdir` word |
| `07-chained-rm.txt` | every `rm`/`rmdir` on the line is checked, not just the first: a chained command whose *later* deletion leaves the workspace still prompts |
| `08-special-vars.txt` | integer-only special vars (`$$`, `$!`, `$PPID`, `$BASHPID`, `$RANDOM`) expand to a bare number, so they cannot move an in-scope path out of scope |
| `09-nested-interpreters.txt` | fixpoint normalization: a destructive command inside an inner interpreter quote wrapped by an outer one (`ssh '... bash -lc "rm ..."'`) is still detected |
| `10-glob-and-redir.txt` | a glob whose literal directory prefix sits under an allowed root is confined there; redirections are not mistaken for `rm` operands |

Keep this table complete when adding a case file. It went six suites out of date once,
which is how a reader concludes the hook covers less than it does.

## Overrides (development)

- `GUARD_HOOK=/path/to/hook.sh` — test a candidate hook instead of the shipped one
- `GUARD_TEST_CWD=/deep/dir` — use a different session cwd / project root

## Adding cases

When you change the hook, add cases that pin the new behavior **and** its failure
modes. For a guardrail the dangerous direction is a false *negative* (something
destructive that runs silently), so favour adversarial cases that should be
`ASK`/`BLOCK` and assert they are.
