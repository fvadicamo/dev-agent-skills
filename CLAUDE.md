# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

A collection of Claude Code agent skills and hooks for development workflows, distributed as a plugin marketplace. Contains 5 skills and 1 hook organized into 3 plugins:

- **github-workflow** plugin: `git-commit`, `github-pr-creation`, `github-pr-merge`, `github-pr-review`
- **skill-authoring** plugin: `creating-skills`
- **guardrails** plugin: `guard-destructive` PreToolUse hook

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

## Writing skills

When creating or editing skills, follow the patterns in `plugins/skill-authoring/skills/creating-skills/SKILL.md`:

- Description formula: `<What it does>. Use when <trigger phrases>. <Key capabilities>.`
- SKILL.md body under 500 lines; move detailed content to `references/`
- Only create helper scripts when they add real value (complex processing, JSON transformation), not for single-command wrappers
- Mark critical constraints with bold **ALWAYS**/**NEVER** in "Important Rules" sections
- Include trigger phrases in descriptions so Claude activates the skill on the right user intents
