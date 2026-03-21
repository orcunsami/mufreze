# EXP-0078: Vue-i18n Translation Path Mismatch

## Metadata
| Field | Value |
|-------|-------|
| **Experience ID** | EXP-0078 |
| **Project** | HocamClass |
| **Task ID** | HCLASS-41 |
| **Date** | 2026-02-01 |
| **Category** | Frontend/Internationalization |
| **Technologies** | Vue.js 3, vue-i18n, TypeScript |
| **Status** | SUCCESS |
| **Time Spent** | 20 minutes |

---

## Problem Description

Translation keys in Vue components are not resolving - showing raw key strings instead of translated text. The component uses `t('quickUpload.title')` but the translation file has a nested structure.

### Symptom
```vue
<template>
  <h1>{{ t('quickUpload.title') }}</h1>
</template>
<!-- Renders as: "quickUpload.title" instead of "Quick Upload" -->
```

### Translation File Structure
```json
{
  "en": {
    "notes": {
      "quickUpload": {
        "title": "Quick Upload",
        "description": "Upload your notes easily"
      }
    }
  }
}
```

### Root Cause
The translation path in the component (`quickUpload.title`) does not match the full path in the JSON structure (`notes.quickUpload.title`).

When using `useI18n()` with local scope or loading translations from a structured JSON file, the translation key must include the complete path from the JSON root.

---

## Solution

### Correct Usage
```vue
<script setup lang="ts">
import { useI18n } from 'vue-i18n'

const { t } = useI18n()
</script>

<template>
  <!-- Use full path from JSON root -->
  <h1>{{ t('notes.quickUpload.title') }}</h1>
  <p>{{ t('notes.quickUpload.description') }}</p>
</template>
```

### Alternative: Use Local Messages
If you want shorter keys, define messages locally in the component:

```vue
<script setup lang="ts">
import { useI18n } from 'vue-i18n'

const { t } = useI18n({
  messages: {
    en: {
      title: 'Quick Upload',
      description: 'Upload your notes easily'
    },
    tr: {
      title: 'Hizli Yukleme',
      description: 'Notlarinizi kolayca yukleyin'
    }
  }
})
</script>

<template>
  <h1>{{ t('title') }}</h1>
</template>
```

---

## Debugging Checklist

1. **Check JSON Structure**: Open the translation JSON and trace the full path
2. **Console Log**: Use `console.log(t('key'))` to see what's being returned
3. **Vue DevTools**: Check the i18n state in Vue DevTools
4. **Path Verification**: Count nesting levels in JSON vs. key in component

### Path Verification Example
```
JSON: { "en": { "notes": { "quickUpload": { "title": "..." } } } }
                   ^          ^             ^
                   1          2             3

Key must be: notes.quickUpload.title (all 3 levels)
NOT: quickUpload.title (missing "notes" level)
```

---

## Patterns Applied
- `vue-i18n-configuration`: Understanding scope and message structure
- `translation-key-resolution`: Full path matching

---

## Prevention Checklist
- [ ] Always check JSON structure before writing translation keys
- [ ] Use consistent nesting patterns across all translation files
- [ ] Add type-safety for translation keys (see vue-i18n typed keys)
- [ ] Create a translation key constant file for autocomplete

---

## Related Experiences
- [EXP-0028](EXP-0028-odtu-nextjs-i18n-switching.md): Next.js i18n Language Switching
- [EXP-0036](EXP-0036-yenizelanda-reactservercomponentserror-i18n-fix.md): ReactServerComponentsError i18n Fix

---

## Tags
`vue-i18n`, `translation`, `i18n`, `vue.js`, `internationalization`, `path-mismatch`, `useI18n`, `json-structure`
