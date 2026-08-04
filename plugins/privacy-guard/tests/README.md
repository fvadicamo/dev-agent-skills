# privacy-guard tests

```sh
bash plugins/privacy-guard/tests/run.sh
```

Runs automatically from `.githooks/pre-commit` when anything under
`plugins/privacy-guard/` is staged, which is the only moment anyone reliably runs a suite.
The trigger is the whole plugin directory on purpose: it used to name the two
subdirectories that existed when it was written, and a plugin that grows a third would
have stopped running its suite without saying so.

## What it covers

`check_privacy.sh`: that a commit's **added** lines are what gets scanned and a token already
committed does not wedge later edits; that the reported line number is the one in the file
and not in the diff; that usage errors exit 2 instead of reporting a clean run over zero
files; that a guard with nothing to enforce (no denylist, or a denylist of comments only)
says so rather than pretending.

`check-sync.sh`: that a copy which is behind, or diverged at the same version, is reported
as such, and that a repo shipping no copy is named rather than passed over.

## Overrides

```sh
PRIVACY_SCRIPT=/path/to/candidate.sh bash tests/run.sh    # test a candidate before shipping
SYNC_SCRIPT=/path/to/candidate.sh    bash tests/run.sh
```

The overrides are what makes the suite provable rather than decorative: point it at the
version from before a fix and it must go red. Against the pre-1.9.0 `check_privacy.sh` it
reports four failures, one per defect fixed there.

## The XFAIL cases

Two cases assert behaviour the script does **not** have yet, and are reported as `xfail`
without failing the run:

- a malformed regex in the denylist makes `grep` exit 2, the condition is false, and a real
  leak passes with exit 0;
- `PRIVACY_DENYLIST` pointing at a file that is not there exits 0, exactly like the
  legitimate no-op of a repo that has no denylist. Setting the variable **declares** that a
  denylist exists, so the two cases are opposite and the script cannot tell them apart. It
  matters because `.local/` is gitignored: a task worktree never carries the denylist, and
  the remedy adopted downstream is to export an absolute path, which puts every worker in
  this case.

Deleting them would lose the only executable record of an open defect. Letting them fail
would leave a permanently red suite, which is a suite people stop reading. When the defect is
fixed the runner prints `XPASS`, says the marker must go, and fails the run until it does,
so a fix cannot land while the suite still calls it broken.
