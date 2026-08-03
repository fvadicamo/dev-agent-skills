# dev-agent-skills

Agent skills and hooks for development workflows - Git, GitHub, skill authoring, safety guardrails, and public-repo privacy.

These skills are designed for [Claude Code](https://claude.com/claude-code), the CLI tool by Anthropic.

## Why these skills?

Claude Code already knows how to commit, create PRs, and review code. But without structured guidance it tends to:

- Use inconsistent commit formats across a session
- Skip target branch confirmation and create PRs against the wrong branch
- Not search for task documentation or validate task completion before opening a PR
- Suggest labels that don't exist in the project
- Process review comments in random order instead of by severity
- Use the wrong GitHub API syntax for replying to threads (`-f` instead of `--input -`)
- Generate verbose merge messages that clutter the git log
- Merge without verifying all review comments have been addressed

These skills add structured workflows that prevent these issues. They don't replace Claude's capabilities - they guide them through the right sequence of steps.

There are no official Anthropic skills for Git/GitHub workflows. This plugin fills that gap.

## Quick install

```bash
# Add marketplace
/plugin marketplace add fvadicamo/dev-agent-skills

# Install plugins
/plugin install github-workflow@dev-agent-skills
/plugin install skill-authoring@dev-agent-skills
/plugin install guardrails@dev-agent-skills
/plugin install privacy-guard@dev-agent-skills
```

## How skills work

Skills are **model-invoked** - Claude automatically activates them based on your request:

- "Create a commit" -> activates `git-commit`
- "Open a PR" -> activates `github-pr-creation`
- "Merge the PR" -> activates `github-pr-merge`
- "Address review comments" -> activates `github-pr-review`
- "Help me create a skill" -> activates `creating-skills`
- "Set up the privacy guard on this public repo" -> activates `privacy-guard`

## Plugin: github-workflow

Skills for Git and GitHub workflows following [Conventional Commits](https://www.conventionalcommits.org/).

### git-commit

Creates commits following Conventional Commits format with type/scope/subject.

**What it adds over Claude's default behavior:**

| Without this skill | With this skill |
|--------------------|-----------------|
| Inconsistent commit format across a session | Enforces CC format with required scope, max 50 chars, imperative tense |
| Ignores existing commit style in the project | Dynamic context injection loads recent commits so Claude matches the style |
| Sometimes uses generic messages ("update code") | Strict rules against vague messages |
| No HEREDOC for multi-line commits | Provides HEREDOC pattern for clean multi-line messages |

Additional features:
- Checks CLAUDE.md for project-specific commit conventions
- Extra commit type `security` beyond standard CC

### github-pr-creation

Creates Pull Requests with automated validation, task tracking, and label suggestions.

**What it adds over Claude's default behavior:**

| Without this skill | With this skill |
|--------------------|-----------------|
| Often skips target branch confirmation | Always asks user to confirm base branch |
| Doesn't search for task documentation | Searches Kiro, Cursor, Trae, GitHub Issues, and generic paths for task specs |
| No task completion validation | Maps commits to tasks and reports missing sub-tasks before creating PR |
| Suggests labels that may not exist in the project | Checks `gh label list` first, matches available labels, suggests creating missing ones |
| Generic PR body | 7 type-specific templates (feature, release, bugfix, hotfix, refactoring, docs, CI/CD) |
| May skip tests | Tests must pass before PR creation |

### github-pr-merge

Merges Pull Requests after validating a pre-merge checklist.

**What it adds over Claude's default behavior:**

| Without this skill | With this skill |
|--------------------|-----------------|
| May merge without checking review comments | Detects unreplied comments via jq query, stops merge and redirects to review skill |
| Inconsistent merge strategy | Always merge commit (`--merge`), never squash/rebase |
| Verbose or empty merge messages | Concise format: 3-5 bullets + reviews/tests/refs (~10 lines max) |
| May skip CI/lint checks | Full pre-merge checklist (tests, lint, CI, comments) with summary shown to user |
| Forgets branch cleanup | Auto-deletes remote branch, switches to develop and pulls |

### github-pr-review

Handles PR review comments and feedback resolution.

**What it adds over Claude's default behavior:**

| Without this skill | With this skill |
|--------------------|-----------------|
| Processes comments in random order | Classifies by severity (CRITICAL > HIGH > MEDIUM > LOW) and processes in order |
| No severity detection | Detects Gemini badges, Cursor HTML comments, and keyword-based severity |
| One commit per fix regardless of impact | Batch strategy: separate commits for functional fixes, single batch for cosmetic |
| May use `-f in_reply_to=...` (broken) | Uses correct `--input -` JSON syntax for thread replies |
| Generic or no replies to threads | Standard templates: Fixed, Won't fix, By design, Deferred, Acknowledged |
| Triggers bot review loops on every push | Strategies to avoid loops: batch pushes, draft PR, skip keywords |
| Forgets to submit formal review | Prompts `gh pr review` with appropriate flag (approve/request-changes/comment) |

## Plugin: skill-authoring

### creating-skills

Guide for creating Claude Code skills following Anthropic's official best practices.

**What it adds over Claude's default behavior:**

Claude knows the basics of skill creation, but this skill provides a comprehensive, up-to-date reference covering features that Claude may not know about or consistently apply.

- Complete frontmatter reference (all 10 fields including `allowed-tools`, `context`, `agent`, `hooks`)
- Invocation control matrix (`disable-model-invocation`, `user-invocable`)
- Dynamic features: context injection (`` !`cmd` ``), string substitutions (`$ARGUMENTS`), subagent execution
- Degrees of freedom concept for matching specificity to task fragility
- Directory structure with `scripts/`, `references/`, and `assets/` resource types
- Description formula, naming conventions, progressive disclosure patterns

#### Comparison with the official skill-creator

This skill complements the official [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator) from Anthropic. They serve different purposes and can be used together.

| Feature | This skill | Official skill-creator |
|---------|-----------|----------------------|
| Complete frontmatter reference (10 fields) | Yes | No (only 5 fields) |
| Invocation control matrix | Yes | No |
| Dynamic context injection (`` !`cmd` ``) | Yes, with examples | No |
| String substitutions (`$ARGUMENTS`, `$1`) | Yes | No |
| Subagent execution (`context: fork`) | Yes, with example | No |
| Discovery hierarchy | Yes | No |
| Context budget (2%, 16k fallback) | Yes | No |
| Skills/commands unification | Yes | No |
| Frontmatter validation rules | Yes | No |
| 6 feature-specific examples | Yes | No |
| Scaffolding script (`init_skill.py`) | No | Yes |
| Packaging script (`package_skill.py`) | No | Yes |
| Validation script (`quick_validate.py`) | No | Yes |
| Workflow patterns reference | No | Yes |
| Output patterns reference | No | Yes |

**In short**: this skill is a practical, up-to-date reference for all available features. The official skill is a conceptual guide with scaffolding/packaging tools. Install both for the most complete experience.

## Plugin: guardrails

Safety guardrails for running Claude Code with reduced supervision (for example under `--dangerously-skip-permissions`). It currently ships one `PreToolUse` hook; more checks may follow. Unlike the skills, the hook is not model-invoked: it runs automatically on every Bash tool call, before the command executes.

### guard-destructive

**What it adds over Claude's default behavior:**

| Without this hook | With this hook |
|-------------------|----------------|
| Catastrophic commands run if permissions allow | Hard-blocks `rm -rf /` (and `~`/`$HOME`), `rsync --delete`, `docker rm -v` / `docker volume rm` |
| `rm` runs without a second look | Prompts for confirmation and enumerates the resolved operands so you see what would be deleted |
| Temp-file cleanup triggers the same prompt | `rm` whose operands all sit strictly under a temp dir (`/tmp`, `/private/tmp`, `/var/tmp`, `/var/folders`) is exempted |
| Destructive commands hidden in `ssh '...'` slip through | Catches commands wrapped in `ssh '...'` / `sh -c "..."` |
| `git reset --hard`, `dd`, `mkfs`, `shred` run unguarded | Prompts for confirmation before each |

The hook is harness-only - it adds no token cost to the model context.

## Plugin: privacy-guard

For people who run private infrastructure (a home lab, a VPS fleet, client machines) and also publish open-source repos. The public repo is the boundary: hostnames, internal project names, local usernames, home paths and VPN addresses must not cross it, in files or anywhere else.

### privacy-guard

**What it adds over Claude's default behavior:**

| Without this skill | With this skill |
|--------------------|-----------------|
| Internal hostnames and paths slip into docs and examples | An explicit threat model of what is sensitive and what is fine to publish |
| Mentioning an internal host in chat leads Claude to write it into the repo | The conversation is private, the repo is not: naming a host does not authorize committing it |
| Only files get checked | Commit messages, branch names, PR and issue bodies, CHANGELOG and release artifacts are in scope too |
| Nothing catches a leak before it is pushed | A pre-commit gate greps the lines a commit **adds** against a local denylist and blocks it, printing the matched lines with their real line numbers |
| A shared denylist would publish the very tokens it protects | The denylist lives in gitignored `.local/`, so it stays private and the hook is a no-op for external contributors and CI, where gitleaks still covers generic secrets |
| A script copied into each repo drifts invisibly | Each copy carries its version and provenance, and `check-sync.sh REPO...` reports which copies are behind, diverged, or missing |

Setup is per-repo and scripted by the skill: copy `check_privacy.sh` into `scripts/`, fill `.local/privacy-denylist.txt` from the shipped placeholder template, add the gitleaks + denylist blocks to `.pre-commit-config.yaml`, then arm-check it with a throwaway file containing a known token. A repo that already sets `core.hooksPath` cannot run `pre-commit install`; the skill documents the variant that calls the script from the existing hook instead.

Note the deliberate trade-offs: the guard is client-side and only protects commits made from a machine that has the denylist; it scans what a commit adds, so it stops new leaks and does not audit history; and it does not cover pastes into the GitHub web UI. That is what the behavioral rules are for.

## Development

Two plugins ship executable logic, and each has a regression suite:

```sh
bash plugins/guardrails/tests/run.sh        # guard-destructive.sh
bash plugins/privacy-guard/tests/run.sh     # check_privacy.sh, check-sync.sh
```

Both exit non-zero on failure and run on macOS and Linux. Each accepts an override
(`GUARD_HOOK=`, `PRIVACY_SCRIPT=`, `SYNC_SCRIPT=`) that points it at a candidate script:
point it at the version from before a fix and the suite must go red. A bench nobody has
seen fail says nothing.

After cloning the repo to work on either, enable the shared git hooks (they live in the
versioned `.githooks/`, not in `.git/hooks/`):

```sh
git config core.hooksPath .githooks      # one-time, per clone
```

With that set, a pre-commit hook runs a plugin's suite whenever that plugin's shipped
files or its tests are staged, and blocks the commit on a regression (bypass once with
`git commit --no-verify`). It also runs this repo's own privacy check on the staged
lines. There is no CI: that hook is the only gate, and it only fires for whoever set
`core.hooksPath`.

See each suite's `tests/README.md` for the case format and `CLAUDE.md` for contributor
guidance.

## License

MIT License - see [LICENSE](LICENSE) for details.
