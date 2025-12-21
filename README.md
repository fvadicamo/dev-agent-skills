# dev-agent-skills

Agent skills for development workflows - Git, GitHub, and skill authoring.

These skills are designed for [Claude Code](https://claude.com/claude-code), the CLI tool by Anthropic.

## Quick Install

```bash
# Add marketplace
/plugin marketplace add fvadicamo/dev-agent-skills

# Install plugins
/plugin install github-workflow@dev-agent-skills
/plugin install skill-authoring@dev-agent-skills
```

## Available Plugins

### github-workflow

Skills for Git and GitHub workflows following Conventional Commits:

| Skill | Description |
|-------|-------------|
| **git-commit** | Creates commits following Conventional Commits format with type/scope/subject |
| **github-pr-creation** | Creates PRs with automated validation, task tracking, and label suggestions |
| **github-pr-merge** | Merges PRs after validating pre-merge checklist (tests, lint, CI, comments) |
| **github-pr-review** | Handles PR review comments: fetches, classifies by severity, applies fixes |

### skill-authoring

| Skill | Description |
|-------|-------------|
| **creating-skills** | Guide for creating Claude Code skills following Anthropic's best practices |

## How Skills Work

Skills are **model-invoked** - Claude automatically activates them based on your request:

- "Create a commit" → activates `git-commit`
- "Open a PR" → activates `github-pr-creation`
- "Merge the PR" → activates `github-pr-merge`
- "Address review comments" → activates `github-pr-review`
- "Help me create a skill" → activates `creating-skills`

## License

MIT License - see [LICENSE](LICENSE) for details.
