# EXP-0074: Remotion + Next.js execSync Deadlock

**Date:** 2026-01-26
**Project:** Video Uretmece (Electron + Next.js + Remotion)
**Category:** API Route / Async Patterns
**Status:** SUCCESS

## Problem

Remotion render API route'dan cagrildiginda timeout oluyor, ama CLI'dan direkt calisiyor.

### Belirtiler

1. `"A delayRender() was called but not cleared after 118000ms"`
2. `"Tried to download file ... but the server sent no data for 20 seconds"`
3. Video API endpoint'i curl ile test edildiginde calisiyor
4. Next.js server donuyor (hang)

## Root Cause Analysis

`execSync` kullanimi Next.js'in event loop'unu blokluyor.

**Senaryo:**
1. API route `/api/render` cagrilir
2. `execSync("npx remotion render ...")` calistirilir
3. Remotion, video dosyalarini `/api/footage/stream` endpoint'inden fetch etmeye calisir
4. AMA Next.js ana thread'i `execSync` tarafindan bloklandi
5. `/api/footage/stream` cevap veremiyor
6. **DEADLOCK** - Remotion bekliyor, Next.js bekliyor

```
Client --> /api/render --> execSync (BLOK!)
                              |
                              v
                         Remotion CLI
                              |
                              v
                     fetch /api/footage/stream
                              |
                              X (Next.js bloklu, cevap yok!)
```

## Solution

`execSync` yerine `spawn` + Promise wrapper kullan:

```typescript
import { spawn } from 'child_process';

const runCommand = (
  cmd: string,
  args: string[],
  options: { cwd?: string; timeout?: number }
): Promise<{ stdout: string; stderr: string }> => {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, {
      cwd: options.cwd,
      shell: true,
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    let stdout = '';
    let stderr = '';

    child.stdout?.on('data', (data) => {
      stdout += data.toString();
    });

    child.stderr?.on('data', (data) => {
      stderr += data.toString();
    });

    const timer = options.timeout
      ? setTimeout(() => {
          child.kill('SIGKILL');
          reject(new Error(`Command timed out after ${options.timeout}ms`));
        }, options.timeout)
      : null;

    child.on('exit', (code) => {
      if (timer) clearTimeout(timer);
      if (code === 0) {
        resolve({ stdout, stderr });
      } else {
        reject(new Error(`Command failed with code ${code}: ${stderr}`));
      }
    });

    child.on('error', (err) => {
      if (timer) clearTimeout(timer);
      reject(err);
    });
  });
};

// Kullanim
const { stdout } = await runCommand(
  'npx',
  ['remotion', 'render', '--codec', 'h264', ...otherArgs],
  { cwd: projectPath, timeout: 300000 }
);
```

## Related Issues (Same Session)

### 1. Custom Template Eksik
**Problem:** Remotion composition registry'de "Custom" yoktu
**Cozum:** `src/Root.tsx`'e `<Composition id="Custom" ... />` eklendi

### 2. URL Parsing Sorunu
**Problem:** `isVideo()` fonksiyonu URL query params'i duzgun parse edemiyordu
**Cozum:** URL parsing logic'i duzeltildi

### 3. Port Yanlisligi
**Problem:** Hardcoded `localhost:3000` kullaniliyordu
**Cozum:** `localhost:3176` (proje portu) kullanildi

### 4. CORS Headers Eksik
**Problem:** Puppeteer/Remotion erisimleri icin CORS headers yoktu
**Cozum:** API route'lara CORS headers eklendi:
```typescript
return new Response(stream, {
  headers: {
    'Content-Type': contentType,
    'Accept-Ranges': 'bytes',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
    'Access-Control-Allow-Headers': '*',
  },
});
```

## Key Learnings

### 1. API Route'larda execSync KULLANMA
Event loop'u bloklar. Eger API route kendi server'indan bir sey fetch ediyorsa, deadlock olusur.

### 2. Self-Referential API Calls
Bir API route, ayni server'daki baska bir API route'u cagiriyorsa:
- Blocking call (execSync) = DEADLOCK
- Non-blocking call (spawn/fetch) = OK

### 3. Test Stratejisi
CLI'dan calisiyor AMA API'den calismiyorsa:
- **blocking/async** sorununa bak
- **self-referential** call var mi kontrol et
- Timeout mesajlarini dikkatlice oku

### 4. Remotion + Next.js Entegrasyonu
- Remotion CLI baska processte calisir
- Bu process, Next.js'ten asset fetch edebilir
- Next.js'in event loop'u acik olmali

## Detection Pattern

Bu sorunu tespit etmek icin:

```bash
# 1. CLI'dan test et
npx remotion render src/index.ts Custom out.mp4

# 2. API'den test et
curl -X POST http://localhost:3176/api/render -d '{"template":"Custom"}'

# Eger 1 calisiyor ama 2 timeout aliyorsa -> Bu sorun!
```

## Prevention Checklist

- [ ] API route'larda `execSync`, `spawnSync` var mi?
- [ ] Bu sync call, ayni server'dan fetch yapiyor mu?
- [ ] Eger evet -> `spawn` + Promise'e cevir
- [ ] Timeout ayarla (300000ms = 5 dakika video render icin makul)

## Files Changed

1. `vy-web/app/api/render/route.ts` - execSync -> spawn
2. `vy-web/app/api/footage/stream/route.ts` - CORS headers
3. `vy-web/src/Root.tsx` - Custom composition eklendi

## Related Experiences

- [EXP-0015](EXP-0015-odtu-cv-processing-timeout.md) - CV Processing Timeouts (circuit breaker pattern)
- [EXP-0023](EXP-0023-odtu-events-api-error.md) - Async MongoDB patterns

## Tags

`remotion`, `nextjs`, `electron`, `execsync`, `deadlock`, `async`, `spawn`, `api-route`, `video-rendering`, `event-loop`, `cors`, `self-referential-api`
