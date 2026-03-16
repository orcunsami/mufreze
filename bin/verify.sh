#!/bin/bash
# MUFREZE
# Verify script - checks project files for syntax/compilation errors
# Usage: verify.sh <work_dir>
# Exit: 0=success, 1=failure

set -euo pipefail

work_dir="${1:-}"

if [[ -z "$work_dir" ]]; then
    echo "❌ Usage: verify.sh <work_dir>"
    exit 1
fi

if [[ ! -d "$work_dir" ]]; then
    echo "❌ Directory not found: $work_dir"
    exit 1
fi

cd "$work_dir"

# Detect project type
detect_project_type() {
    if [[ -f "pyproject.toml" ]] || [[ -f "requirements.txt" ]] || [[ -f "setup.py" ]] || [[ -f "setup.cfg" ]]; then
        echo "python"
    elif [[ -f "tsconfig.json" ]]; then
        echo "typescript"
    elif [[ -f "package.json" ]]; then
        echo "javascript"
    else
        echo "unknown"
    fi
}

# Get changed files or all files
get_files_to_check() {
    local pattern="$1"
    local files
    
    # Try to get changed files from git
    if git rev-parse --git-dir > /dev/null 2>&1; then
        files=$(git diff --name-only HEAD 2>/dev/null | grep -E "$pattern" || true)
        if [[ -z "$files" ]]; then
            # No changed files, check all
            files=$(find . -type f -name "$2" 2>/dev/null | sed 's|^\./||' || true)
        fi
    else
        # Not a git repo, check all files
        files=$(find . -type f -name "$2" 2>/dev/null | sed 's|^\./||' || true)
    fi
    
    echo "$files"
}

# Verify Python files
verify_python() {
    echo "🔍 Detected Python project"
    
    local files
    files=$(get_files_to_check '\.py$' '*.py')
    
    if [[ -z "$files" ]]; then
        echo "⚠️ No Python files to verify"
        return 0
    fi
    
    local failed=0
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue
        
        echo "📄 Checking: $file"
        if ! python -m py_compile "$file" 2>&1; then
            echo "❌ Syntax error in: $file"
            failed=1
        fi
    done <<< "$files"
    
    return $failed
}

# Verify TypeScript files
verify_typescript() {
    echo "🔍 Detected TypeScript project"
    
    if [[ ! -f "tsconfig.json" ]]; then
        echo "⚠️ No tsconfig.json found, skipping TypeScript check"
        return 0
    fi
    
    echo "📄 Running tsc --noEmit"
    if ! npx tsc --noEmit 2>&1; then
        echo "❌ TypeScript compilation failed"
        return 1
    fi
    
    return 0
}

# Verify JavaScript files
verify_javascript() {
    echo "🔍 Detected JavaScript project"
    
    local files
    files=$(get_files_to_check '\.js$' '*.js')
    
    if [[ -z "$files" ]]; then
        echo "⚠️ No JavaScript files to verify"
        return 0
    fi
    
    local failed=0
    
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        [[ -f "$file" ]] || continue
        
        echo "📄 Checking: $file"
        if ! node --check "$file" 2>&1; then
            echo "❌ Syntax error in: $file"
            failed=1
        fi
    done <<< "$files"
    
    return $failed
}

# Main
main() {
    echo "🎖️ MUFREZE: Starting verification in $work_dir"
    
    local project_type
    project_type=$(detect_project_type)
    
    case "$project_type" in
        python)
            if ! verify_python; then
                echo "❌ Verification failed"
                exit 1
            fi
            ;;
        typescript)
            if ! verify_typescript; then
                echo "❌ Verification failed"
                exit 1
            fi
            ;;
        javascript)
            if ! verify_javascript; then
                echo "❌ Verification failed"
                exit 1
            fi
            ;;
        unknown)
            echo "⚠️ Unknown project type - no verification performed"
            echo "   (Looking for: requirements.txt/pyproject.toml, tsconfig.json, or package.json)"
            exit 0
            ;;
    esac
    
    echo "✅ All files verified"
    exit 0
}

main
