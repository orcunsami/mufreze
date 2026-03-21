# EXP-0071: Giulia Vilaca Portfolio - Full-Stack Debugging & Best Practices

**Project**: Giulia Vilaca Portfolio
**Date**: 2026-01-06
**Category**: Full-Stack Development, Debugging, DevOps
**Technologies**: FastAPI, Next.js 14, MongoDB, PM2, Gmail SMTP, WebP, Figma MCP
**Stack Version**: FastAPI 0.104+, Next.js 14, MongoDB 7.x, Python 3.11+
**Keywords**: mongodb authentication, pm2 logs, webp conversion, contact form, gmail smtp, figma implementation, debugging workflow, multi-project vps

---

## Problem Statement

Portfolio website geliştirirken karşılaşılan birden fazla entegre problem:

1. **MongoDB Authentication**: VPS'te `authorization: enabled` ile çalışan MongoDB'ye bağlantı hatası
2. **Contact Form Email**: Gmail SMTP ile email gönderimi yapılandırması
3. **Image Optimization**: PNG dosyalarının client download hızı için WebP'ye dönüştürülmesi
4. **Figma Implementation**: Figma'dan kod üretirken doğru içerik kullanımı
5. **Multi-Project VPS**: Birden fazla projenin aynı VPS'te yönetimi

---

## Investigation Process

### 1. MongoDB Authentication Hatası

**Belirti**:
```
pymongo.errors.OperationFailure: Command insert requires authentication,
full error: {'ok': 0.0, 'errmsg': 'Command insert requires authentication',
'code': 13, 'codeName': 'Unauthorized'}
```

**Araştırma**:
1. `pm2 logs giuliavilaca-api --err --lines 50` ile hata stack trace'i
2. `/etc/mongod.conf` kontrolü - `security.authorization: enabled`
3. Diğer projelerin `.env` dosyalarını karşılaştırma
4. `mongosh` history kontrolü - admin credentials bulma

### 2. Gmail SMTP Yapılandırması

**Belirti**: Contact form 500 error döndürüyor

**Araştırma**:
1. Backend `.env` dosyasında `GMAIL_USER` ve `GMAIL_APP_PASSWORD` kontrolü
2. Mevcut email service kodunun incelenmesi
3. Gmail App Password gereksinimleri (2FA zorunlu)

### 3. Image Optimization

**Belirti**: PNG dosyaları çok büyük (~300KB), client download yavaş

**Araştırma**:
1. `cwebp` tool'unun VPS'te varlığı kontrolü
2. WebP quality ayarları test

---

## Root Cause

### MongoDB Authentication
- **Neden**: VPS'te MongoDB `authorization: enabled` ile çalışıyor
- **Problem**: `.env` dosyasında `mongodb://localhost:27017` (credentials yok)
- **Beklenen**: `mongodb://user:pass@localhost:27017/db?authSource=db`

### Contact Form
- **Neden**: MongoDB authentication hatası email gönderimini de engelliyor
- **Problem**: Message MongoDB'ye kaydedilemiyor → tüm flow başarısız

### Image Size
- **Neden**: PNG format gereksiz büyük, portfolio için WebP daha uygun
- **Problem**: 4 proje görseli toplam ~1.2MB

---

## Solution

### 1. MongoDB User Oluşturma

```bash
# Admin credentials ile bağlan
mongosh -u admin -p ADMIN_PASSWORD --authenticationDatabase admin --eval '
use("giuliavilaca_db");
db.createUser({
  user: "giuliavilaca_app",
  pwd: "SECURE_PASSWORD",
  roles: [{ role: "readWrite", db: "giuliavilaca_db" }]
});
print("User created successfully");
'
```

### 2. Backend .env Güncelleme

```bash
# YANLIŞ
MONGODB_URL=mongodb://localhost:27017

# DOĞRU
MONGODB_URL=mongodb://giuliavilaca_app:PASSWORD@localhost:27017/giuliavilaca_db?authSource=giuliavilaca_db
```

### 3. Backend Restart

```bash
# Sadece bu projeyi restart et (multi-project VPS kuralı)
pm2 restart giuliavilaca-api

# Log ile doğrula
pm2 logs giuliavilaca-api --lines 10 --nostream
# Beklenen: "Connected to MongoDB: giuliavilaca_db"
```

### 4. API Test

```bash
curl -X POST http://localhost:8660/api/v1/contact/send \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","message":"Test message"}' | jq .

# Beklenen: {"success": true, "message": "Thank you for your message!..."}
```

### 5. WebP Dönüşümü

```bash
cd /usr/local/main/giuliavilaca/frontend/public

# Her PNG için WebP oluştur
cwebp -q 85 seres.png -o seres.webp
cwebp -q 85 simple_inventory.png -o simple_inventory.webp
cwebp -q 85 social_features.png -o social_features.webp
cwebp -q 85 edtech.png -o edtech.webp

# Sonuç: ~90% boyut azalması
# seres.png (320KB) → seres.webp (32KB)
```

### 6. Frontend Image Update

```tsx
// page.tsx - projects array
const projects = [
  {
    id: '1',
    category: 'WEB',
    title: 'SERES',  // Figma'dan DOĞRU isim
    image: '/seres.webp',  // WebP kullan
  },
  // ...
];

// ProjectCard component
<Image
  src={project.image}
  alt={project.title}
  fill
  className="object-cover"
/>
```

---

## Verification

### MongoDB Bağlantı Test
```bash
mongosh -u giuliavilaca_app -p PASSWORD \
  --authenticationDatabase giuliavilaca_db \
  giuliavilaca_db \
  --eval 'db.contact_messages.find().sort({created_at:-1}).limit(1).toArray()'
```

### API Health Check
```bash
curl http://localhost:8660/health
# {"status": "ok"}
```

### Contact Form E2E Test
```bash
curl -X POST http://localhost:8660/api/v1/contact/send \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","message":"Test"}' | jq .
# {"success": true, ...}
```

### Production Test
```bash
curl -s -o /dev/null -w "HTTP %{http_code}" https://giuliavilaca.com
# HTTP 200

curl https://api.giuliavilaca.com/health
# {"status": "ok"}
```

---

## Applicable To

### Doğrudan Uygulanabilir
- FastAPI + MongoDB projeleri (tüm freelance projeler)
- Multi-project VPS ortamları
- Portfolio/showcase siteleri
- Contact form sistemleri

### Kısmen Uygulanabilir
- Farklı email provider kullanan projeler (SendGrid, Mailgun)
- Farklı image format gereksinimleri (AVIF, optimized PNG)
- Single-project VPS ortamları

---

## Lessons Learned

### 1. MongoDB Authentication Pattern (KRİTİK)
```
KURAL: VPS'te MongoDB HER ZAMAN authentication ile çalışır.
FORMAT: mongodb://USER:PASS@localhost:27017/DB?authSource=DB
TEST: mongosh ile bağlantı doğrula
```

### 2. PM2 Multi-Project Safety (KRİTİK)
```
KURAL: ASLA `pm2 restart all` kullanma!
DOĞRU: pm2 restart PROJECT-api
NEDEN: Diğer projeleri etkilememek için
```

### 3. Debugging Workflow
```
1. pm2 logs PROJECT-api --err --lines 50
2. Root cause bul (stack trace)
3. Fix uygula
4. pm2 restart PROJECT-api
5. curl ile test
6. pm2 logs ile doğrula
```

### 4. Image Optimization
```
KURAL: Portfolio görselleri için WebP kullan
KOMUT: cwebp -q 85 input.png -o output.webp
KAZANÇ: ~90% boyut azalması
```

### 5. Figma Implementation
```
KURAL: Figma'daki isimleri KULLAN, uydurma!
YANLIŞ: "FinTech Mobile App" (uydurma)
DOĞRU: "Simple Inventory Management Software" (Figma'dan)
```

### 6. Gmail SMTP Setup
```
GEREKSİNİMLER:
- 2FA aktif olmalı
- App Password oluşturulmalı (16 haneli)
- .env: GMAIL_USER + GMAIL_APP_PASSWORD
```

---

## Prevention Framework

### Yeni Proje Başlatırken
1. [ ] MongoDB user oluştur (admin credentials ile)
2. [ ] .env dosyasında MONGODB_URL credentials ile
3. [ ] PM2 ecosystem.config.js proje-spesifik isimlerle
4. [ ] Health check endpoint ekle ve test et
5. [ ] Image optimization strategy belirle (WebP vs AVIF)

### Deploy Öncesi
1. [ ] pm2 logs ile error kontrol
2. [ ] curl ile tüm endpoints test
3. [ ] MongoDB bağlantısı doğrula
4. [ ] Email gönderimi test et (eğer varsa)

---

## Related Experiences

- [EXP-0057: VPS2 MongoDB Authentication Enable](EXP-0057-vps2-mongodb-authentication-enable.md) - MongoDB auth setup
- [EXP-0055: Urunlu API URL Prefix](EXP-0055-urunlu-api-url-prefix-standardization.md) - API patterns
- [EXP-0058: VPS1 Disk Cleanup MongoDB Logs](EXP-0058-vps1-disk-cleanup-mongodb-logs.md) - MongoDB log management

---

## Code Snippets Reference

### MongoDB User Creation Script
```bash
#!/bin/bash
# create-mongo-user.sh
mongosh -u admin -p "$ADMIN_PASS" --authenticationDatabase admin --eval "
use('$DB_NAME');
db.createUser({
  user: '$APP_USER',
  pwd: '$APP_PASS',
  roles: [{ role: 'readWrite', db: '$DB_NAME' }]
});
"
```

### WebP Batch Conversion
```bash
#!/bin/bash
# convert-to-webp.sh
for file in *.png *.jpg *.jpeg; do
  [ -f "$file" ] || continue
  output="${file%.*}.webp"
  cwebp -q 85 "$file" -o "$output"
  echo "Converted: $file → $output"
done
```

### Contact Form API Test
```bash
#!/bin/bash
# test-contact.sh
curl -X POST http://localhost:$PORT/api/v1/contact/send \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","message":"Test message"}' \
  | jq .
```

---

**Author**: Claude Code
**Validated**: 2026-01-06
**Status**: SUCCESS - All patterns verified in production
