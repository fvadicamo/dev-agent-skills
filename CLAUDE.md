# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A collection of Claude Code agent skills and hooks for development workflows, distributed as a plugin marketplace. Contains 6 skills and 1 hook organized into 4 plugins:

- **github-workflow** plugin: `git-commit`, `github-pr-creation`, `github-pr-merge`, `github-pr-review`
- **skill-authoring** plugin: `creating-skills`
- **guardrails** plugin: `guard-destructive` PreToolUse hook
- **privacy-guard** plugin: `privacy-guard` skill (session rules + pre-commit denylist gate for public repos)

Skills are model-invoked (Claude activates them based on user intent, not slash commands). The hook runs automatically on every Bash tool call.

## Architecture

```
.claude-plugin/
  marketplace.json          # Marketplace registry: lists all plugins
plugins/
  <plugin-name>/
    .claude-plugin/
      plugin.json           # Plugin manifest
    skills/                 # Skills (skill plugins) - auto-discovered
      <skill-name>/
        SKILL.md            # Main skill file (YAML frontmatter + markdown body)
        references/         # Optional deep-dive docs loaded on demand
    hooks/                  # Hooks (guardrails plugin) - auto-discovered
      hooks.json            # Hook registration
      guard-destructive.sh  # Hook script, run via ${CLAUDE_PLUGIN_ROOT}
    tests/                  # regression suite - guardrails and privacy-guard have one
      run.sh                #   guardrails: cases/*.txt table; privacy-guard: inline
      cases/*.txt           #   (guardrails only)
```

### Key file: `marketplace.json`

Lists the plugins. Each plugin is a self-contained directory under `plugins/`, referenced only by `source` (e.g. `./plugins/github-workflow`); its components are auto-discovered from that directory. The marketplace entry carries no `skills`/`hooks` arrays - this is the standard Claude Code plugin layout. To add a plugin, create `plugins/<name>/` with a `.claude-plugin/plugin.json` and its components, then add an entry here.

### Skill anatomy

Every skill requires a `SKILL.md` with:
1. **YAML frontmatter** (`name` + `description`) - the description is critical for discovery, it determines when Claude activates the skill
2. **Markdown body** - workflow instructions, kept under 500 lines

Reference files in `references/` provide extended examples and documentation that Claude loads only when needed (progressive disclosure).

## Conventions

- **Commits**: Conventional Commits format - `type(scope): subject` (see `plugins/github-workflow/skills/git-commit/SKILL.md`), with **one declared exception**: the subject is not capped at 50 characters here. That skill marks the cap `NEVER` and it is a sound default for the repos it ships to; in this repo the subject states the defect ("il README descriveva una suite sola e un gate che grep-pava i file interi") rather than labelling the change, because `git log --oneline` is the first place anyone looks for a *why*. Measured 2026-08-03: 58 of 64 subjects exceed 50, median 70, longest 99. Keep them under ~100 and let the body carry the rest. The exception is written here because a rule disregarded 90% of the time is not a rule, it teaches the next reader to skim the file it lives in.
- **Naming**: lowercase, hyphens between words, no spaces (e.g., `github-pr-review`)
- **Merge strategy**: always merge commits (`--merge`), never squash/rebase
- **Changelog**: follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format
- **Versioning**: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

## Versioning and release

Three numbers, and they answer different questions. Keeping that straight is what
went wrong twice: a shipped file changed under a frozen number, and nobody saw it.

| Number | Question it answers | Who reads it |
|---|---|---|
| `plugins/<name>/.claude-plugin/plugin.json` `version` | which build of this plugin is installed | `claude plugin update`, the cache dir `<plugin>/<version>/` |
| the same number in that plugin's `marketplace.json` entry | which version this marketplace advertises | the plugin browser UI, before anything is fetched |
| `marketplace.json` `metadata.version` | which release of **this repo** you are on | `CHANGELOG.md`, the `v*` tag, the GitHub release |

**The rule that got missed**: any change to a file under `plugins/<name>/` bumps
that plugin's version. *Everything* in that directory is shipped, tests included:
the installed copy is the whole directory. Without a bump, `claude plugin update`
compares the number, sees no change, and never fetches the new content — the node
runs the old files under the new name and nothing says so.

`.githooks/check-version-bump.sh` enforces it at commit time, because the rule
existed in spirit and was disregarded twice anyway. Its bench is
`.githooks/tests/run.sh`, with a `BUMP_SCRIPT=` override.

The plugin entry's `version` must match its `plugin.json`; `claude plugin tag`
refuses to tag when they disagree, and says `plugin.json wins at install time`.
The entry is not redundant: the browser UI renders a version only when the entry
carries one, and at that point no `plugin.json` has been fetched. The same
pre-commit check enforces the pair, because the tag gate only fires when someone
tags, and the entry is a copy kept by hand — the one thing this repo does not
leave to attention. An entry with no `version` at all stays legitimate.

`metadata.version` follows the `CHANGELOG.md` heading, always.

**At every change**: bump what moved, add the changelog entry, then tag. Per-plugin
tags come from the tool, the repo tag is created by hand and carries the release:

```sh
claude plugin tag ./plugins/<name> --push     # <name>--v<version>, validates the pair
git tag -a v<X.Y.Z> -m "v<X.Y.Z>" && git push origin v<X.Y.Z>
gh release create v<X.Y.Z> --notes-from-tag
```

Releases are not how code reaches a node — see *Distribution is not automatic* —
but they are the only moment anyone decides a version is distributable. Skipping
them is how the numbers drifted five months without anything breaking.

## Testing

Two plugins ship executable logic, and each has a regression suite. **Run the
suite of whatever you touched, before committing:**

```sh
bash plugins/guardrails/tests/run.sh        # guard-destructive.sh
bash plugins/privacy-guard/tests/run.sh     # check_privacy.sh, check-sync.sh
```

Both exit non-zero on failure (usable in pre-commit / CI) and run on macOS and
Linux. When you change behaviour, add cases that pin the new behaviour **and its
failure modes**. For a guard the dangerous direction is the false negative, the
one where nothing is printed and the commit goes through, so favour adversarial
cases: `ASK`/`BLOCK` for guardrails, and for privacy-guard at least one case
whose only job is to say whether the guard was neutralised rather than fixed. A
suite made only of cases that must pass goes green on a guard that guards
nothing.

Both suites accept an override that points them at a **candidate** version
(`GUARD_HOOK=`, `PRIVACY_SCRIPT=`, `SYNC_SCRIPT=`). Use it to prove the suite can
fail: point it at the version from before a fix, and it must go red. A bench
nobody has seen fail says nothing.

`plugins/privacy-guard/tests/` carries one **XFAIL** case, an open defect kept as
an executable record. It does not fail the run; when the defect is fixed the
runner reports `XPASS` and fails until the marker is removed. See that suite's
README.

The repo's own hooks have a bench too, `.githooks/tests/run.sh`, covering
`check-version-bump.sh`. Its cases are the real misses (a skill file and a test
file changed under a frozen version; a marketplace entry edited on its own into
disagreement), the edges that must **not** block (a repo-level file, an entry
carrying no version, no marketplace at all, a plugin being added, a plugin being
removed), and two that assert the check *complains* rather than passing when it
cannot read its input: a manifest that does not parse, and a missing `python3`.

Four different reasons exit 1, so an exit code alone cannot say a case blocked
for the reason it was written for. Where that ambiguity is real the bench uses
`check_because`, which also asserts the message.

A pre-commit hook (`.githooks/pre-commit`) runs a plugin's suite when that
plugin's shipped files or its tests are staged, runs the version-bump check on
every commit, and blocks on failure. Adding the next plugin's suite is one
`suite ...` line. Enable the hook once per clone (it lives in a versioned, shared
dir, not `.git/hooks/`):

```sh
git config core.hooksPath .githooks
```

Bypass a single commit with `git commit --no-verify`. There is **no CI**: the
pre-commit is the only gate, and it only fires for whoever set `core.hooksPath`.

## Backlog

This repo has no `BACKLOG.md`: the backlog **is** the issue tracker. Start a
session with `gh issue list`. Issues here are written to be self-contained, with
the mechanics, what was measured, and a recommended answer, because the person
who reads one is rarely the person who wrote it.

## Distribution is not automatic

Pushing to the default branch is **not** enough to reach a node. Three copies are
in play and none of them aligns on its own: this repo, the marketplace clone under
`~/.claude/plugins/marketplaces/`, and the installed plugin under
`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`. Measured on two nodes
on 2026-08-03: the marketplace clone was five days and 28 commits behind while the
installed plugin was two minor versions back, so a session invoking a skill was
running code fixed hours earlier.

```sh
claude plugin marketplace update <marketplace>
claude plugin update <plugin>@<marketplace>    # restart to apply
```

`claude plugin tag` creates a release tag and validates that `plugin.json` and the
marketplace entry agree, which is the check the version drift here has been
missing.

## Writing skills

When creating or editing skills, follow the patterns in `plugins/skill-authoring/skills/creating-skills/SKILL.md`:

- Description formula: `<What it does>. Use when <trigger phrases>. <Key capabilities>.`
- SKILL.md body under 500 lines; move detailed content to `references/`
- Only create helper scripts when they add real value (complex processing, JSON transformation), not for single-command wrappers
- Mark critical constraints with bold **ALWAYS**/**NEVER** in "Important Rules" sections
- Include trigger phrases in descriptions so Claude activates the skill on the right user intents
