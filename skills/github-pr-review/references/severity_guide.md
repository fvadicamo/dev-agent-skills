# Severity guide

Reference guide for interpreting severity levels from automated review comments (Gemini, CodeRabbit, Cursor, and others).

## Severity Badges

Gemini uses visual badges in review comments to indicate severity:

### CRITICAL
**Badge**: `![critical](https://www.gstatic.com/codereviewagent/critical.svg)`

**Visual**: Red badge with "critical" text

**Meaning**: Must be fixed before merge. Indicates:
- Security vulnerabilities
- Data loss risks
- Logic errors causing incorrect behavior
- Infinite loops or deadlocks
- Memory leaks or resource exhaustion

**Action**: Stop and fix immediately. These block merge.

---

### HIGH
**Badge**: `![high](https://www.gstatic.com/codereviewagent/high-priority.svg)`

**Visual**: Orange badge

**Meaning**: Should be fixed. Indicates:
- Performance issues
- Error handling gaps
- Potential race conditions
- Missing validation on important paths

**Action**: Address before merge unless there's a strong reason not to.

---

### MEDIUM
**Badge**: `![medium](https://www.gstatic.com/codereviewagent/medium-priority.svg)`

**Visual**: Yellow badge

**Meaning**: Recommended fix. Indicates:
- Code style issues
- Minor refactoring opportunities
- Unreachable code (dead code)
- Duplicate logic
- Missing edge case handling

**Action**: Address if time permits, or create follow-up issue.

---

### LOW
**Badge**: `![low](https://www.gstatic.com/codereviewagent/low-priority.svg)`

**Visual**: Blue/gray badge

**Meaning**: Optional improvement. Indicates:
- Import ordering
- Naming conventions
- Documentation suggestions
- Minor style preferences

**Action**: Optional. Can be skipped with justification.

---

## Detection Patterns

### Gemini Badge Detection (Primary for Gemini)
```python
# In comment body, look for:
"critical.svg" → CRITICAL
"high-priority.svg" → HIGH
"medium-priority.svg" → MEDIUM
"low-priority.svg" → LOW
```

### CodeRabbit Detection

CodeRabbit does **not** use SVG badges. It uses emoji + italic text in the comment body.
The pattern is: `_<emoji> <label>_` or `_<emoji> <label>_ | _<color> <severity>_`

| Comment pattern | Severity |
|----------------|----------|
| `_🔒 Security_` or `_🚨 Critical_` | CRITICAL |
| `_⚠️ Potential issue_` | HIGH |
| `_🐛 Bug_` | HIGH |
| `_⚡ Performance_` | HIGH |
| `_💡 Suggestion_` | MEDIUM |
| `_🧹 Nitpick_` | LOW |
| `_🔧 Optional_` | LOW (skip by default) |

When a secondary color badge is present (`_🔴 Critical_`, `_🟠 Major_`, `_🟡 Minor_`, `_🔵 Info_`),
use the **secondary badge** as the binding severity indicator:

| Secondary badge | Maps to |
|----------------|---------|
| `_🔴 Critical_` | CRITICAL |
| `_🟠 Major_` | HIGH |
| `_🟡 Minor_` | LOW |
| `_🔵 Info_` | LOW |

**CodeRabbit "outside diff" comments** are not posted as inline review comments
(they don't appear in `pulls/$PR/comments`). Instead, they are embedded in the
PR-level review body (`pulls/$PR/reviews`) inside `<details>` blocks with
"Outside diff range comments" as the summary. These must be fetched separately:

```bash
gh api repos/$REPO/pulls/$PR/reviews \
  --jq '.[] | select(.user.login | startswith("coderabbitai")) | .body'
```

Then parse the markdown body to extract file path, line range, and comment text
from the `<details>/<summary>` blocks.

### Cursor Comments
```
<!-- **High Severity** --> → HIGH
<!-- **Medium Severity** --> → MEDIUM
```

### Keyword Detection (Fallback)
When badges or HTML comments aren't present, infer from keywords:

| Keywords | Severity |
|----------|----------|
| security, vulnerability, injection, XSS, SQL | CRITICAL/HIGH |
| dangerous, unsafe, exploit | CRITICAL |
| performance, slow, O(n²) | HIGH |
| error handling, exception, catch | HIGH |
| unreachable, dead code, unused | MEDIUM |
| refactor, simplify, consolidate | MEDIUM |
| style, formatting, PEP, naming | LOW |
| import order, whitespace | LOW |

---

## Related Comments Detection

Comments are often related when:

1. **Consequence relationship**: Comment B is a consequence of fixing Comment A
   - Keywords: "consequence", "result of", "as mentioned above"

2. **Same root cause**: Multiple comments about the same underlying issue
   - Keywords: "root cause", "same issue", "related to"

3. **Unreachable code**: After an exception handling fix, related `except` blocks may become unreachable
   - Pattern: CRITICAL exception handling → MEDIUM unreachable code

4. **Same function/method**: Comments within ~100 lines in the same file, where one is CRITICAL and others are MEDIUM/LOW

---

## Example: Exception Handling Pattern

Common scenario from Gemini reviews:

**Comment 1 (CRITICAL)**: Exception handling in `method_x()` needs refactoring:
- FileNotFoundError should fail-fast, not retry
- Generic exceptions need sleep to avoid busy-loop

**Comment 2 (MEDIUM)**: `except FileNotFoundError` block at line 186 is unreachable
→ This is a CONSEQUENCE of fixing Comment 1

**Comment 3 (MEDIUM)**: `except FileNotFoundError` block at line 473 is unreachable
→ Also a CONSEQUENCE of fixing Comment 1

**Resolution**: Fix Comment 1 first. Comments 2 and 3 will be automatically resolved.

---

## Gemini Config Reference

Gemini behavior is controlled by `.gemini/config.yaml`:

```yaml
code_review:
  threshold: LOW          # Minimum severity to report
  auto_fix: false         # Whether to suggest auto-fixes
  blocking: false         # Whether reviews block merge
```

When `threshold: LOW`, all severities are reported.
When `blocking: false`, reviews are advisory only.

---

## Workflow Integration

1. **Fetch comments**: Parse severity from badge URLs in comment body
2. **Sort by severity**: CRITICAL → HIGH → MEDIUM → LOW
3. **Group related**: Use heuristics above
4. **Process CRITICAL first**: These often resolve MEDIUM/LOW comments
5. **Skip LOW if needed**: They're optional by definition

---

## References

- [Gemini Code Assist Documentation](https://cloud.google.com/gemini/docs/discover/code-assist)
- [GitHub PR Review API](https://docs.github.com/en/rest/pulls/comments)
