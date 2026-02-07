# dev-agent-skills

Agent skills for development workflows - Git, GitHub, and skill authoring.

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
```

## How skills work

Skills are **model-invoked** - Claude automatically activates them based on your request:

- "Create a commit" -> activates `git-commit`
- "Open a PR" -> activates `github-pr-creation`
- "Merge the PR" -> activates `github-pr-merge`
- "Address review comments" -> activates `github-pr-review`
- "Help me create a skill" -> activates `creating-skills`

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

## License

MIT License - see [LICENSE](LICENSE) for details.
