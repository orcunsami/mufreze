# EXP-0103: App Store Legal Compliance — Privacy Policy, Terms & Registration Checkbox

## Metadata
- **Date**: 2026-02-28
- **Project**: HocamKariyer Mobile (Jira MAC-134, MAC-135, MAC-136)
- **Severity**: CRITICAL (App Store REJECTS without this)
- **Category**: Mobile Compliance, App Store, Legal, React Native
- **Status**: SOLVED

## Problem Statement
Mobile app rejected by App Store review: missing terms of service acceptance in registration flow. Legal pages either missing entirely or opened with `Alert.alert()` instead of actual browser. Registration button had no terms checkbox — users could register without accepting terms.

## Three Required Components

### 1. Web Legal Pages (Next.js / Any Web Framework)
```tsx
// pages/gizlilik-politikasi.tsx (Turkish Privacy Policy)
export default function PrivacyPolicyPage() {
  return (
    <div className="max-w-4xl mx-auto px-4 py-12">
      <h1>Gizlilik Politikasi</h1>
      <p>Son guncelleme: 1 Subat 2026</p>

      {/* Required sections for Turkish law (KVKK) + GDPR */}
      <h2>1. Toplanan Veriler</h2>
      <h2>2. Verilerin Kullanimi</h2>
      <h2>3. Verilerin Paylasilmasi</h2>
      <h2>4. Veri Saklama Suresi</h2>
      <h2>5. Kullanici Haklari</h2>
      <h2>6. Iletisim</h2>
    </div>
  )
}

// pages/kullanim-kosullari.tsx (Turkish Terms of Service)
// Similar structure with: Kabul, Hizmet Tanimi, Kullanici Yukumlulukleri, Sorumluluk, Fesih
```

```tsx
// Footer.tsx — add legal links
<footer>
  <Link href="/gizlilik-politikasi">Gizlilik Politikasi</Link>
  <Link href="/kullanim-kosullari">Kullanim Kosullari</Link>
</footer>
```

### 2. Mobile Legal Links — expo-web-browser (NOT Alert.alert!)
```tsx
// mobile/app/(auth)/register.tsx — WRONG
import { Alert } from 'react-native'

<Text onPress={() => Alert.alert("Gizlilik Politikasi", "...")}>
  Gizlilik Politikasi  {/* Shows alert popup — NOT acceptable for App Store */}
</Text>

// CORRECT: Open actual URL in in-app browser
import * as WebBrowser from 'expo-web-browser'

const PRIVACY_URL = "https://your-domain.com/gizlilik-politikasi"
const TERMS_URL = "https://your-domain.com/kullanim-kosullari"

<Text onPress={() => WebBrowser.openBrowserAsync(PRIVACY_URL)}>
  Gizlilik Politikasi
</Text>
```

### 3. Registration Checkbox (App Store REQUIRES this)
```tsx
// mobile/app/(auth)/register.tsx
import { useState } from 'react'
import * as WebBrowser from 'expo-web-browser'

export default function RegisterScreen() {
  const [termsAccepted, setTermsAccepted] = useState(false)
  const [termsError, setTermsError] = useState('')

  const handleRegister = async () => {
    if (!termsAccepted) {
      setTermsError('Devam etmek icin kosullari kabul etmelisiniz.')
      return
    }
    // Proceed with registration...
  }

  return (
    <View>
      {/* Registration form fields... */}

      {/* Terms checkbox */}
      <View style={styles.checkboxRow}>
        <TouchableOpacity
          style={[styles.checkbox, termsAccepted && styles.checkboxChecked]}
          onPress={() => {
            setTermsAccepted(!termsAccepted)
            setTermsError('')
          }}
        >
          {termsAccepted && <Text style={styles.checkmark}>v</Text>}
        </TouchableOpacity>

        <Text style={styles.termsText}>
          <Text onPress={() => WebBrowser.openBrowserAsync(TERMS_URL)}>
            Kullanim Kosullari
          </Text>
          {" "}ve{" "}
          <Text onPress={() => WebBrowser.openBrowserAsync(PRIVACY_URL)}>
            Gizlilik Politikasi
          </Text>
          {'ni okudum ve kabul ediyorum.'}
        </Text>
      </View>

      {termsError ? <Text style={styles.error}>{termsError}</Text> : null}

      {/* DISABLED until terms accepted */}
      <TouchableOpacity
        style={[styles.button, !termsAccepted && styles.buttonDisabled]}
        onPress={handleRegister}
        disabled={!termsAccepted}
      >
        <Text>Kayit Ol</Text>
      </TouchableOpacity>
    </View>
  )
}
```

## App Store Review Checklist
- [ ] Privacy Policy URL in App Store Connect settings
- [ ] Privacy Policy accessible WITHOUT logging in (public URL)
- [ ] Terms of Service URL in App Store Connect settings
- [ ] Registration checkbox that links to both documents
- [ ] Checkbox required (button disabled until accepted)
- [ ] Legal pages open in browser (not Alert), accessible from app

## GDPR / KVKK Requirements (Turkish)
Turkish apps must also comply with KVKK (Kisisel Verilerin Korunmasi Kanunu):
- List all data collected with legal basis
- State retention periods
- Include explicit user rights (access, deletion, correction)
- Contact info for DPO (Data Protection Officer)

## Applicable To
- ALL mobile apps submitted to App Store / Google Play
- Turkish apps (KVKK compliance required)
- Any app collecting user data (email, name, etc.)

## Lessons Learned
1. **App Store WILL REJECT** without visible terms acceptance checkbox in registration
2. **`Alert.alert()` is wrong** for legal docs — must open real URLs
3. **Button disabled until checked** is the correct UX — not just validation on submit
4. **Privacy page must be public** (no login required) — App Store reviewers check this
5. **Turkish apps need KVKK** sections in addition to standard GDPR content
6. Add legal links to Footer on ALL pages, not just registration

## Related Experiences
- EXP-0091: iOS EAS Build & TestFlight (same project)
- EXP-0092: Full VPS Deployment (same project)

## Tags
`app-store` `compliance` `privacy` `terms` `react-native` `expo` `kvkk` `gdpr` `mobile` `legal`
