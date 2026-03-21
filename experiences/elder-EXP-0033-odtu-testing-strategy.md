# ODTÜ Connect Testing Strategy

## Overview
This document outlines a comprehensive testing strategy for ODTÜ Connect to catch errors before manual testing, including syntax errors, missing imports, TypeScript issues, and runtime problems.

## Current Testing Infrastructure

### Backend (FastAPI)
- **Test Framework**: Python scripts with curl-based E2E testing
- **Structure**: Each endpoint has a corresponding test file (`*_test.py`) and runner script (`*_test.sh`)
- **Virtual Environment**: `/Users/mac/Documents/freelance/odtuyenidonem/backend/venv`
- **Test Organization**: Co-located with endpoint files in `/backend/app/pages/`

### Frontend (Next.js)
- **Build-time Checks**: 
  - `npm run lint` - ESLint for code quality
  - `npm run type-check` - TypeScript compiler checks
- **No formal test suite**: Currently missing Jest/React Testing Library setup

## Testing-QA Agent Integration

The testing-qa agent should be leveraged for:
1. Creating comprehensive test suites
2. Validating both backend and frontend changes
3. Automating pre-deployment checks
4. Ensuring cross-component compatibility

## Pre-Manual Testing Validation Suite

### 1. Syntax and Import Validation

#### Backend Python Checks
```bash
#!/bin/bash
# backend-syntax-check.sh

echo "🔍 Running Backend Syntax Checks..."

# Check Python syntax
find backend -name "*.py" -type f | while read file; do
    python -m py_compile "$file" 2>/dev/null || echo "❌ Syntax error in: $file"
done

# Check imports
python << EOF
import sys
import os
sys.path.append('backend')

failed_imports = []
for root, dirs, files in os.walk('backend/app'):
    for file in files:
        if file.endswith('.py'):
            module_path = os.path.join(root, file)
            try:
                with open(module_path, 'r') as f:
                    content = f.read()
                    # Extract imports
                    import re
                    imports = re.findall(r'^(?:from|import)\s+([^\s]+)', content, re.MULTILINE)
                    for imp in imports:
                        try:
                            exec(f"import {imp.split('.')[0]}")
                        except ImportError as e:
                            failed_imports.append((module_path, imp, str(e)))
            except Exception as e:
                print(f"Error reading {module_path}: {e}")

if failed_imports:
    print("\n❌ Import errors found:")
    for path, imp, error in failed_imports:
        print(f"  {path}: Cannot import {imp}")
else:
    print("✅ All imports valid")
EOF
```

#### Frontend TypeScript Checks
```bash
#!/bin/bash
# frontend-validation.sh

echo "🔍 Running Frontend Validation..."

cd frontend

# TypeScript compilation check
echo "📝 Checking TypeScript..."
npm run type-check
if [ $? -ne 0 ]; then
    echo "❌ TypeScript errors found"
    exit 1
fi

# ESLint check
echo "🔍 Running ESLint..."
npm run lint
if [ $? -ne 0 ]; then
    echo "❌ Linting errors found"
    exit 1
fi

# Check for missing translations
echo "🌐 Checking translations..."
python << EOF
import os
import json
import re

# Load translation files
locales = ['en', 'tr']
translations = {}
for locale in locales:
    with open(f'messages/{locale}.json', 'r') as f:
        translations[locale] = json.loads(f.read())

# Find all translation keys in TSX files
used_keys = set()
for root, dirs, files in os.walk('src'):
    for file in files:
        if file.endswith('.tsx') or file.endswith('.ts'):
            with open(os.path.join(root, file), 'r') as f:
                content = f.read()
                # Find t('key') patterns
                keys = re.findall(r"t\(['\"]([^'\"]+)['\"]", content)
                used_keys.update(keys)

# Check for missing translations
missing = {}
for key in used_keys:
    for locale in locales:
        keys_path = key.split('.')
        current = translations[locale]
        found = True
        for k in keys_path:
            if k in current:
                current = current[k]
            else:
                found = False
                break
        if not found:
            if locale not in missing:
                missing[locale] = []
            missing[locale].append(key)

if missing:
    print("❌ Missing translations:")
    for locale, keys in missing.items():
        print(f"\n  {locale}:")
        for key in keys:
            print(f"    - {key}")
else:
    print("✅ All translations present")
EOF

echo "✅ Frontend validation complete"
```

### 2. API Endpoint Connectivity Check

```bash
#!/bin/bash
# api-connectivity-check.sh

echo "🔍 Checking API Endpoint Connectivity..."

# Start backend if not running
cd backend
if ! lsof -i:8700 > /dev/null; then
    echo "Starting backend..."
    python run.py &
    BACKEND_PID=$!
    sleep 5
fi

# Test basic endpoints
endpoints=(
    "GET /health"
    "GET /api/v1/auth/status"
    "GET /api/v1/announcements/public"
    "GET /api/v1/faq/public"
)

for endpoint in "${endpoints[@]}"; do
    method=$(echo $endpoint | cut -d' ' -f1)
    path=$(echo $endpoint | cut -d' ' -f2)
    
    response=$(curl -s -o /dev/null -w "%{http_code}" -X $method "http://localhost:8700$path")
    
    if [[ $response -ge 200 && $response -lt 300 ]] || [[ $response -eq 401 ]]; then
        echo "✅ $endpoint - $response"
    else
        echo "❌ $endpoint - $response"
    fi
done

# Kill backend if we started it
if [ ! -z "$BACKEND_PID" ]; then
    kill $BACKEND_PID
fi
```

### 3. Feature-Specific Test Suite

For each feature, create a comprehensive test that validates:
- Backend endpoints
- Frontend components
- Integration between them

Example for Announcements feature:

```bash
#!/bin/bash
# test-announcements-feature.sh

echo "🧪 Testing Announcements Feature..."

# 1. Backend Tests
echo "\n📦 Backend Tests:"
cd backend/app/pages/announcements
if [ -f "run_all_tests.sh" ]; then
    ./run_all_tests.sh
else
    echo "⚠️  No backend tests found for announcements"
fi

# 2. Frontend Checks
echo "\n🎨 Frontend Checks:"
cd ../../../../frontend

# Check announcements page syntax
npx tsc --noEmit src/app/[locale]/announcements/page.tsx
if [ $? -ne 0 ]; then
    echo "❌ TypeScript errors in announcements page"
    exit 1
fi

# Check for required imports
python << EOF
import re

with open('src/app/[locale]/announcements/page.tsx', 'r') as f:
    content = f.read()
    
required_imports = [
    "useRouter.*next/navigation",
    "useLocale.*next-intl",
    "apiClient.*@/shared/apiClient"
]

missing = []
for pattern in required_imports:
    if not re.search(pattern, content):
        missing.append(pattern)

if missing:
    print("❌ Missing required imports:")
    for m in missing:
        print(f"  - {m}")
else:
    print("✅ All required imports present")
EOF

# 3. Integration Test
echo "\n🔗 Integration Test:"
# Start both services and test the flow
# ... (implementation depends on specific requirements)
```

### 4. Master Validation Script

```bash
#!/bin/bash
# validate-all.sh
# Run this before any manual testing

echo "🚀 ODTÜ Connect Pre-Testing Validation Suite"
echo "==========================================="

# Set error handling
set -e

# Track results
FAILED=0

# Run all checks
checks=(
    "./backend-syntax-check.sh"
    "./frontend-validation.sh"
    "./api-connectivity-check.sh"
)

for check in "${checks[@]}"; do
    echo "\n🔍 Running: $check"
    if $check; then
        echo "✅ $check passed"
    else
        echo "❌ $check failed"
        FAILED=$((FAILED + 1))
    fi
done

# Summary
echo "\n==========================================="
if [ $FAILED -eq 0 ]; then
    echo "✅ All validation checks passed!"
    echo "Safe to proceed with manual testing."
else
    echo "❌ $FAILED validation checks failed!"
    echo "Please fix the issues before manual testing."
    exit 1
fi
```

## Implementation Plan

### Phase 1: Basic Validation (Immediate)
1. Implement syntax checking scripts
2. Set up TypeScript strict checking
3. Create import validation tools
4. Document common error patterns

### Phase 2: Test Infrastructure (Short-term)
1. Add Jest and React Testing Library to frontend
2. Create PyTest infrastructure for backend
3. Set up test data management
4. Implement CI/CD integration

### Phase 3: Comprehensive Coverage (Long-term)
1. Achieve 80% code coverage
2. Implement visual regression testing
3. Add performance benchmarks
4. Create security testing suite

## Usage with Testing-QA Agent

When using the testing-qa agent, request:

1. **For New Features**:
   ```
   "Create comprehensive tests for [feature] including:
   - Backend endpoint tests
   - Frontend component tests
   - Integration tests
   - Error scenario coverage"
   ```

2. **For Bug Fixes**:
   ```
   "Create regression tests for [bug] that verify:
   - The bug is fixed
   - No new issues introduced
   - Edge cases are covered"
   ```

3. **For Validation**:
   ```
   "Run the complete validation suite and report:
   - Syntax errors
   - Type errors
   - Missing imports
   - API connectivity issues"
   ```

## Common Error Patterns to Catch

1. **Syntax Errors**:
   - Missing semicolons/commas
   - Unclosed brackets/parentheses
   - Invalid JSX syntax

2. **Import Errors**:
   - Missing imports
   - Circular dependencies
   - Wrong import paths

3. **Type Errors**:
   - Undefined properties
   - Type mismatches
   - Missing type definitions

4. **Runtime Errors**:
   - Null/undefined access
   - Missing API endpoints
   - Invalid API responses

5. **Integration Errors**:
   - Frontend/backend contract mismatches
   - Authentication flow issues
   - State management problems

## Monitoring and Reporting

1. **Test Results Dashboard**:
   - Create a simple HTML report
   - Track test trends over time
   - Identify flaky tests

2. **Error Tracking**:
   - Log all validation failures
   - Track error patterns
   - Create fix priority lists

3. **Quality Metrics**:
   - Code coverage percentage
   - Test execution time
   - Error detection rate

## Best Practices

1. **Run validation before every commit**
2. **Fix all errors before manual testing**
3. **Keep tests fast and focused**
4. **Document test failures clearly**
5. **Update tests with code changes**

This comprehensive testing strategy ensures that common errors are caught early in the development process, reducing the time spent on manual testing and improving overall code quality.