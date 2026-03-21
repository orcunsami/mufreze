# EXP-0053: Vue.js XSS Prevention with DOMPurify

**Project**: Grand (Vue.js)
**Date**: 2025-12-12
**Status**: Complete - SUCCESS
**Category**: Security/Frontend
**Technologies**: Vue.js 3, TypeScript, DOMPurify, v-html, XSS Prevention

---

## Problem

**Initial State**: 9 XSS vulnerabilities detected across Vue components using unsafe `v-html` directive
- Blog content rendering
- AI chat messages (ChatModel.vue, AIDemo.vue)
- Product descriptions (admin panel)
- Paper template previews (with CSS styling requirements)
- Static blog posts

**Root Cause**: Vue's `v-html` directive renders raw HTML without sanitization, creating XSS attack vectors when displaying user-generated or dynamic content.

**Security Risk**: OWASP A03:2021 - Injection (Cross-Site Scripting)

---

## Solution Architecture

### 1. Centralized Sanitization Utility

Created `/utils/sanitize.ts` with multiple sanitization levels:

```typescript
import DOMPurify from 'dompurify'

// Strict sanitization - forbids style/script tags
export function sanitizeHtml(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'u', 'a', 'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'code', 'pre'],
    ALLOWED_ATTR: ['href', 'target', 'rel', 'class']
  })
}

// Template sanitization - allows style tags for document templates
export function sanitizeTemplate(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'u', 'a', 'ul', 'ol', 'li', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'blockquote', 'code', 'pre', 'div', 'span', 'style'],
    ALLOWED_ATTR: ['href', 'target', 'rel', 'class', 'style', 'id'],
    FORBID_TAGS: ['script', 'iframe', 'object', 'embed']
  })
}

// Basic sanitization - minimal tags for comments
export function sanitizeBasic(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: ['p', 'br', 'strong', 'em', 'a'],
    ALLOWED_ATTR: ['href']
  })
}

// Strip all HTML
export function stripHtml(dirty: string): string {
  return DOMPurify.sanitize(dirty, {
    ALLOWED_TAGS: [],
    ALLOWED_ATTR: []
  })
}
```

### 2. Component Implementation Patterns

#### Pattern A: Computed Properties
```typescript
// BlogOne.vue, StaticBlogPost.vue, AdminDisplayProductsSingle.vue
import { sanitizeHtml } from '@/utils/sanitize'

const sanitizedContent = computed(() => {
  return sanitizeHtml(props.post.content)
})

// Template
<div v-html="sanitizedContent"></div>
```

#### Pattern B: Function Sanitization
```typescript
// ChatModel.vue - formatMessage function
import { sanitizeHtml } from '@/utils/sanitize'

function formatMessage(content: string): string {
  const formatted = content
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
    .replace(/\n/g, '<br>')

  return sanitizeHtml(formatted)  // Sanitize AFTER formatting
}

// Template
<div v-html="formatMessage(message.content)"></div>
```

#### Pattern C: Template Preview (Allows CSS)
```typescript
// PaperTemplateEdit.vue, PaperEditImproved.vue
import { sanitizeTemplate } from '@/utils/sanitize'

const previewHtml = computed(() => {
  return sanitizeTemplate(compiledTemplate.value)
})

// Template
<div v-html="previewHtml"></div>
```

### 3. Updated Components

| Component | Use Case | Sanitization Level |
|-----------|----------|-------------------|
| BlogOne.vue | Blog content display | sanitizeHtml (strict) |
| ChatModel.vue | AI chat messages | sanitizeHtml (strict) |
| AIDemo.vue | AI demo messages | sanitizeHtml (strict) |
| StaticBlogPost.vue | Static blog content | sanitizeHtml (strict) |
| AdminDisplayProductsSingle.vue | Product descriptions | sanitizeHtml (strict) |
| PaperOne.vue | Paper template preview | sanitizeTemplate (allows style) |
| PaperEditImproved.vue | Template compilation | sanitizeTemplate (allows style) |
| PaperTemplateEdit.vue | Template editing preview | sanitizeTemplate (allows style) |

---

## Key Learnings

### 1. Sanitization Timing Matters

```typescript
// ❌ WRONG - Sanitize before formatting
function formatMessage(content: string): string {
  const sanitized = sanitizeHtml(content)  // Removes ** markers
  return sanitized.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')  // No effect
}

// ✅ CORRECT - Sanitize after formatting
function formatMessage(content: string): string {
  const formatted = content.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
  return sanitizeHtml(formatted)  // Sanitizes formatted HTML
}
```

### 2. Template Preview Requires Style Tags

Document templates (paper templates) need CSS styling for preview:
- Use `sanitizeTemplate()` instead of `sanitizeHtml()`
- Allows `<style>` tags and `style` attributes
- Still blocks `<script>`, `<iframe>`, `<object>`, `<embed>`

### 3. Scanner False Positive Fix

**Issue**: Scanner detected `exec()` in ChatModel.vue as command injection

```typescript
// ❌ Scanner flagged this as vulnerable
if (pattern.exec(line)) {
  // This is JavaScript's RegExp.exec(), not shell exec!
}
```

**Solution**: Updated scanner pattern with negative lookbehind
```python
# Before - flagged all exec()
r"\.exec\("

# After - excludes JavaScript RegExp methods
r"(?<!pattern\.)(?<!regex\.)(?<!regexp\.)\.exec\("
```

### 4. DOMPurify Configuration Strategy

**Three-tier approach:**
1. **Strict** (`sanitizeHtml`) - User content, blog posts, comments
2. **Template** (`sanitizeTemplate`) - Document templates with CSS
3. **Basic** (`sanitizeBasic`) - Comments, short text
4. **Strip** (`stripHtml`) - Plain text extraction

---

## Implementation Steps

1. **Install DOMPurify**
   ```bash
   npm install dompurify
   npm install --save-dev @types/dompurify
   ```

2. **Create Utility**
   - Create `/utils/sanitize.ts`
   - Define sanitization functions with DOMPurify configs
   - Export multiple sanitization levels

3. **Update Components**
   - Import: `import { sanitizeHtml } from '@/utils/sanitize'`
   - Wrap computed properties or function returns
   - Choose appropriate sanitization level

4. **Test Coverage**
   - Test with malicious payloads: `<script>alert('XSS')</script>`
   - Test with legitimate HTML: `<strong>Bold</strong>`
   - Test template CSS: `<style>.header { color: red; }</style>`
   - Verify formatting preserved: `**bold** text`

5. **Scanner Update**
   - Update vibe_trap_scanner.py regex patterns
   - Add negative lookaheads for JavaScript methods
   - Test against codebase

---

## Results

### Before
- 9 XSS vulnerabilities detected
- Raw HTML rendering without sanitization
- High security risk (OWASP A03:2021)

### After
- 0 XSS vulnerabilities
- All v-html usage sanitized with DOMPurify
- Proper separation of content types (strict vs template)
- Scanner false positive eliminated

### Performance Impact
- Negligible (DOMPurify is highly optimized)
- Sanitization runs once per render cycle
- Cached in computed properties

---

## Code Examples

### Example 1: Blog Content (Strict Sanitization)

**File**: `BlogOne.vue`

```typescript
<script setup lang="ts">
import { computed } from 'vue'
import { sanitizeHtml } from '@/utils/sanitize'

const props = defineProps<{
  post: {
    content: string
    // ... other fields
  }
}>()

const sanitizedContent = computed(() => {
  return sanitizeHtml(props.post.content)
})
</script>

<template>
  <div class="blog-content" v-html="sanitizedContent"></div>
</template>
```

### Example 2: AI Chat with Formatting (Function Sanitization)

**File**: `ChatModel.vue`

```typescript
<script setup lang="ts">
import { sanitizeHtml } from '@/utils/sanitize'

interface Message {
  role: 'user' | 'assistant'
  content: string
}

function formatMessage(content: string): string {
  // Apply formatting first
  let formatted = content
    .replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')  // Bold
    .replace(/\*(.*?)\*/g, '<em>$1</em>')              // Italic
    .replace(/\n/g, '<br>')                             // Line breaks

  // Sanitize AFTER formatting
  return sanitizeHtml(formatted)
}
</script>

<template>
  <div v-for="message in messages" :key="message.id">
    <div v-html="formatMessage(message.content)"></div>
  </div>
</template>
```

### Example 3: Template Preview (Allows CSS)

**File**: `PaperTemplateEdit.vue`

```typescript
<script setup lang="ts">
import { computed } from 'vue'
import { sanitizeTemplate } from '@/utils/sanitize'

const compiledTemplate = ref('')

const previewHtml = computed(() => {
  // Allows style tags for template CSS
  return sanitizeTemplate(compiledTemplate.value)
})
</script>

<template>
  <div class="template-preview" v-html="previewHtml"></div>
</template>
```

---

## Anti-Patterns

### ❌ No Sanitization
```vue
<!-- DANGEROUS - Direct v-html without sanitization -->
<div v-html="userContent"></div>
```

### ❌ Wrong Sanitization Order
```typescript
// Sanitize first, format later = formatting doesn't work
const sanitized = sanitizeHtml(content)
return sanitized.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>')
```

### ❌ Over-Permissive Config
```typescript
// Allows script tags - DANGEROUS
DOMPurify.sanitize(dirty, {
  ALLOWED_TAGS: ['script', 'p', 'div']  // Never allow script!
})
```

### ❌ Wrong Sanitization Level
```typescript
// Using strict sanitization on template preview
// Removes style tags, breaks template CSS
return sanitizeHtml(templateWithCSS)  // Should use sanitizeTemplate()
```

---

## Related Experiences

- **EXP-0047**: Security Scanner False Positive Reduction (cyber-sec-check)
- See also: OWASP A03:2021 - Injection vulnerabilities
- See also: Vue.js Security Best Practices

---

## Best Practices

### 1. Always Sanitize v-html
Never use `v-html` without sanitization in production:
```typescript
// Good
<div v-html="sanitizeHtml(content)"></div>

// Bad
<div v-html="content"></div>
```

### 2. Choose Appropriate Sanitization Level
- **User content** → `sanitizeHtml()` (strict)
- **Templates with CSS** → `sanitizeTemplate()` (allows style)
- **Comments** → `sanitizeBasic()` (minimal tags)
- **Plain text** → `stripHtml()` (no tags)

### 3. Centralize Sanitization Logic
- Single source of truth in `/utils/sanitize.ts`
- Consistent DOMPurify configuration
- Easy to audit and update

### 4. Sanitize After Formatting
```typescript
// Format first (markdown, line breaks, etc.)
const formatted = formatMarkdown(content)

// Sanitize last
return sanitizeHtml(formatted)
```

### 5. Test with Malicious Payloads
```typescript
// Test cases
const tests = [
  '<script>alert("XSS")</script>',
  '<img src=x onerror=alert("XSS")>',
  '<iframe src="javascript:alert(\'XSS\')"></iframe>',
  '<a href="javascript:alert(\'XSS\')">Click</a>'
]

tests.forEach(test => {
  const result = sanitizeHtml(test)
  console.log('Sanitized:', result)  // Should remove malicious code
})
```

---

## Scanner Pattern Update

### Before
```python
# Too broad - flagged JavaScript RegExp.exec()
r"\.exec\("
```

### After
```python
# Excludes JavaScript regex methods
r"(?<!pattern\.)(?<!regex\.)(?<!regexp\.)\.exec\("
```

**Rationale**: JavaScript's `RegExp.exec()` is not a command injection risk. Only system shell `exec()` functions are vulnerable.

---

## Tags

`xss`, `vue`, `dompurify`, `v-html`, `sanitization`, `security`, `owasp`, `injection`, `frontend-security`, `vue3`, `typescript`, `content-security`

---

## Files Changed

```
frontend/src/utils/sanitize.ts                           (NEW)
frontend/src/pages/default/home/BlogOne.vue              (UPDATED)
frontend/src/components/ChatModel.vue                    (UPDATED)
frontend/src/components/AIDemo.vue                       (UPDATED)
frontend/src/pages/default/blog/StaticBlogPost.vue       (UPDATED)
frontend/src/pages/default/admin/products/AdminDisplayProductsSingle.vue (UPDATED)
frontend/src/pages/features/paper/PaperOne.vue           (UPDATED)
frontend/src/pages/features/paper/PaperEditImproved.vue  (UPDATED)
frontend/src/pages/features/paper/PaperTemplateEdit.vue  (UPDATED)
```

---

**Success Metrics**:
- 9/9 XSS vulnerabilities resolved (100%)
- 0 critical security findings
- Template CSS rendering preserved
- AI chat formatting maintained
- Scanner false positive eliminated
- Zero performance degradation

**Reusability**: HIGH - Pattern applicable to all Vue.js projects using v-html
**Documentation Quality**: Complete with examples, anti-patterns, and test cases
