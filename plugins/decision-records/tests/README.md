# decision-records tests

```sh
bash plugins/decision-records/tests/run.sh
```

Covers `check-decisions.sh`. Exits non-zero on failure, runs on macOS and Linux, and
touches nothing outside a temp directory.

## What it covers

**Every one of the eight checks has a fixture that makes it fail.** That is the shape of the
file, not a nice-to-have: a suite made only of cases that must pass goes green against a
validator that validates nothing, and the dangerous direction for a check is the false
negative, where nothing is printed and the collection reads as clean.

Eight codes can each exit 1, so an exit code alone cannot say which check fired. `because`
asserts the code too, for the same reason `.githooks/tests/run.sh` has `check_because`.

Beside each negative case, the controls that stop it from being a check that fires on
everything: a supersede reference that resolves, a declared vocabulary that matches, two
supersede statuses that differ only in whom they name, two dated records on the same day, a
section only one record carries.

All four status forms are exercised by a clean fixture each, so a form that quietly stopped
being recognised fails a case instead of turning every record in that dialect into a
`STATUS` violation: frontmatter (`house`), a `## Status` section (`nygard`), a bold field
(`ecc`), a `- Status:` bullet (`bullets`). Same for the three supersede reference forms: a
markdown link, `ADR-0009`, and a bare number, each with the dangling case and the resolving
one.

Four cases pin design decisions rather than defects, because each is a place where the
obvious implementation is wrong:

- **required sections are a majority, not an intersection.** Under an intersection one
  sloppy record erases the requirement for every other one, so the check stops checking
  exactly when the collection has started to rot.
- **`DUPLICATE` does not apply to dated collections.** There the whole filename is the
  identifier (the log4brains answer in [adr/madr#28](https://github.com/adr/madr/issues/28)),
  so two records sharing a date is legitimate and flagging it would invent a rule. Pinned in
  **both** date shapes, because log4brains itself writes the compact `YYYYMMDD-` one and
  recognising only `YYYY-MM-DD` sent it into the numbered branch, where the check invented
  exactly that rule.
- **a collection matching no published spec must pass.** The `house` fixture is dated
  filenames, a frontmatter status and a bespoke section set. Every linter in the prior art
  reports that convention as violations; this one has to accept it, and the case fails if
  it stops doing so.
- **no closed list of shapes is complete, so being wrong about EVERY record is the worst
  failure.** The `bullets` and `prefixed` fixtures are the two shapes the first version did
  not know: a status carried as a `- Status:` bullet, and a number carried behind a word in
  `ADR-031-slug.md`. The first produced a `STATUS` violation on every record of a legitimate
  collection; the second silently switched `NAME` and `DUPLICATE` off. A tool wrong about
  every record does not get corrected, it gets switched off, and the other seven checks go
  with it. Both were found in review, on four real collections, and both directions are
  pinned here.

And the verdict a guard must never fake: an empty directory, a directory holding only an
index and a template, a directory that is not there, no arguments, an option missing its
value, an unknown option, and two directories at once all exit **2**, never a clean 0 over
nothing checked.

## Overrides

```sh
CHECK_SCRIPT=/path/to/candidate.sh bash plugins/decision-records/tests/run.sh
```

The override is what makes this bench provable rather than decorative:

```sh
printf '#!/usr/bin/env bash\nexit 0\n' > /tmp/always-ok.sh
CHECK_SCRIPT=/tmp/always-ok.sh bash plugins/decision-records/tests/run.sh
# -- 25 passed, 42 failed --
```

A bench nobody has seen fail says nothing. Pointing it at a script that always exits 0
turns 42 of the 67 cases red; the 25 that stay green are the ones asserting a clean
collection passes, which is exactly what a stub gets right by accident.

Stronger, and the check worth repeating after a change: **remove a guard from the real
script and confirm the case written for it goes red.** A test can pass *beside* the guard it
claims to hold, because something earlier short-circuits. Measured on this suite:

| Mutation | Cases that go red |
|---|---|
| the empty-collection guard exits 0 instead of 2 | the two `exits 2` cases, and nothing else |
| required sections by intersection instead of majority | the two `SECTION` cases |
| the index checked in one direction only | `INDEX: idx-ghost`, alone |
| the `- Status:` bullet form removed from `status_of` | the bullet `STATUS` case and *status VALUE was read* |
| `STATUS` fires per record even when no record has one | the two statusless cases |
| the `<prefix>-NNN` scheme unrecognised | the `prefixed` report case and its `DUPLICATE` case |
| the `## Status` reader does not stop at the next heading | the empty-section `STATUS` case and the vocabulary-leak case |
| the whitespace squeeze removed from `headings_of` | the double-space heading case |
| the compact `YYYYMMDD-` date form unrecognised | the two same-day compact-date cases |
| the reference-style branch removed from `index_links` | *the INDEX check actually ran against it* |
| the index chosen by existence instead of by its links | the `index.md` beside a prose `README.md` case |
| the `--portable` path pattern requires a trailing slash | the bare-absolute-path `PORTABLE` case |
| `basename` collapsing the supersede link path | the out-of-collection `SUPERSEDE` case |
| the dated `NAME` guard neutered | the dated `NAME` case |

Each mutation kills exactly the cases written for it, which is what says the cases are
attached to the guards they name. Two of them are worth reading twice, because both times
the first run killed **fewer** cases than expected and the case had to be re-anchored:

- removing the bullet status form left the *bullet collection is clean* case green, because
  a collection where no status is recognised is skipped and also exits 0. The assertion on
  the reported status **vocabulary** was added for it: the value can only appear there if
  `status_of` extracted it.
- removing the reference-style link parser killed **nothing**. With no links found, the
  index candidate is rejected as not-an-index, the INDEX check is skipped, and the run exits
  0 for an unrelated reason: two fixes masking each other. The assertion that the INDEX check
  *ran* was added for it.

In both cases the case was passing *beside* the guard it claimed to hold, and only mutation
could say so. Reading the file again would not have.
