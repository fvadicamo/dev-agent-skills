# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
- `guard-destructive` hook: `rm` / `rmdir` are now **scope-aware** instead of prompting on every invocation. An operation whose operands all resolve strictly inside the allowed workspace runs silently; only an operation touching a path outside it raises a confirmation. The allowed workspace is the Claude session project root (`$CLAUDE_PROJECT_DIR`, else the cwd; ignored when it is `/` or `$HOME`), the temp dirs, and any colon-separated roots in `$GUARD_ALLOWED_EXTRA` (per-node scratch, e.g. `/mnt/scratch`).
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
