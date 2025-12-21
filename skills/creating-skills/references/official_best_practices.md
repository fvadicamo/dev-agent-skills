# Anthropic Official Best Practices for Skills

Source: https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices

---

## What is a Skill?

A skill is a markdown file (`SKILL.md`) that teaches Claude how to perform a specific task. Skills enable Claude to follow custom workflows, use external tools, and maintain consistency across interactions.

## SKILL.md Format

### Required: YAML Frontmatter

```yaml
---
name: skill-name
description: What the skill does and when to use it
---
```

### Name Field
- Use lowercase with hyphens
- Be descriptive but concise
- Naming patterns:
  - **Gerund form**: `processing-pdfs`, `analyzing-spreadsheets`, `managing-databases`
  - **Noun phrases**: `github-pr-creation`, `code-review`

### Description Field (CRITICAL)

The description determines when Claude uses the skill. It should include:
1. **What**: What the skill does
2. **When**: Trigger phrases and conditions
3. **Capabilities**: Key features

**Formula:**
```
<What it does>. Use when <trigger conditions>. <Key capabilities>.
```

**Example:**
```
Processes PDF documents for text extraction and analysis. Use when user
wants to read PDF, extract PDF content, or analyze PDF documents. Supports
multi-page documents, OCR for scanned PDFs, and structured data extraction.
```

## Token Budget

### Primary concern: Quality over quantity

> "Not every token in your Skill has an immediate cost... However, being concise
> in SKILL.md still matters."

### Guidelines
- **SKILL.md body**: Keep under 500 lines for optimal performance
- **Description**: Maximum 1024 characters
- **Quick Start**: Under 30 lines
- **Split content** when approaching limits

### Progressive Disclosure

```
SKILL.md (always loaded)
    ↓
references/ (loaded when needed)
    ↓
external resources (rarely needed)
```

## Core Principle: Claude is Already Smart

> "Default assumption: Claude is already very smart. Only add context
> Claude doesn't already have."

### Challenge Each Piece of Information

Ask yourself:
- Does Claude really need this explanation?
- Can I assume Claude knows this?
- Does this paragraph justify its token cost?

### What NOT to Include
- Basic programming concepts
- Common tool usage (git, npm, etc.)
- Standard library documentation
- Explanations of well-known patterns

### What TO Include
- Project-specific conventions
- Custom workflows
- Non-obvious requirements
- Domain-specific knowledge Claude wouldn't have

## Helper Scripts

### When Scripts Add Value

**Good use cases:**
- Complex multi-step processing
- JSON parsing and transformation
- State management across calls
- Integration with external APIs
- Calculations or data analysis

**Bad use cases (avoid):**
- Single command wrappers
- Simple file operations
- Basic text transformations
- Anything Claude can do inline

### Script Guidelines

```python
#!/usr/bin/env python3
"""Clear description of what this script does."""

import json
import sys

def main():
    # Use stdin for input when possible
    data = json.load(sys.stdin)

    # Process data
    result = process(data)

    # Output JSON to stdout
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
```

- Output structured JSON
- Use stdin/stdout for piping
- Handle errors gracefully
- Keep single responsibility

## User Confirmation Patterns

### When to Confirm

**ALWAYS confirm before:**
- Modifying user files
- Running destructive commands
- Creating external resources (PRs, issues, deployments)
- Irreversible operations

**Don't over-confirm:**
- Read-only operations
- Reversible actions
- Intermediate steps in approved workflow

### Confirmation Format

```markdown
## Important Rules

- **ALWAYS** confirm before modifying files
- **ALWAYS** show content for approval before creating
- **NEVER** skip user confirmation for file changes
```

## Skill Structure Best Practices

### Recommended Sections (in order)

1. **Title**: `# Skill Name`
2. **One-liner**: Brief description
3. **Quick Start**: Minimal copy-paste example
4. **Core Workflow**: Numbered steps
5. **Helper Scripts**: Table if applicable
6. **Important Rules**: Bold constraints
7. **References**: Links to additional docs

### Quick Start Pattern

```bash
# 1. First step
command_one

# 2. Second step
command_two

# 3. Third step
command_three
```

- Numbered steps
- Actual commands (not pseudocode)
- Copy-paste ready
- Minimal (3-7 steps)

### Core Workflow Pattern

```markdown
## Core Workflow

### 1. Step Name

Brief description of what this step does.

\`\`\`bash
actual_command --with-args
\`\`\`

### 2. Next Step

...
```

## Directory Structure

```
~/.claude/skills/<skill-name>/
├── SKILL.md              # Required: main skill file
├── scripts/              # Optional: helper scripts
│   └── processor.py
└── references/           # Optional: detailed documentation
    ├── examples.md
    └── api-reference.md
```

## Anti-Patterns

| Pattern | Problem | Solution |
|---------|---------|----------|
| Wrapper scripts | No value added | Inline commands |
| Verbose explanations | Token waste | Trust Claude's knowledge |
| Multiple paths | Confusion | One clear workflow |
| Custom systems | Non-standard | Use official patterns |
| Over-confirmation | Friction | Confirm only critical actions |

## Testing Skills

### Trigger Testing
Verify skill activates on expected phrases:
- "create a PR"
- "open pull request"
- "merge to develop"

### Workflow Testing
- Follow Quick Start steps manually
- Verify each command works
- Check error handling

### Edge Cases
- Missing prerequisites
- Invalid input
- Partial completion

## Maintenance

### When to Update
- Workflow changes
- New capabilities added
- User feedback received
- Tools/APIs change

### Keep Skills Focused
- One skill = one workflow
- Split if doing multiple unrelated things
- Prefer multiple small skills over one large skill

---

## Summary: Key Takeaways

1. **Description is critical** - determines when skill is used
2. **Claude is smart** - don't over-explain
3. **Stay under 500 lines** - split if needed
4. **Scripts only for value-add** - not wrappers
5. **Confirm critical actions** - but don't over-confirm
6. **One clear workflow** - not multiple paths
7. **Test trigger phrases** - verify activation
