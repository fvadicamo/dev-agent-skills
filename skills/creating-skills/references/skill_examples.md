# Skill Examples

Real examples from refactored skills following Anthropic best practices.

---

## Example 1: github-pr-creation

### Frontmatter

```yaml
---
name: github-pr-creation
description: Creates GitHub Pull Requests with automated validation and task tracking. Use when user wants to create PR, open pull request, merge feature to develop, or check if ready for PR. Validates task completion against .kiro/specs/*/tasks.md, runs tests, generates Conventional Commits title and description, suggests labels.
---
```

**Analysis:**
- **What**: Creates GitHub Pull Requests with validation
- **When**: "create PR", "open pull request", "merge feature to develop", "check if ready for PR"
- **Capabilities**: validates tasks, runs tests, generates Conventional Commits, suggests labels

### Quick Start

```bash
# 1. Verify GitHub CLI
gh --version && gh auth status

# 2. Analyze commits and tasks
python3 ~/.claude/skills/github-pr-creation/scripts/analyze_commits.py develop

# 3. Run project tests
make test  # or: pytest, npm test

# 4. Generate PR content
python3 ~/.claude/skills/github-pr-creation/scripts/generate_pr.py

# 5. Create PR
gh pr create --title "..." --body "..." --base develop --label feature
```

**Why this works:**
- 5 clear numbered steps
- Actual commands, copy-paste ready
- No explanations, just actions
- Alternatives noted briefly (`# or: pytest, npm test`)

### Helper Scripts Table

```markdown
| Script | Purpose |
|--------|---------|
| `analyze_commits.py` | Maps commits to tasks from .kiro/specs/*/tasks.md |
| `verify_tasks.py` | Checks all sub-tasks are implemented |
| `generate_pr.py` | Creates title, body, labels |
```

**Why scripts are justified:**
- `analyze_commits.py`: Complex git log parsing + task file matching
- `verify_tasks.py`: Multi-file analysis + completion tracking
- `generate_pr.py`: Template generation + Conventional Commits formatting

### Important Rules

```markdown
## Important Rules

- **NEVER** modify repository files (read-only + external commands)
- **ALWAYS** confirm target branch with user
- **ALWAYS** run tests before creating PR
- **ALWAYS** show PR content for approval before creating
```

**Pattern:** Bold **ALWAYS**/**NEVER** for critical constraints

---

## Example 2: github-pr-review

### Frontmatter

```yaml
---
name: github-pr-review
description: Handles PR review comments from Gemini or other reviewers. Use when user wants to resolve PR comments, handle review feedback, fix review comments, or address PR review. Fetches comments via GitHub CLI, classifies by severity, proposes fixes with confirmation, commits with proper format, replies to resolved threads.
---
```

**Analysis:**
- **What**: Handles PR review comments
- **When**: "resolve PR comments", "handle review feedback", "fix review comments", "address PR review"
- **Capabilities**: fetches via CLI, classifies severity, proposes fixes, commits, replies to threads

### Severity Table (Reference Content)

```markdown
| Severity | Badge | Action |
|----------|-------|--------|
| CRITICAL | red | Must fix before merge |
| HIGH | orange | Should fix |
| MEDIUM | yellow | Recommended |
| LOW | blue | Optional |

Process CRITICAL first, then HIGH, MEDIUM, LOW.
```

**Why this is good:**
- Clear visual hierarchy
- Actionable guidance (process order)
- Concise table format

### Inline Commands (No Script Needed)

```markdown
### Fetch PR Comments

\`\`\`bash
PR=$(gh pr view --json number -q '.number')
gh api repos/{owner}/{repo}/pulls/$PR/comments
\`\`\`
```

**Why no script:**
- Single `gh api` command
- No complex processing needed
- Claude can parse JSON response directly

### Verification Checklist

```markdown
### Post-Fix Verification (CRITICAL)

Before committing, verify ALL issues in comment were fixed:

\`\`\`
✅ Verification - Comment #1:
□ Issue 1: [description] → FIXED
□ Issue 2: [description] → FIXED
□ Issue 3: [description] → FIXED

All issues resolved? [Sì/No]
\`\`\`

**If any issue NOT resolved, stop and fix it.**
```

**Pattern:** User confirmation with visual checklist

---

## Common Patterns

### Command with Error Handling

```markdown
### Step Name

\`\`\`bash
command_here || echo "Error: description"
\`\`\`

If error occurs: [brief guidance]
```

### Conditional Workflow

```markdown
### Detect and Run Tests

- If Makefile with `test` target: `make test`
- If package.json: `npm test`
- If Python project: `pytest`
```

### Output Format Specification

```markdown
Output JSON:
\`\`\`json
{
  "field": "value",
  "status": "success|error"
}
\`\`\`
```

---

## Before/After Comparison

### Before Refactoring (Anti-Pattern)

```yaml
name: github-pr-manager
description: Comprehensive GitHub Pull Request management system for feature
development workflow. Use this skill when the user wants to create, verify,
or manage Pull Requests on GitHub repositories. Key triggers - "create PR",
"open pull request", "merge to develop/master", "check if ready for PR",
"verify tasks completion". This skill handles the complete workflow - validates
task completion against project documentation (.kiro/specs/*/tasks.md), runs
tests, generates PR title and description following Conventional Commits,
suggests appropriate labels, and creates the PR using GitHub CLI. Supports
both feature→develop and develop→master workflows with different validation
requirements.
```

**Problems:**
- Verbose description (overkill)
- "Comprehensive" and "complete workflow" are filler words
- Redundant explanations

### After Refactoring (Good)

```yaml
name: github-pr-creation
description: Creates GitHub Pull Requests with automated validation and task
tracking. Use when user wants to create PR, open pull request, merge feature
to develop, or check if ready for PR. Validates task completion against
.kiro/specs/*/tasks.md, runs tests, generates Conventional Commits title and
description, suggests labels.
```

**Improvements:**
- Concise, focused name
- Clear triggers without redundancy
- Specific capabilities listed
- ~50% fewer words, same information

---

## Line Count Comparison

| Skill | Before | After | Reduction |
|-------|--------|-------|-----------|
| github-pr-creation | 597 | 145 | -76% |
| github-pr-review | 511 | 161 | -69% |
| **Total** | 1108 | 306 | **-72%** |

Scripts eliminated: 4 wrapper scripts (~600 lines)
Shared utilities eliminated: 694 lines

**Final structure: 1427 total lines (from ~4000)**
