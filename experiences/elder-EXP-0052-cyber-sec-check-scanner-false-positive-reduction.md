# EXP-0052: Cyber-Sec-Check Scanner False Positive Reduction

## Metadata
- **Date**: 2025-12-12
- **Project**: /Users/mac/Documents/freelance/cyber-sec-check
- **Related**: EXP-0045, TRAP-016, TRAP-017, TRAP-018

## Problem
Security scanner was generating too many false positives:
- YeniZelanda project: 1258 findings (160 Critical, 1098 High)
- ~90% were false positives due to pattern limitations

## Root Causes

### 1. DES Regex Matching Common Words
```python
# BAD - matches "description", "design", etc.
r"DES|des(?!cription|ign)"

# GOOD - word boundary with comprehensive exclusions
r"\bDES\b(?!cription|ign|ired|ignated|troy|ktop|ert)"
```

### 2. FastAPI Depends() Not Recognized
OWASP checker didn't detect FastAPI's dependency injection auth pattern:
```python
# Added patterns:
r"Depends\s*\(\s*get_current_user",
r"Depends\s*\(\s*get_admin_user",
r"current_user\s*:\s*\w+\s*=\s*Depends",
```

### 3. Secret Patterns Matching Variable References
```python
# BAD - matches "password: data.password"
r"password\s*[=:]\s*['\"]?[^\s'\"]{8,}"

# GOOD - requires quotes and excludes variable patterns
r"password\s*[=:]\s*['\"](?!data\.|user\.|form\.|req\.|input|password|Password)[A-Za-z0-9@#$%^&*!]{8,}['\"]"
```

### 4. XSS Without Sanitization Context
```python
# BAD - flags all innerHTML usage
(r"innerHTML\s*=", "Potential XSS")

# GOOD - context-aware detection
def _check_xss_with_context(self, filepath, content, has_sanitization):
    # Check for DOMPurify, nh3, bleach, sanitize in file
    # Reduce severity if sanitization exists
    severity = "medium" if has_sanitization else "high"
```

### 5. Config Override Issue
`utils/config.py` had old patterns in `default_config` that overrode improved scanner defaults:
```python
# FIX: Empty list = use scanner defaults
"secret_patterns": [],  # Let file_scanner.py use its improved defaults
```

## Solutions Applied

### Files Modified
1. **scanners/owasp_checker.py**
   - Fixed DES regex
   - Added FastAPI auth patterns
   - Added `_check_xss_with_context()` method

2. **scanners/file_scanner.py**
   - Improved secret patterns (require quotes, exclude variables)
   - Added skip patterns for example/template files
   - Added test directory exclusions

3. **scanners/vibe_trap_scanner.py**
   - Updated NoSQL injection patterns
   - Expanded exclude_dirs

4. **utils/config.py**
   - Set `secret_patterns: []` to use scanner defaults

## Results

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Total** | 1258 | 243 | **-81%** |
| **Critical** | 160 | 42 | **-74%** |
| **High** | 1098 | 33 | **-97%** |

## Key Learnings

1. **Config Override Check**: Always verify config loading - default configs can override scanner improvements
2. **Negative Lookahead**: Use `(?!...)` for excluding false positive patterns
3. **Context-Aware Detection**: Check for sanitization (nh3, DOMPurify, bleach) before flagging XSS
4. **Variable vs Literal**: `password: data.password` is NOT a secret, `password: "MySecret123"` IS
5. **Exclude Test Outputs**: playwright-report, coverage, test-results are auto-generated

## Pattern Library

### Safe to Ignore
- `password: data.password` - Variable reference
- `password: passwordFormData` - Variable name
- `innerHTML` with sanitization - Context-safe
- Files in `/testing/`, `/.claude/`, `/playwright-report/`

### True Positives
- `password = "literal123"` - Hardcoded secret
- `api_key = "sk_live_xxx"` - API key with known prefix
- `mongodb+srv://user:pass@host` - Connection string with credentials
- `eyJhbGciOi...` - JWT token (three base64 parts)
