# EXP-0047: Security Scanner False Positive Reduction

**Project**: cyber-sec-check
**Date**: 2025-12-12
**Category**: Security/Testing
**Status**: ✅ SUCCESS
**Technologies**: Python, Regex, OWASP Security Patterns, Static Analysis

---

## Problem Statement

Security scanner generating excessive false positives (1258 findings with 160 Critical, 1098 High for YeniZelanda project), reducing scanner credibility and overwhelming developers with noise.

---

## Root Causes Identified

### 1. Regex Pattern Issues
- **DES Pattern**: `r"DES|des(?!cription|ign)"` matching legitimate words
  - Flagged "description", "design", "desktop", etc.
  - Negative lookahead insufficient

### 2. Framework Authentication Not Recognized
- FastAPI `Depends()` dependency injection not recognized as authentication
- Common framework patterns flagged as unprotected endpoints

### 3. Secret Detection Over-Matching
- Pattern: `password\s*[=:]\s*.*`
- Flagging variable references: `password: data.password`, `password: formData.password`
- Should only flag hardcoded strings

### 4. XSS Without Context
- All `innerHTML`/`dangerouslySetInnerHTML` flagged
- No check for sanitization (DOMPurify, nh3)
- No distinction between static templates and user content

### 5. Scanning Non-Production Files
- Test files, migrations, examples included
- Auto-generated reports scanned
- Development dependencies flagged

### 6. Config Override Issue
- `utils/config.py` had OLD patterns
- Config loading overrode improved scanner defaults
- Empty list needed to use scanner's patterns

---

## Solutions Applied

### 1. Fixed DES Regex Pattern

```python
# Before: r"DES|des(?!cription|ign)"
# After:
r"\bDES\b(?!cription|ign|ired|ignated|troy|ktop|ert)"
```

**Improvements**:
- `\b` word boundaries for exact match
- Extended negative lookahead for common false positives
- Matches only crypto algorithm references

### 2. FastAPI Authentication Patterns

Added to `owasp_checker.py`:
```python
# Recognize common FastAPI auth patterns
r"Depends\(get_current_user\)",
r"Depends\(get_current_active_user\)",
r"Depends\(verify_token\)",
r"Depends\(check_admin\)",
r"Depends\(require_auth\)",
r"@requires_auth",
```

### 3. Improved Secret Patterns

```python
# Before: password\s*[=:]\s*.*
# After:
r"password\s*[=:]\s*['\"](?!data\.|user\.|form\.|req\.|input|password|Password)[A-Za-z0-9@#$%^&*!]{8,}['\"]"
```

**Key Changes**:
- Require quotes around value
- Exclude variable references with negative lookahead
- Minimum length requirement
- Character class for realistic passwords

### 4. Context-Aware XSS Detection

Added `_check_xss_with_context()` method:
```python
def _check_xss_with_context(self, line: str, file_content: str) -> bool:
    """Check if XSS pattern has sanitization context"""

    # Check for sanitization libraries
    sanitization_patterns = [
        r"DOMPurify\.sanitize",
        r"sanitizeHtml",
        r"nh3\.",
        r"bleach\.",
    ]

    # If sanitization present, not vulnerable
    for pattern in sanitization_patterns:
        if re.search(pattern, file_content, re.IGNORECASE):
            return False

    # Check if static/template content
    static_patterns = [
        r"dangerouslySetInnerHTML=\{\{__html:\s*['\"]",  # Static string
        r"innerHTML\s*=\s*['\"]<",  # Template literal
    ]

    for pattern in static_patterns:
        if re.search(pattern, line):
            return False

    return True  # Potential vulnerability
```

### 5. Comprehensive Exclusion Patterns

Added to all scanners:
```python
exclude_dirs = [
    'node_modules', '.next', '__pycache__', '.git',
    'venv', 'env', '.venv',
    'dist', 'build', 'coverage',
    '.pytest_cache', '.mypy_cache',
    'playwright-report', 'test-results',
    'migrations', 'alembic',
]

skip_patterns = [
    r'/test[s]?/',
    r'\.test\.',
    r'\.spec\.',
    r'example\.',
    r'\.example\.',
    r'template\.',
    r'\.template\.',
]
```

### 6. Fixed Config Loading

```python
# utils/config.py - BEFORE
SECRET_PATTERNS = [
    r"password\s*[=:]\s*.*",  # OLD, overly broad
]

# utils/config.py - AFTER
SECRET_PATTERNS = []  # Empty - use scanner defaults
```

---

## Results

### Quantitative Improvements

| Metric | Before | After | Reduction |
|--------|--------|-------|-----------|
| Total Findings | 1258 | 243 | -81% |
| Critical | 160 | 42 | -74% |
| High | 1098 | 33 | -97% |

### Qualitative Improvements

1. **Eliminated Common False Positives**
   - "description" not flagged as DES
   - FastAPI auth recognized
   - Variable references not flagged as secrets

2. **Context-Aware Detection**
   - XSS checks for sanitization
   - Static content vs dynamic content
   - Framework patterns recognized

3. **Better Signal-to-Noise Ratio**
   - 81% reduction in total findings
   - Higher confidence in remaining findings
   - Developers can focus on real issues

---

## Files Modified

1. **scanners/owasp_checker.py**
   - Fixed DES regex with proper word boundaries
   - Added FastAPI authentication patterns
   - Implemented `_check_xss_with_context()` method
   - Enhanced context-aware detection

2. **scanners/file_scanner.py**
   - Improved secret patterns with negative lookahead
   - Added exclude patterns for test/example files
   - Required quotes for secret values

3. **scanners/vibe_trap_scanner.py**
   - Enhanced NoSQL injection patterns
   - Expanded exclude_dirs list
   - Added skip patterns

4. **utils/config.py**
   - Changed SECRET_PATTERNS to empty list
   - Allow scanner defaults to be used
   - Removed outdated patterns

---

## Key Learnings

### 1. Config Files Can Override Defaults
- Always check config loading logic
- Empty list != None in some contexts
- Scanner defaults may be better than config overrides

### 2. Negative Lookahead for Exclusions
```python
# Pattern: Match X but not X followed by Y
r"\bX\b(?!Y|Z)"
```

### 3. Context-Aware Detection Reduces FPs
- Check for sanitization libraries
- Recognize framework patterns
- Distinguish static vs dynamic content

### 4. Variable References Are Not Secrets
```python
# NOT a secret (variable reference)
password: data.password
password = formData.password

# IS a secret (hardcoded)
password = "MyP@ssw0rd123"
password: "admin123"
```

### 5. Exclude Development Artifacts
- Test files and specs
- Auto-generated reports
- Migration scripts
- Example/template files

### 6. Word Boundaries Matter
```python
# Without \b - matches "description"
r"DES(?!cription)"  # Matches "DES" in "DEScription"

# With \b - exact word only
r"\bDES\b(?!cription)"  # Only matches standalone "DES"
```

---

## Pattern Templates

### 1. Crypto Algorithm Detection
```python
# Match crypto name but exclude common words
r"\bALGO\b(?!word1|word2|word3)"
```

### 2. Secret Detection
```python
# Require quotes, exclude variable references
r"secret_key\s*[=:]\s*['\"](?!var\.|obj\.)[A-Za-z0-9]{16,}['\"]"
```

### 3. Framework Auth Recognition
```python
# Common dependency injection patterns
r"Depends\((get_current_user|verify_token|check_admin)\)",
```

### 4. Context-Aware XSS
```python
def check_xss_with_context(line, full_file_content):
    # Check for sanitization
    if has_sanitization(full_file_content):
        return False

    # Check for static content
    if is_static_template(line):
        return False

    return True  # Potential vulnerability
```

---

## Related Experiences

- **EXP-0045**: nh3 HTML Sanitization - YeniZelanda (referenced in XSS context detection)
- **TRAP-016**: NoSQL Injection Patterns
- **TRAP-017**: MongoDB Injection Defense
- **TRAP-018**: Advanced NoSQL Exploits

---

## Prevention Checklist

Before deploying security scanner updates:

- [ ] Test against known false positives
- [ ] Verify config files don't override improvements
- [ ] Check negative lookahead patterns are complete
- [ ] Test with multiple real projects
- [ ] Document pattern rationale
- [ ] Add test cases for edge cases
- [ ] Verify framework-specific patterns
- [ ] Check exclusion lists are comprehensive

---

## Applicability

**When to Apply**:
- Building static analysis tools
- Implementing security scanners
- Reducing false positive rates
- Pattern-based detection systems
- Code quality tools

**Transferable Patterns**:
- Context-aware detection
- Negative lookahead for exclusions
- Framework pattern recognition
- Variable vs literal distinction
- Config override management

---

## Future Improvements

1. **Machine Learning**
   - Learn from user feedback
   - Adaptive pattern refinement
   - Project-specific baselines

2. **Semantic Analysis**
   - AST-based detection
   - Data flow analysis
   - Control flow understanding

3. **Framework Plugins**
   - FastAPI auth plugin
   - Django middleware detection
   - Express.js patterns
   - Spring Security recognition

4. **Confidence Scoring**
   - Weighted findings
   - Context-based confidence
   - Historical accuracy tracking

---

**Tags**: `security`, `static-analysis`, `false-positives`, `regex`, `owasp`, `pattern-matching`, `scanner-optimization`, `context-awareness`
