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

- **Commits**: Conventional Commits format - `type(scope): subject` (see `plugins/github-workflow/skills/git-commit/SKILL.md`)
- **Naming**: lowercase, hyphens between words, no spaces (e.g., `github-pr-review`)
- **Merge strategy**: always merge commits (`--merge`), never squash/rebase
- **Changelog**: follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format
- **Versioning**: [Semantic Versioning](https://semver.org/spec/v2.0.0.html)

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

A pre-commit hook (`.githooks/pre-commit`) runs a plugin's suite when that
plugin's shipped files or its tests are staged, and blocks the commit on failure.
Adding the next plugin's suite is one `suite ...` line. Enable the hook once per
clone (it lives in a versioned, shared dir, not `.git/hooks/`):

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
