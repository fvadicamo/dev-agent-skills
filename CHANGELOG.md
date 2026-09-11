# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.16.0] - 2026-09-11

### Added

#### decision-records plugin, **0.2.3 -> 0.3.0**

- **`tests/claims.sh`, a bench of predicates over what the documentation claims.** `run.sh`
  checks that the script does what it should; this checks that `tests/README.md` and
  `SKILL.md` still say what is true: the case count, the stub run's two numbers, the site
  counts in the coverage section, the number of checks written in prose above the table
  listing them, and that every code the script can emit also has a line saying when it cannot
  apply. 20 predicates. **Not** run from the pre-commit: it runs the suite twice and takes
  about half a minute, so it is the check you run to close, before a release.
- **Why a bench and not one more review.** Six rounds of re-reading had been run on this
  plugin, and by the last ones most findings were about the previous round's corrections. A
  chain like that has no natural end, because every correction creates surface. A green bench
  says *what* was checked and *how*; "another reading found nothing" says neither, and does
  not distinguish a clean run from a lazy one.
- **The class it kills had bitten four times in one session**, and none of them was a code
  defect that any suite could have caught: `43` green cases where there were 51, "three
  reviews" over a five-row table, a mutation table saying three where the table had fourteen,
  and a case count that went 96 to 99 to 109 to 118 while a paragraph two lines up kept the
  old one.
- Each predicate carries its counter-proof: the run ends by re-checking itself against a copy
  of the tree with one number perturbed, which must go red. Every predicate was additionally
  perturbed by hand, one at a time, and **the fifth perturbation revealed a broken
  counter-proof rather than a broken predicate**: `sed` could not match a phrase that wraps
  across two lines, so it changed nothing and the bench stayed green for the right reason.
  Redone with a multi-line perturbation, the predicate reports `claimed=999 measured=18`.
- The bench found two defects in itself on its first two runs, which is the argument for
  writing the counter-proof into it rather than beside it: the code extraction carried a stray
  quote (`"DRIFT` instead of `DRIFT`), so the membership predicate could not match anything
  while the count predicate beside it stayed green; and the failure message named the two
  sides the wrong way round, which would have sent a reader to correct the wrong file.

### Changed

- Marketplace `metadata.version` 1.15.3 -> **1.16.0**.

## [1.15.3] - 2026-09-06

### Fixed

#### decision-records plugin, **0.2.2 -> 0.2.3**

- **The convention report was nondeterministic, and had been since the first version.**
  `producer | grep -q` under `set -o pipefail` is a race: `grep` exits at the first match, the
  producer dies of SIGPIPE, the pipeline status becomes 141 and the `if` reads false. It only
  bites once the producer's output passes the pipe buffer, which is why every fixture in the
  suite was too small to see it. Measured on a 12-record collection where every record carries
  a `- Status:` bullet: the reported status form flipped between `bullet` and `none` across
  identical runs, 5 times out of 8. Now 12 runs out of 12 agree. Two of the 27 real
  collections on the machine where this was found had their convention reported wrongly by
  that race, and now report correctly. The same shape was fixed in `links_a_record`, where the
  producer is the whole record list.
- **A regression introduced by 1.15.2**: the index candidate was chosen by glob order, which
  is locale-collated. With `README.md` and `readme.md` both present, `LC_ALL=C` exited 0 and
  `en_US.UTF-8` exited 1 with two records reported unindexed. Same directory, two verdicts,
  and the ambient locale produced the wrong one. The order is declared now, and any remaining
  case variant is resolved in `LC_ALL=C`.
- **Emphasis wrapping the first word** was not markup to the normaliser, only emphasis
  wrapping the whole value was. `**Superseded** by [0003](0003-x.md)` became
  `Superseded** by …`, so `--status` reported a violation on every record of a collection
  using that shape. That is inside the class `[1.15.2]` declared closed.
- The script header carried `check-decisions.sh 0.1.0` while the plugin shipped 0.2.2. The
  number is **removed** rather than synchronised: the header itself explains that this script
  is never copied, so nothing was keeping that number true, and a number nothing synchronises
  is a number that lies. The version that means something is the plugin's.

### Changed

- **The coverage sweep covers both families.** It had been run over every `say` site for two
  rounds and reported none uncovered, which was true about the half it looked at: three
  `skipped` sites had no case asserting them, and could have been deleted with the suite
  green. 18 `say` sites and 10 `skipped` sites are now mutated one at a time, each must
  produce at least one failure, and `tests/README.md` carries both loops.
- 109 cases -> **118**. Against a stub that always exits 0: 54 passed, 64 failed. Across the
  27 real collections, **no verdict changed** between 0.2.2 and 0.2.3.
- Marketplace `metadata.version` 1.15.2 -> **1.15.3**.

### Corrected in the 1.15.2 entry

- It named `Index.md` as one of the two findings that "turned out to be false positives". It
  was not: on 0.2.2's predecessor it exits 0, prints `index : none found`, lists `INDEX:`
  among the checks that did not run, and produces no violation under `--status`. It is a
  silence, exactly as it had been filed. The two that did fire on every record were the
  un-normalised status value and the trailing punctuation.

## [1.15.2] - 2026-09-06

### Fixed

#### decision-records plugin, **0.2.1 -> 0.2.2**

Three findings an earlier review had filed as "smaller, your call" were reproduced before
deciding, and **two of them turned out to be false positives rather than the silences they
had been recorded as**: the un-normalised status value and the sentence punctuation left
inside it, each reporting a violation on every record of a legitimate collection under
`--status`. The third, `Index.md`, is a silence exactly as it had been filed, and is fixed
here for consistency rather than for severity. That measurement is what moved the first two
from backlog to now.

All three were **contradictions already inside the script**, not missing features, and each
fix removes an asymmetry rather than adding a shape:

- `status_of` normalised the value in three of its four forms and not in the fourth, so a
  status written `**Accepted**`, or as a `- accepted` bullet under `## Status`, reached the
  checks raw. There is one normalisation now, applied at the end to all four forms. It follows
  that **markup is not vocabulary**: bold beside plain is the same status differently typeset
  and no longer reads as drift, while `Accepted` beside `accepted` still does, which is what
  `DRIFT` is for.
- `is_furniture()` lowercases, so `Index.md` was already **excluded from the records** as an
  index; the candidate selection then compared three literals and never used it as one,
  reporting "no index" on a directory that had one. Both places lower now.
- Trailing sentence punctuation (`accepted.`, `accepted;`) was part of the value. Found by the
  dogfood on a real 27-file collection whose deduced vocabulary read
  `accepted accepted. accepted;`. The stripped set is closed (`[.,;:]`) on purpose: an open
  rule there is how a normalisation starts eating meaning.

### Added

- **A declared limit** in `SKILL.md`: `STATUS` and `DRIFT` assume the status field holds a
  **token**, and key the vocabulary off its first word. Some collections put a paragraph there
  instead, and on those the deduced vocabulary is the first word of prose. Deciding where a
  token ends inside free text is guesswork, and guessing is how a validator starts reporting a
  collection's own convention back to it, so this is written down as a limit rather than
  normalised away. The remedy is one line: do not pass `--status` there. The other seven checks
  do not read that field and are unaffected.

### Changed

- 99 cases -> **109**. Against a stub that always exits 0: 51 passed, 58 failed.
- Marketplace `metadata.version` 1.15.1 -> **1.15.2**.

## [1.15.1] - 2026-09-02

### Fixed

#### decision-records plugin, **0.2.0 -> 0.2.1**

- **`ADR_template.md` was reported as a `NAME` violation.** The furniture exclusion was a
  list of three literals (`readme.md`, `index.md`, `template.md`) and missed it. Found by
  running the validator over **real collections** rather than over its own fixtures, which
  is the pass a suite written beside an implementation cannot perform: 8 files in that shape
  on the machine where it was found, and the tool was wrong about every collection using it.
  This repo's own coding rules name the shape ("exclusion lists are the common trap: they
  cover the cases you thought of, on the day you wrote it"), and it was one anyway.
- The exclusion is a pattern now, and **narrow on purpose**. Measured on the same disk,
  three real records carry the word in their slug
  (`ADR-0020-prompt-template-architecture.md` and two others), so matching `*template*`
  would have traded one false positive for three false negatives, the worse direction for a
  guard. The word must be the whole name or a whole leading or trailing component of it.
  Both directions have a case.
- **What the exclusion removes is now named** in *checks that did not run*. Deciding not to
  look at a file is a decision, and this script exists to refuse silent ones.
- The line that reports it was written **above** the function it calls, so it was a bare
  `command not found` on stderr, and on a collection with no furniture it would not have
  appeared at all. Fixed, and it is the failure shape worth remembering: a defect visible
  only on the inputs that exercise it.

### Changed

- 96 cases -> **99**. Against a stub that always exits 0: 44 passed, 55 failed.
  Marketplace `metadata.version` 1.15.0 -> **1.15.1**.

## [1.15.0] - 2026-09-02

### Fixed

#### decision-records plugin, **0.1.0 -> 0.2.0**

A third independent review, this one reading the **corrections** made after the second, found
that two of those corrections had restored the defect they removed in the other half of the
code. A correction is new code, and new code is where the next defect goes.

- **The index race came back.** The fix said "choose the candidate that links to records" and
  the code said "carries any `.md` link", so one ordinary `[the guide](../CONTRIBUTING.md)`
  in a prose `README.md` beat the real `index.md` and every record reported as unindexed.
  The fixture could not see it: it used a README with *no* links, the one case the defect
  does not cover.
- **`basename` collapsing was fixed at one of its two call sites.** SUPERSEDE got the fix,
  the index parser kept it, so a link to `../elsewhere/0003-x.md` made the local `0003-x.md`
  read as indexed, and a link to an existing `../docs/design.md` read as dangling.
- **The fix for one uncovered guard added another**: the new prefixed `NAME` guard shipped
  with no case, exactly the defect the previous round had found on the dated branch.
- `- **Status:** accepted` matched the new bullet regex and yielded `** accepted`, so the
  deduced vocabulary became `**` and `--status` fired on every record of a legitimate
  collection. One asterisk away from the shape the correction was written to fix.
- `RE_PREFIXED` read free-form titles as a numbered scheme: `use-2-phase-commit.md` beside
  `move-2-week-sprints.md` became "prefixed", their identifier became `2`, and the two were
  reported as a duplicate. A prefix is now a scheme only when the collection **shares** it.
- `--portable` fired on any URL carrying a `/home/` path segment.
- The index parser read the index's own fenced examples, so an index documenting its row
  format reported its example as a link to a missing file.
- A level-3 heading leaked into the status value exactly as the level-2 one had.
- `SECTION` could silently not run, inside the block whose stated purpose is to say what did
  not run; and `--require` resolving to nothing was silent where `--status` already spoke.
- An indented code block could supply a record's status, because four-space indentation is
  code by the markdown rule and the status patterns allowed any leading whitespace.

### Changed

- **Guard coverage is now measured, not sampled.** Every `say` site in the script, all
  eighteen, is mutated one at a time and each must produce at least one failing case. Both
  uncovered guards found so far were found this way and neither was the one anyone would
  have picked. `plugins/decision-records/tests/README.md` carries the one-liner, including
  the warning that it must run under bash: in zsh the loop does not split and reports
  "none uncovered" having tested nothing.
- **A prose promise is now a check.** SKILL.md states that every check says when it cannot
  apply; the suite asserts it against the script, one case per code.
- 67 cases -> **96**. Against a stub that always exits 0: 43 passed, 53 failed.
- Marketplace `metadata.version` 1.14.0 -> **1.15.0**.

### Corrected in the 1.14.0 entry

- It said the dated `NAME` guard "was the only `say` site in the script that no case was
  attached to". That was true when written and false one correction later.

## [1.14.0] - 2026-08-26

### Added

#### decision-records plugin (new, **0.1.0**)

- A plugin with one skill, `decision-records`: it writes decision records (ADRs) by
  proposing a draft and writing only after explicit approval, supersedes rather than
  rewriting an accepted record, and validates a collection with `check-decisions.sh`
  (exit 0 clean, 1 violations, 2 nothing to check). Eight checks, each printing a stable
  code: `NAME`, `SECTION`, `STATUS`, `DRIFT`, `SUPERSEDE`, `DUPLICATE`, `INDEX`, `PORTABLE`.
- **What is actually new about it, stated honestly.** ADR linters are not new and several
  are more capable: mdbook-lint ships 17 ADR rules, madr-lint covers MADR v2 to v4 and ships
  its own Claude skills, adrkit finds supersession cycles. They all validate against a
  *published* spec, Nygard or MADR, chosen by auto-detecting between those. A collection
  whose convention is neither has its own convention reported to it as violations. This one
  deduces the filename scheme, the section set and the status form from the records present,
  and needs no toolchain. The premise the work started from ("no skill validates an existing
  collection") was false and is recorded here rather than quietly dropped.
- **The deduction has a limit, and it is in the design.** The status *vocabulary* cannot be
  deduced: "the allowed statuses are the ones in use" can never say no. So the deduced side
  checks drift instead (`Accepted` beside `accepted`) and `--status` is the only way to
  declare a vocabulary. Required sections use a **majority**, not an intersection, because
  under an intersection one sloppy record erases the requirement for every other one.
- **No `template.md` is written into the target repo.** A template beside the records is a
  second home for the convention and the two diverge in silence. The most-installed prior
  art creates one; this is a deliberate departure and the skill says so.
- **No second denylist.** Private tokens stay `privacy-guard`'s job. `--portable` covers only
  what breaks when a record is *copied*: absolute paths, and links that climb out of the
  collection.
- `tests/run.sh`, 67 cases, every check with a negative fixture. Against a stub that always
  exits 0 it reports 25 passed, 42 failed.

### Fixed

#### decision-records plugin, before first release

Two reviews ran against the first version, and between them they found the defects below,
none of which the suite written alongside the implementation could see: a suite inherits its
author's blind spots by construction. All are fixed and each has a case now.

- **A status carried as a `- Status:` bullet was not recognised**, so every record of a
  collection using that form got a `STATUS` violation. Reproduced on four real collections;
  32 files on the machine where it was found. This is the failure this plugin exists to
  prevent, produced by the plugin: a tool wrong about every record does not get corrected,
  it gets switched off, and the other seven checks go with it.
- Consequently the `STATUS` check is now **collection-aware**: a record with no status is out
  of step only when its neighbours have one. When no record has one, that is a line in
  *checks that did not run*, not a violation per record. No closed list of four shapes is
  ever complete.
- **An empty `## Status` section** made the check unable to fire and put the next heading
  into the deduced vocabulary (`status vocabulary : ## accepted`).
- **A heading with two consecutive spaces** produced a `SECTION` violation on every record of
  an internally consistent collection: the majority vote rebuilt headings through awk with a
  single-space separator while the per-record set kept both.
- **`ADR-031-slug.md` was classified as "no scheme"**, silently switching `NAME` and
  `DUPLICATE` off; and **free-form filenames did the same**. Both now report what did not run.
- **log4brains' compact `YYYYMMDD-` date** fell into the numbered branch, so two records
  written on one day were reported as a `DUPLICATE`, inventing the exact rule the tests
  pin as one that must never be invented.
- **`--portable` missed a bare absolute path** not followed by a further `/`, the shape a
  sentence actually uses.
- **`README.md` won the index race unconditionally**, so a collection whose index is
  `index.md` and whose `README.md` is prose had every record reported as unindexed. The index
  is now the candidate that actually links to records. **Reference-style links** are read too.
- **A supersede link climbing out of the collection "resolved"**, because the path was
  collapsed with `basename` before the existence test.
- **The dated `NAME` guard had no negative fixture**, found by disabling every `say` site
  one at a time. It was not the last one: the fix for the prefixed scheme added another
  uncovered guard, caught the same way a round later. The method is now run over every site
  rather than over the ones anyone thought to check.
- Every fix is held down by mutation: fourteen guards removed one at a time, each killing
  exactly the cases written for it. Two cases had to be **re-anchored** because the first
  mutation run killed fewer cases than expected: they were passing *beside* the guard they
  named, which is the one thing reading the file again cannot reveal.

### Changed

- `.githooks/pre-commit` runs the new suite when anything under `plugins/decision-records/`
  is staged. Without that line the suite would never have run at commit time, and this repo
  has no CI.
- `README.md` and `CLAUDE.md`: 7 skills across 5 plugins, three suites, `scripts/` added to
  the architecture map, and a note that the mutation check is stronger than the
  `CHECK_SCRIPT=` override where a suite claims to hold one specific guard down.
- Marketplace `metadata.version` 1.13.2 -> **1.14.0**.

#### privacy-guard plugin, caught up here

- **1.3.3 shipped without a release and this is where it reaches anyone.** Commit `23114c9`
  bumped `plugins/privacy-guard/.claude-plugin/plugin.json` and its marketplace entry from
  1.3.2 to 1.3.3 and changed `SKILL.md`, but there was no changelog entry, no
  `privacy-guard--v1.3.3` tag, and `metadata.version` stayed at 1.13.2. So the content was on
  the default branch and no version anyone reads had moved: exactly the drift
  `check-version-bump.sh` exists to stop, one level up where nothing was watching.
- The tag has been created retroactively at `23114c9`, where `plugin.json` and the
  marketplace entry both read 1.3.3, which is the pair `claude plugin tag` validates.
- What 1.3.3 actually changed, documentation only: the arming step of the setup procedure
  now says to put a **token** in the test file, not a pattern. The denylist holds anchored
  extended regexes, so writing one verbatim does not match itself, the script exits 0, and
  that reads as "the guard is not armed" when in fact the test was wrong. Measured on
  2026-08-09 while arming three repos: 6 of 29 patterns happened to match their own text.
  `check_privacy.sh` itself is untouched and stays **1.2.1**.

## [1.13.2] - 2026-08-04

### Security

#### guardrails plugin
- A comment in `tests/cases/06-docker-rm-flag.txt` named the **private** repository the
  regression came from. The denylist did not catch it and could not: it holds node names,
  home paths and private ranges, and a private repo name is none of those. Found by an audit
  of the whole `gh` channel (33 sources, 1796 lines) run against the denylist first and then
  against generic detectors, which is the only pass that could see it.
- The same name is in a merged PR body, edited there too. Both remain in history: the commit
  that added the line, and GitHub's edit history for the PR body. Fixing forward is what is
  available without rewriting public history; the exposure is a project name, not a
  credential. Evidence for #12, which is about the `gh` channel having no technical guard.
- Plugin 1.7.5 -> **1.7.6**. No behaviour change: the hook is untouched.

### Added

#### privacy-guard plugin
- A second XFAIL case, holding down the open defect of #18: `PRIVACY_DENYLIST` pointing at a
  file that is not there exits 0, exactly like the legitimate no-op of a repo that has no
  denylist. Setting the variable **declares** that a denylist exists, so the two are opposite
  statements and the script cannot tell them apart.
- It is not a hypothetical shape. `.local/` is gitignored, so a task worktree never carries
  the denylist, and the remedy adopted downstream is to export an absolute `PRIVACY_DENYLIST`
  so workers can reach it. That puts every worker in precisely this case, where a stale path
  buys a guard reporting clean over zero bytes read.
- Verified against a candidate carrying the fix (`PRIVACY_SCRIPT=`): the case flips to XPASS
  and the runner fails the run until the marker goes, and the other 22 cases stay green, so
  the fix direction does not disturb the two no-ops that are legitimate.
- Plugin 1.3.1 -> **1.3.2**. `check_privacy.sh` itself is unchanged and stays **1.2.1**: the
  bump is the tests, which ship in the plugin directory like everything else.

### Migration

- **No recopy needed.** No shipped script changed in this release.

## [1.13.1] - 2026-08-03

### Security

#### privacy-guard plugin
- `check_privacy.sh` matched patterns against **`N:line`** instead of the line. `added_lines()`
  prefixes each added line with its real file number, and that text went straight to `grep`,
  so the prefix became part of the subject. Both directions were wrong, and the first is the
  one that matters: a pattern anchored with `^` could never match, because the line now
  started with a digit — the token stayed in the commit and the script exited 0. Specularly, a
  pattern that can begin with a digit or `:` fired on clean lines.
- The anchor is what someone writes to **narrow** a pattern (an absolute path, a slug in
  column one, the start of a URL). Doing the careful thing bought a pattern that protected
  nothing, with no signal at all. The whole-file form this replaced did not have the problem:
  it matched the bare line and added `file:line:` to the *output* afterwards, so this is a
  trap of the newer shape, like the `-` lines already noted in the header.
- The number is now kept out of grep's input (`cut -d: -f2-`) and stitched back by position
  (`grep -n` numbering the stream, `awk` returning the full lines). `grep -iE -f` is untouched,
  so case-insensitivity and the ERE dialect are exactly as before, and the `sed`/`head` below
  are unchanged.
- Four regression cases, including the two that make the bench honest: a **control** asserting
  the same token blocks when unanchored (without it, the failing case could be explained by a
  broken bench), and a line carrying its own colons (`https://host:8443/...`) reported whole
  rather than truncated at the first one. Against the 1.2.0 script the suite reports two
  failures.
- Reported from a review on a downstream PR that was syncing its copy, and reproduced here
  before being fixed. Script version 1.2.0 -> **1.2.1**, plugin 1.3.0 -> 1.3.1.

### Migration

- **Recopy `scripts/check_privacy.sh` again** in every repo that ships one: the copies pushed
  earlier today carry 1.2.0 and this defect.

## [1.13.0] - 2026-08-03

### Security

#### privacy-guard plugin
- `check_privacy.sh` **never scanned a line beginning with `++`**, so a denylisted token on
  such a line entered the repo with the guard reporting clean, exit 0. `added_lines()`
  recognised the unified-diff header by shape (`/^\+\+\+/`), and once the diff prepends its
  own `+`, a content line starting with `++` is byte-identical to that header: the rule
  dropped both. The defect was in the canonical template, not in a copy, and every version
  through 1.2.2 carried it.
- **Second consequence, quieter and missed by the review that found the first**: the skipped
  line did not advance the counter, so every later line in the same hunk was reported at the
  wrong number. A guard that points at the wrong line sends whoever reads it to look in the
  wrong place, which is the exact failure the line-number handling was added to prevent.
  Measured on a five-line file: two lines vanished and the rest were numbered 2 and 3 instead
  of 3 and 5.
- The fix excludes the preamble by **position** instead of by shape: everything before the
  first `@@` is header, and after it every `+` line is content, without exception. There is
  no longer a content line that can be mistaken for a header.
- Four regression cases, and the one that matters most is not the bypass: a commit that
  **removes** a token from a `++` line must still pass, because the token is leaving the
  repo. Without it, a fix that simply scanned everything would look correct and would wedge
  the one commit the guard must never block. Against the pre-fix script the suite reports
  three failures.
- Reported from a review on a downstream repo that was syncing its copy to the template, and
  reproduced independently before being fixed here.

### Changed

#### privacy-guard plugin
- The script's own version line goes 1.1.1 -> **1.2.0**: that number is the only way a
  materialized copy can know it is behind, and after this change every existing copy is.
  Plugin version 1.2.2 -> 1.3.0.

### Migration

- **Recopy `scripts/check_privacy.sh` in every repo that ships one.** Until then those repos
  run a guard with a known bypass. `references/check-sync.sh REPO...` names them: it now
  reports the three known copies as `BEHIND`.
- The guard now blocks commits it previously let through. That is the point, but a repo whose
  documentation legitimately contains `++`-prefixed lines carrying its own denylist tokens
  will notice on the next commit that adds one.

## [1.12.6] - 2026-08-03

### Changed

#### repo
- `CLAUDE.md` declares the one place this repo departs from the `git-commit` skill it ships:
  the 50-character subject cap, which that skill marks `NEVER`. Measured over the whole
  history: **58 of 64** subjects exceed it, median 70, longest 99. The long form is
  deliberate here — the subject states the defect rather than labelling the change, because
  `git log --oneline` is the first place anyone looks for a *why* — but it had never been
  written down, so `CLAUDE.md` pointed at a rule the repo disregards nine times out of ten.
  A rule in that state is not a rule; it teaches the next reader to skim the file it lives
  in. The skill is unchanged: 50 remains a sound default for the repos it ships to.

## [1.12.5] - 2026-08-03

### Fixed

#### privacy-guard plugin
- `tests/README.md` still described the pre-commit trigger as the two subdirectories named
  in it before 1.12.4 widened it to the whole plugin directory. Found by the sweep over
  1.12.4, one file outside the perimeter that release touched — which is where doc drift
  lives, by definition.

## [1.12.4] - 2026-08-03

### Fixed

#### repo
- A `marketplace.json` that does not parse made the entry check a **silent no-op**: the JSON
  error was swallowed, the entry map came back empty, and the run reported clean over zero
  entries. Measured: manifest truncated mid-array, entry at 9.9.9 against a `plugin.json` at
  1.0.0, exit 0. It is the same shape as the open malformed-denylist defect (#10) — a guard
  that cannot read its own input must stop, not guess — written into new code by someone who
  knew about that issue. It now blocks and names the manifest.
- The three answers that were collapsed into "empty" are now distinct: no manifest in the
  index (legitimate, silent), a manifest that does not parse (blocks), no `python3` (warns
  that half the check did not run). Two bench cases pin the first two.
- The bench asserted only exit codes, so a case could pass by blocking for the wrong reason —
  four different failures all exit 1. `check_because` now asserts the message too, on the
  three cases where the ambiguity is real.
- `.githooks/pre-commit` triggered a plugin's suite from a hand-written list of its
  subdirectories (`(hooks|tests)`, `(skills|tests)`). That is the exclusion-list trap the
  version-bump check's own comment warns about, sitting ten lines above it: the list covers
  what was thought of the day it was written, and a plugin that grows a directory silently
  stops running its suite. The trigger is now the whole plugin directory.

## [1.12.3] - 2026-08-03

### Fixed

#### repo
- `check-version-bump.sh` missed the marketplace-entry mismatch in the one case where it is
  most likely: a commit that edits **only** `.claude-plugin/marketplace.json`. The check
  looped over plugins with staged changes under `plugins/`, and that edit touches no plugin
  directory, so the loop body never ran. Measured on a throwaway repo: entry at 9.9.9,
  `plugin.json` at 1.0.0, exit 0. Editing the entry by hand is exactly how someone "fixes" a
  version, so the guard was blind to its own most probable input.
- The set of entries verified is now: the plugins with staged changes, or **all** of them
  when `marketplace.json` itself is staged. A repo-level commit that touches neither is
  still not punished for drift it did not cause.
- The `python3`-absent branch had no case, so nothing proved it warns instead of passing.
  It has one now, run with a `PATH` that deliberately excludes `python3`. An untested
  fallback is indistinguishable from a fallback that silently returns "clean".
- `.githooks/pre-commit` no longer invokes the check unguarded: a missing script produced a
  `No such file` and a blocked commit rather than a stated reason. It now says the check did
  not run, the same shape the suite runner already used.
- `CLAUDE.md` described the bench as it stood before 1.12.1, listing neither the
  marketplace-entry cases nor the `python3` one — the same doc drift this session opened by
  fixing, reintroduced two releases later.

## [1.12.2] - 2026-08-03

### Fixed

#### repo
- `README.md` now states the version-bump rule. The check landed in 1.12.0 and the only
  place explaining it was `CLAUDE.md`, which is contributor guidance for agents; a person
  editing a plugin would have met a blocked commit citing a rule they had never read. A
  guard whose reason is undocumented gets bypassed with `--no-verify`, which is how a guard
  stops guarding while staying installed.

## [1.12.1] - 2026-08-03

### Fixed

#### repo
- `check-version-bump.sh` also verifies that a plugin's `marketplace.json` entry advertises
  the version its `plugin.json` declares. Found by the sweep over 1.12.0, in that release's
  own diff: adding `version` to every entry created a copy kept by hand, and the only thing
  guarding it was `claude plugin tag`, which fires when someone tags. Between two tags the
  pair could drift freely — the same shape as the defect 1.12.0 removed, reintroduced one
  step to the side.
- The entry is what the plugin browser reads **before** anything is fetched, so a stale one
  misinforms precisely the reader who has no way to check. An entry carrying no `version`
  stays legitimate and is not flagged; three cases pin that boundary.
- The lookup needs `python3`. When it is absent the check **says** the marketplace-entry
  half did not run instead of exiting clean, because a check that evaporates in silence
  reads as a pass.

## [1.12.0] - 2026-08-03

### Added

#### repo
- `.githooks/check-version-bump.sh` blocks a commit that changes what a plugin ships
  without moving that plugin's version. Without the bump the change never reaches an
  installed copy: `claude plugin update` compares the number, sees none, and does not
  fetch — so the node keeps running the old files while the version claims otherwise. It
  is the `DIVERGED` case `check-sync.sh` was written to catch for the materialized copies
  of `check_privacy.sh`, one level up, where nothing was watching.
- It happened **twice** and neither time did anyone notice. `guardrails`: four commits to
  `guard-destructive.sh` after the bump to 1.7.4. `privacy-guard`: `SKILL.md` rewritten
  after the bump to 1.2.0, leaving two different contents both called 1.2.0 — measured 12
  lines apart between this repo and the installed cache on a node.
- The rule is "any staged change under `plugins/<name>/` bumps that plugin", not a list of
  which subdirectories count. Everything in that directory is shipped, tests included
  (verified against a real plugin cache), and a hand-kept list of exceptions is wrong the
  day someone adds a directory nobody thought of.
- `.githooks/tests/run.sh` benches it, with a `BUMP_SCRIPT=` override. Seven cases: the two
  real misses, and the edges that must not block (a repo-level file, a plugin being added,
  a plugin being removed). Against a candidate that always exits 0 it reports two failures.

### Changed

#### repo
- Every `marketplace.json` plugin entry now carries its `version`, matching its
  `plugin.json`. This is what makes `claude plugin tag` a real gate: it refuses to tag when
  the two disagree, and until now there was nothing for it to compare. The entry is not a
  redundant copy — the plugin browser renders a version **only** when the entry carries
  one, and at that point no `plugin.json` has been fetched.
- `metadata.version` 1.8.0 -> 1.12.0, following the changelog heading. It had drifted three
  minor versions behind while nothing broke, which is exactly why it drifted.
- `CLAUDE.md` gains a *Versioning and release* section: which of the three numbers answers
  which question, who reads each, and the release commands. The two points that were only
  ever implicit are now written down, which is the point — what is not written there is
  what stops being done.

#### guardrails plugin
- Version 1.7.4 -> 1.7.5. No behaviour change: the bump the four post-1.7.4 fixes to
  `guard-destructive.sh` and today's tests README never got.

#### privacy-guard plugin
- Version 1.2.0 -> 1.2.1. No behaviour change: the bump the `SKILL.md` rewrite of `b9bff66`
  never got. Nodes on 1.2.0 could not receive it, since the number had not moved.

## [1.11.1] - 2026-08-03

### Fixed

#### repo
- `README.md` still described a single regression suite and a pre-commit tied to
  `guardrails`. `CLAUDE.md` had been corrected in 1.11.0 and the README had not, so the
  file an external contributor reads first was the one still wrong. It now names both
  suites, the candidate overrides that make them provable, and states out loud that there
  is no CI.
- The privacy-guard section claimed the gate greps **staged files**. True until 1.9.0,
  false since: it greps the lines a commit adds. The same row also omitted `check-sync.sh`
  and the `core.hooksPath` variant, both shipped, so the README undersold the plugin while
  misdescribing it.
- The architecture tree in `CLAUDE.md` annotated `tests/` as belonging to `guardrails` and
  listed `cases/*.txt` as if every suite used that format. Two plugins have a suite and
  only one uses a case table.
- The "Suites" table in `plugins/guardrails/tests/README.md` listed 4 case files out of 10.
  Six suites added between 1.7.0 and 1.7.4 were never documented there, so the file that
  explains what the hook is tested for understated the coverage by more than half.

## [1.11.0] - 2026-08-03

### Added

#### repo
- `plugins/privacy-guard/tests/` — regression suite for `check_privacy.sh` and
  `check-sync.sh`, in the shape the guardrails plugin already used in this repo. It was the
  only plugin whose scripts had no tests, and it is the one that changed three times in a
  day, each time on a defect that a case would have caught. Provable rather than
  decorative: `PRIVACY_SCRIPT=` points it at a candidate, and against the pre-1.9.0 script
  it reports four failures, one per defect fixed there.
- One case is marked **XFAIL** and reports without failing the run: a malformed regex in the
  denylist makes `grep` exit 2 and a real leak passes with exit 0 (the open defect). Deleting
  it would lose the only executable record of that defect; letting it fail would leave a
  permanently red suite, which is a suite people stop reading. When the defect is fixed the
  runner prints `XPASS` and fails until the marker is dropped, so a fix cannot land while the
  suite still calls it broken.

### Changed

#### repo
- `.githooks/pre-commit` runs a suite **per plugin** instead of one inlined block. The old
  shape ended in `exit 0` when guardrails files were not staged, so any suite added after it
  would never have run: the next one would have been installed and silently dead. Adding a
  plugin's suite is now one line.
- Its header no longer claims the privacy check reads the working tree rather than the staged
  blobs. True until 1.9.0, false since: the script reads `git diff --cached`, so the
  framework's stash step changes nothing, and a token living only in an unstaged edit is no
  longer reported.

## [1.10.0] - 2026-08-03

### Added

#### privacy-guard plugin
- `references/check-sync.sh REPO...` reports whether a repo's materialized copies of
  `check_privacy.sh` are current with this skill. Copying is deliberate (the repo has to work
  for contributors who do not have the plugin), and the price of copying is drift that nobody
  can see: a copy a month behind is indistinguishable from a current one. The version line
  added in 1.1.1 gives the comparison something to hold on to; this gives it a command.
- Copies are asked to **git** (`ls-files`), not to the filesystem and not to a hardcoded
  `scripts/` path: the question is "what does this repo ship", and asking git answers it
  wherever the copy lives. The hand-written list of repos that were believed to hold a copy
  had already missed one.
- Four verdicts, and `DIVERGED` (same version, different content) is the one worth having:
  the version claims to be current while the content is not, so the change must go upstream
  or the next sync reverts it in silence. `NONE` is reported rather than passed over, because
  silence would read as "current".

## [1.9.1] - 2026-08-03

### Fixed

#### privacy-guard plugin
- `check_privacy.sh` called with **no arguments** exited 0 in silence: a "clean" verdict over
  zero files checked, which is the one thing the script's own comment says it must never
  fake. It now prints a usage line and exits 2, and the exit codes are documented in the
  header. The guard is placed before the "no denylist, no-op" early exit, so a repo without a
  denylist still reports the usage error instead of swallowing it. The check came from a
  materialized copy that had grown it locally: it is upstream now, so that copy stops being a
  variant.

### Added

#### privacy-guard plugin
- `check_privacy.sh` carries its **version and provenance** in the header. A materialized copy
  had been a month behind with no way for anyone to notice, because nothing in the file said
  where it came from or which version it was. The line also states the rule that keeps copies
  from drifting: fix upstream and recopy, never edit the copy.

## [1.9.0] - 2026-08-03

### Changed

#### privacy-guard plugin
- `check_privacy.sh` scans the lines a commit **adds** (`git diff --cached -U0`, `+` lines
  only) instead of the whole staged file. Scanning whole files does not stop new leaks, it
  stops maintenance: a repo whose documentation legitimately names the tokens its own
  denylist protects becomes unmodifiable, and the only exit the message offers is
  `--no-verify`, which is how a guard stops guarding while staying installed. Measured on a
  private repo where an unrelated paragraph added to a docs file failed the commit citing
  four lines that had been committed for weeks. The two sibling guards in this ecosystem
  already scanned added lines only; this was the one left behind.
- Matches now carry the **real** line number in the file. `grep -n` over a diff numbers the
  lines of the diff, not of the file, so the fix reads them from the hunk headers: a guard
  whose output points at the wrong line sends whoever reads it to look in the wrong place.
- The "nothing was checked" warning now covers being run by hand outside a commit, where
  there is nothing staged to look at. Worth knowing because it is the natural way to verify
  this script and get a meaningless pass: run from a directory where the denylist does not
  resolve, the check is a no-op that answers "clean".

### Migration

- If you materialized `scripts/check_privacy.sh` into a repo, recopy it from
  `plugins/privacy-guard/skills/privacy-guard/references/`. Without that, nothing breaks
  today, but that repo keeps the whole-file behaviour and will wedge on the first file that
  carries one of its own tokens.
- One behaviour is genuinely narrower: a token living only in an **unstaged** edit is no
  longer reported. It is not being committed, and under the pre-commit framework the stash
  step made this moot anyway, but repos on the `core.hooksPath` variant were getting that
  extra reach for free and now are not.

## [1.8.1] - 2026-07-28

### Added

#### repo
- `.githooks/pre-commit` now runs the privacy denylist check on the staged files before the guardrails suite, so this repo is covered by the guard it ships. The check is a no-op without `.local/privacy-denylist.txt`, which is the case for every external contributor. The canonical script lives here already, with the privacy-guard skill, so the hook calls it in place instead of duplicating it into `scripts/`.

### Security

#### guardrails plugin
- Test fixtures no longer carry a real local username or a real internal instance name; both were replaced with neutral placeholders (`deploy`, `myapp`) across four case files. In those cases the string is an arbitrary operand (an argument to `su`/`runuser`, a path under `/srv`), so no verdict changes and the suite stays at 179 PASS. They surfaced by running this repo's own privacy guard over its tracked files, which is the point of shipping one. Git history still holds them: for a username and a dev instance name, that is a deliberate trade against rewriting a public repo's history and breaking every existing clone.

### Changed

#### privacy-guard plugin
- `check_privacy.sh` warns on stderr when it is handed arguments but none of them resolves to a readable file, instead of exiting 0 in silence. That silence is indistinguishable from a clean run, and it misled the author of this very changelog entry: an unquoted variable under zsh (which does not word-split variable expansions) arrives as one long argument, matching no file, and the script reported nothing. Behavior under pre-commit, where filenames arrive correctly, is unchanged.
- The skill's setup gains the case this repo actually hit: when the target repo sets `core.hooksPath`, `pre-commit install` refuses to run by design (pre-commit 4.6.0, `install_uninstall.py:125`, "Cowardly refusing to install hooks with `core.hooksPath` set"). Unsetting it to make room for the framework would disable the hooks the repo relies on, so the documented answer is to call `check_privacy.sh` from the existing hook over the staged list, run gitleaks in CI instead of per commit, and accept that without the framework's stash step the check reads the working tree rather than the staged blobs. The snippet keeps `|| exit 1`: swallowing the exit code leaves a guard that reports and lets the commit through anyway.

## [1.8.0] - 2026-07-27

### Added

#### privacy-guard plugin (new)
- New plugin with the `privacy-guard` skill: keeps private infrastructure details (node hostnames, internal project names, local usernames and personal emails, absolute home paths, private and VPN IP ranges) out of public repositories. It has two legs: behavioral rules for the session (the repo is the boundary, and the user naming an internal host in conversation does not authorize writing it into the repo) and a per-repo technical gate.
- The gate is `references/check_privacy.sh`, a pre-commit script that greps staged files against `.local/privacy-denylist.txt` (one case-insensitive extended-regex pattern per line) and blocks the commit on a match, printing the offending lines. The denylist stays gitignored, because publishing it would reveal the very tokens it protects: the hook is therefore a deliberate no-op for external contributors and in CI, where gitleaks still covers generic secrets. `references/pre-commit-snippet.yaml` wires both hooks up.
- `references/denylist-template.txt` is a placeholder-only starting point; every line ships commented out, so a copy that was never filled in matches nothing. The skill's setup ends with an explicit arming check for exactly that reason.

## [1.7.4] - 2026-06-20

### Changed

#### guardrails plugin
- rm/rmdir scope: a directory-anchored glob whose literal prefix resolves inside an allowed root (e.g. `rm -f /tmp/probe*.py`, or a path under `$GUARD_ALLOWED_EXTRA`) now runs silently. A glob metacharacter never matches `/` and `..` is rejected first, so every match is confined under that literal prefix; the verdict is now deterministic instead of depending on whether the glob happens to match files on the host running the hook. A bare glob with no directory part (`*.o`) has no anchor and still prompts, and a glob anchored outside every allowed root still prompts.

### Fixed

#### guardrails plugin
- rm/rmdir operand enumeration no longer performs local pathname expansion (`set -f`). Previously a glob operand was expanded against the local filesystem, which was non-deterministic and a hazard: `rm -rf /*` expanded to the entire tree and `find`-counted each entry, hanging the hook. Globs are now judged by their literal prefix (see above) without touching the filesystem.
- Shell redirections on the rm/rmdir line (`2>/dev/null`, `> file`, `2>&1`) are no longer mistaken for rm operands. This removes a false confirmation when a redirection target resolved outside the workspace (e.g. `rm -f /tmp/x > /var/log/out` treated `/var/log/out` as a deletion target).
- A project root or `$GUARD_ALLOWED_EXTRA` entry with a trailing slash (e.g. `/srv/scratch/`) is now matched correctly; the trailing slash previously produced a `//` in the match pattern so in-scope deletions under that root prompted. (From code review.)
- The special-variable substitution resolves `$PPID`/`$BASHPID`/`$RANDOM` before `$$`/`$!`, so an adjacency like `/tmp/x_$PPID$$.log` now fully resolves instead of leaving a stray `$` that prompted. (Two adjacent *named* vars remain a rare residual; `\b` is intentionally not used as it is unsupported by BSD/macOS sed.) (From code review.)
- `renorm` starts from the un-normalized command, so an already-stable command (no nested interpreters, the common case) costs a single `transform` pass instead of two; also uses a regular loop variable instead of the special `_`. (From code review.)

## [1.7.3] - 2026-06-19

### Fixed

#### guardrails plugin
- `guard-destructive` now normalizes each command to a fixpoint, closing a detection bypass for a destructive command nested inside a SECOND interpreter layer. A single pass exposed only the outermost interpreter argument (e.g. the `'...'` of `ssh host '...'`), leaving an inner `bash -lc "rm ..."` quoted verbatim; a destructive command that was the first token inside that inner quote escaped detection entirely, including a hard-block bypass where `ssh host 'bash -lc "rm -rf /"'` ran silently. The normalization is re-applied until stable, peeling one interpreter layer per pass (an inner command is exposed when its wrapper is an interpreter, neutralized when it is data such as `echo "..."`). A chained inner command (`...; rm ...`) was already detected and still is.
- Known residual limit (unchanged): a backslash-escaped inner quote (e.g. `\"rm -rf /\"` at a third nesting level) is not unescaped and can still evade detection, the same class as the documented `\$`/backslash escaping limits.

## [1.7.2] - 2026-06-17

### Changed

#### guardrails plugin
- `guard-destructive` `rm`/`rmdir` scope check now resolves the integer-only special shell variables `$$`, `$!`, `$PPID`, `$BASHPID` and `$RANDOM` (to a digit) before the in-scope check. They expand to a bare number that cannot contain `/` or `..`, so they never move a path out of its literal parent; an otherwise in-scope deletion such as `rm -f /tmp/suite_$$.log` (the common test-harness temp-file idiom) now runs silently instead of prompting on the unresolvable `$$`.
- Conservative by design: only these five special vars are resolved, matched on a word boundary (`$RANDOMX` and `${MYPID}` are unaffected). Every other `$VAR` stays unresolvable and prompts as before, the `..` traversal reject still runs first, a special var that resolves outside the workspace still prompts, and catastrophic `rm -rf /` still hard-blocks.

## [1.7.1] - 2026-06-15

### Fixed

#### guardrails plugin
- `guard-destructive`: a `$`-operand whose extracted name is not a bare identifier (`$A.B`, `$A*`, `$A.*B`) is `$VAR` plus extra characters, not a variable by that name; it is no longer fed (unescaped) to the variable name matchers and instead falls through to the glob/var reject so it prompts. Closes a false negative from the 1.7.0 static-literal resolution where a decoy assignment (e.g. `AXB=/tmp/x`) could make `rm -rf "$A.B"` resolve to an in-workspace path and run silently; also hardens the pre-existing mktemp-variable match against the same class.

## [1.7.0] - 2026-06-15

### Changed

#### guardrails plugin
- `guard-destructive` `rm`/`rmdir` scope check now resolves a variable assigned a **static literal** path in the same command (`ROOT=/tmp/x; rm -rf "$ROOT"`): the value is known exactly, so it runs silently when it resolves inside the workspace, exactly as the inline literal would. Conservative like the mktemp path (single assignment, pure-literal RHS with no `$`/substitution/glob/`~`/`..`, name not rebound as a bareword); a reassigned, loop/read-rebound or `$`-substituted variable still prompts.

### Fixed

#### guardrails plugin
- `guard-destructive` operand scan no longer reads the `rm` inside a flag like `docker run --rm` as the `rm` command (the verb is anchored as a word), removing a false confirmation on `docker run --rm -v host:container image ...` whose only deletion is in-scope.
- `guard-destructive` now checks every `rm`/`rmdir` on the command line, not just the first one: a chained `rm -rf /tmp/a && rm -rf /etc` (a false negative that previously ran silently) now prompts.

## [1.6.5] - 2026-06-13

### Changed

#### github-workflow plugin
- `github-pr-merge` gained a pre-merge changelog-completeness check: it lists the commits the merge will publish (`base..head`) and verifies every behavior-changing one is reflected in the CHANGELOG, stopping if any are unlogged. Guards release-promotion merges (`develop` → `main`) against leaving commits out of the changelog.

## [1.6.4] - 2026-06-13

### Added

#### guardrails plugin
- Regression test suite for the `guard-destructive` hook at `plugins/guardrails/tests/` (`run.sh` + `cases/*.txt`), runnable with `bash plugins/guardrails/tests/run.sh`; exits non-zero on failure and runs on macOS and Linux.
- Pre-commit hook (`.githooks/pre-commit`) that runs the suite automatically when the hook or its tests are staged, enabled per clone with `git config core.hooksPath .githooks`.
- README and CLAUDE.md documentation for the test suite and the git-hooks bootstrap.

### Changed

#### github-workflow plugin
- `github-pr-merge` is now merge-direction aware for branch deletion. It deletes the head branch (`--delete-branch`) only for a topic branch (`feature`/`fix`/etc.) merging into `develop`; on a `develop` → `main` merge it omits the flag and never proposes deleting `develop`. Previously the skill always passed `--delete-branch`, which would have deleted the long-lived `develop` branch when promoting it to `main`.
- `github-pr-merge` post-merge cleanup now syncs the PR base branch (`develop` or `main`) instead of always checking out `develop`.

## [1.6.3] - 2026-06-13

### Fixed

#### guardrails plugin
Closed two false negatives in the 1.6.2 mktemp-variable recognition, found by adversarial review (a deletion that should prompt could run silently):
- A mktemp-backed variable rebound by a loop or read (`D=$(mktemp -d); for D in /etc; do rm -rf "$D"; done`, or `read D < ...`) is no longer trusted: a variable referenced anywhere as a bareword (any rebinding form, not `$VAR` and not `NAME=`) is dropped from the temp set.
- Path traversal out of a temp variable (`rm -rf "$D/../../etc"`) now prompts: the `..` reject runs before the temp-variable allow.

## [1.6.2] - 2026-06-13

### Changed

#### guardrails plugin
- rm/rmdir scope: a variable provably assigned from a bare `mktemp` / `mktemp -d` earlier in the SAME command (the "create temp workspace ... `rm -rf` it" idiom, common in test harnesses) now counts as a temp path, so the cleanup runs silently instead of prompting on the unresolvable `$VAR`. Covers `$VAR`, `${VAR}` and `$VAR/sub`.
- Conservative by design: only a bare mktemp qualifies (flags `-d`/`-q`/`-u`, no positional template, no `-p`), only single-assignment names (a reassigned variable still prompts), and the assignment must be outside any heredoc body. Every other variable stays unresolvable and prompts as before; catastrophic `rm -rf /` still hard-blocks even when a temp var is present.

## [1.6.1] - 2026-06-12

### Fixed

#### guardrails plugin
Closed false-negative gaps found by an adversarial review of 1.6.0 (commands that should block or prompt but passed silently):
- A `<<` sitting inside an open quote (e.g. `echo "a<<b"`) was mistaken for a heredoc and swallowed the following lines; heredoc detection is now quote-balance aware.
- Interpreter coverage extended to `su`, `doas`, `runuser`, and `-c` after a `$VAR` interpreter (`$SHELL -c '...'`), so `su -c 'rm -rf /'` and friends are caught.
- Backslash-escaped catastrophic targets (`rm -rf \/`, `rm -rf \~`) now hard-block; operands containing a backslash or a `{}` placeholder (`find ... -exec rm -rf {} \;`) are treated as outside the workspace and prompt.
- A shallow project root (`/`, `$HOME`, or a single-segment dir like `/Users` or `/mnt`) is no longer trusted as a blanket allow.

Known residual limits (rare, documented): non-shell `-c` interpreters (`python -c`, `perl -e`) and command substitution inside double quotes are not inspected.

## [1.6.0] - 2026-06-12

### Changed

#### guardrails plugin
- `guard-destructive` now matches against a NORMALIZED view of the command instead of the raw string, fixing false positives where a command merely *mentions* a destructive pattern (a heredoc body, a commit message, an `echo` / `grep` argument, a comment). Normalization strips heredoc bodies and comments (quote-aware), and neutralizes quoted strings except those that are the argument of an interpreter (`ssh`, `sh -c` / `bash -c` / `zsh -c`, `eval`), whose content stays exposed because it is a real command.
- The catastrophic hard-block tier (`rm -rf /` / `~` / `$HOME`, `rsync --delete`, `docker rm -v` / `docker volume rm`) and the scope-aware `rm` / `rmdir` tier both use this normalization. So a commit message that contains `rsync --delete` no longer hard-blocks, while `ssh host 'rsync -a --delete ...'` and `sh -c "rm -rf /"` still do.

### Notes
- Known limits, both rare: a command substitution inside double quotes is neutralized (a destructive command placed there would be missed, but these patterns are never used for output capture); a destructive command nested inside an interpreter-quoted `echo` can still trip the catastrophic tier (errs toward prompting).

## [1.5.0] - 2026-06-12

### Changed

#### guardrails plugin
- `guard-destructive` hook: `rm` / `rmdir` are now **scope-aware** instead of prompting on every invocation. An operation whose operands all resolve strictly inside the allowed workspace runs silently; only an operation touching a path outside it raises a confirmation. The allowed workspace is the Claude session project root (`$CLAUDE_PROJECT_DIR`, else the cwd; ignored when it is `/` or `$HOME`), the temp dirs, and any colon-separated roots in `$GUARD_ALLOWED_EXTRA` (per-node scratch, e.g. `/srv/scratch`).
- Operands the hook cannot resolve before execution (globs like `*.o`, variables like `$BUILD`, `~` paths, `..` traversal) are treated as outside the workspace and prompt (fail-safe).
- The out-of-scope prompt now carries a reflective question (is this deletion part of the expected process? could it destroy pre-existing user data outside the work area? re-verify the targets and parameters) instead of a generic re-verify notice.
- Unchanged: catastrophic hard-blocks (`rm -rf /` / `~` / `$HOME`, `rsync --delete`, `docker rm -v` / `docker volume rm`) and the always-prompt set (`git reset --hard` / `clean` / `restore`, `shred`, `truncate`, `mkfs`, `dd`).

## [1.4.0] - 2026-05-17

### Changed

- Restructured the repository to the standard Claude Code plugin layout: every plugin is now a self-contained directory under `plugins/` (`plugins/github-workflow`, `plugins/skill-authoring`, `plugins/guardrails`), each with its own `.claude-plugin/plugin.json`. Marketplace entries reference plugins via `source` only; components are auto-discovered from each plugin directory.

### Fixed

- Skill duplication: `github-workflow` and `skill-authoring` previously shared `source: "./"` (the repo root), so each auto-discovered every directory under `skills/` on top of its explicit `skills` array - `github-workflow` resolved to 9 skills (its 4 doubled, plus `creating-skills`). With per-plugin directories each plugin now resolves only its own skills.

## [1.3.0] - 2026-05-17

### Added

#### guardrails plugin (new)
- New plugin for running Claude Code with reduced supervision, shipping the `guard-destructive` `PreToolUse` hook for the Bash tool
- Hard-blocks catastrophic commands: `rm -rf /` (and `~` / `$HOME`), `rsync --delete`, `docker rm -v` / `docker volume rm`
- Prompts for confirmation on other destructive operations: `rm` (with resolved-operand enumeration), `rmdir`, `git reset --hard` / `clean -f` / `checkout --` / `restore`, `shred` / `truncate` / `mkfs`, `dd`
- Exempts `rm` whose operands all resolve strictly under a temp directory (`/tmp`, `/private/tmp`, `/var/tmp`, `/var/folders`); a bare `/tmp` or any path containing `..` is never exempt
- Catches destructive commands wrapped in `ssh '...'` / `sh -c "..."`

## [1.2.1] - 2026-03-23

### Fixed

#### github-pr-review
- Added fallback to `pulls/$PR/reviews/$REVIEW_ID/comments` endpoint when review-attached inline comments are not surfaced by the general `pulls/$PR/comments` endpoint (cross-checks "Actionable comments posted: N" count)
- Added missing CodeRabbit type indicators to severity table (`_🚨 Critical_`, `_⚡ Performance_`)
- Documented secondary color badge override rule (e.g., `_💡 Suggestion_ | _🟠 Major_` binds to HIGH, not MEDIUM)
- Added reference to CodeRabbit global "Prompt for all review comments with AI agents" block for cross-comment context
- Added `?per_page=100` to all fetch API calls to handle PRs with many comments

## [1.2.0] - 2026-02-20

### Changed

#### github-pr-review
- Added CodeRabbit severity detection to `references/severity_guide.md`: emoji+italic pattern (`_⚠️ Potential issue_`, `_🧹 Nitpick_`, `_🔧 Optional_`, etc.), secondary color badges (`_🟡 Minor_`, `_🟠 Major_`) as binding severity indicator
- Documented CodeRabbit "outside diff" comments pattern: embedded in PR-level review body `<details>` blocks, not in `pulls/$PR/comments`
- Step 1: added `pulls/$PR/reviews` fetch alongside `pulls/$PR/comments` to capture outside diff comments
- Step 1: replaced raw fetch commands with inline `--jq` filters to avoid `!=` operator, which Claude Code's Bash tool escapes as `\!=` breaking jq
- Updated severity table in step 1 with CodeRabbit indicators
- Current PR context now includes milestone: `PR #N: title (state) | Milestone: name`
- Added step 7: verify milestone at end of review; suggest assigning if missing and open milestones exist (never assigns automatically)

#### github-pr-creation
- Added `.s2s/plans/*.md` to task documentation search paths (Spec2Ship projects)
- Added `chore/*`, `ci/*`, `docs/*` branch patterns to title prefix table
- Added breaking change handling: add `breaking` label + `## Breaking changes` body section
- Added step 9: detect open milestones and assign if exactly one is active; ask user if multiple exist
- Updated `gh pr create` command with `--milestone`, `--reviewer`, correct multi-`--label` syntax
- Added `--draft` usage note (WIP, CI wait, AI bot trigger)

#### github-pr-merge
- Added step 2: check PR milestone before merge; warn (not block) if open milestones exist but PR has none
- Added milestone line to pre-merge checklist summary (step 4)
- Added step 7: after merge, check `open_issues` on milestone; offer to close it if all items are done
- Renumbered steps: old 2→3, 3→4, 4→5, 5→6; new steps are 2 and 7

## [1.1.0] - 2026-02-07

### Added

- **CLAUDE.md**: project-level instructions for contributors
- **.gitignore**: exclude local settings from version control
- **README.md**: "Why these skills?" section with value propositions and Without/With comparison tables for each skill

### Changed

#### git-commit
- Streamlined SKILL.md from 236 to 54 lines (-77%)
- Added dynamic context injection (`!`git log``) to match existing project commit style
- Removed content Claude already knows (CC types, subject rules, git basics, trailers, breaking changes)
- Removed merge commits section (belongs to github-pr-creation)
- Moved good/bad examples to `references/commit_examples.md`

#### github-pr-creation
- Streamlined SKILL.md from 202 to 138 lines (-32%)
- Added dynamic context injection for current branch and unpushed commits
- Expanded task documentation search with paths for Kiro, Cursor, Trae, GitHub Issues
- Reworked label suggestion to check available project labels first via `gh label list`
- Trimmed `references/pr_templates.md` from 461 to 188 lines (templates only)
- Removed `references/conventional_commits.md` (duplicated standard CC knowledge)

#### github-pr-merge
- Streamlined SKILL.md from 211 to 113 lines (-46%)
- Added dynamic context injection for current PR info
- Simplified unreplied comments check to single jq command
- Removed redundant sections (Quick Start, Pre-Merge Checklist table, Error Handling)

#### github-pr-review
- Streamlined SKILL.md from 236 to 111 lines (-53%)
- Added dynamic context injection for current PR info
- Integrated reply API gotcha (`--input -` vs `-f`) into workflow step
- Renamed `references/gemini_severity_guide.md` to `references/severity_guide.md`
- Added Cursor comment severity detection to severity guide

#### creating-skills
- Streamlined SKILL.md from 262 to 159 lines (-39%)
- Added complete frontmatter reference (10 fields including `allowed-tools`, `context`, `agent`, `hooks`)
- Added invocation control matrix, dynamic features (context injection, string substitutions, subagent execution)
- Added degrees of freedom concept and `assets/` resource type
- Rewrote `references/official_best_practices.md` with context budget, frontmatter validation, discovery hierarchy, skills/commands unification
- Rewrote `references/skill_examples.md` with 6 concrete examples of new features

## [1.0.0] - 2025-12-21

### Added

- Initial release with 5 skills organized in 2 plugins

#### github-workflow plugin
- **git-commit**: Conventional Commits format with type/scope/subject
- **github-pr-creation**: PR creation with validation and task tracking
- **github-pr-merge**: Pre-merge checklist validation
- **github-pr-review**: PR review comment resolution with severity classification

#### skill-authoring plugin
- **creating-skills**: Guide for creating Claude Code skills
