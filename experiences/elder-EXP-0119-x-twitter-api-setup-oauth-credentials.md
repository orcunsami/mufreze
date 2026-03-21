# EXP-0119 — X (Twitter) API Kurulumu: OAuth Credential Karmaşası

**Tarih**: 2026-03-02
**Proje**: Bültenim AI (resmigazete)
**Süre**: ~2 saat
**Sonuç**: Çözüldü — tweet atma çalışıyor

---

## Problem

Twitter/X API kurulumu yaparken 3 farklı credential tipi var ve bunlar karıştırılıyor.
Developer console'da "regenerate" yapınca hangi credential'ın değiştiği belirsiz.
401 Unauthorized hatası alındı, sebebi yanlış credential kullanımıydı.

---

## Kök Neden

X developer console'da 3 ayrı credential sistemi var:

| Tip | Kullanım | Alanlar |
|-----|----------|---------|
| OAuth 1.0a Consumer Keys | Bot kendi hesabından tweet atar | API Key + API Key Secret |
| OAuth 1.0a Auth Tokens | Bot hesabının izni | Access Token + Access Token Secret |
| OAuth 2.0 Client | Kullanıcılar app'e login olur | Client ID + Client Secret |
| Bearer Token | Sadece okuma (app-only) | Bearer Token |

**Kritik Fark**:
- Tweet ATMAK için: OAuth 1.0a Consumer Key/Secret + Access Token/Secret (4 değer)
- Tweet OKUMAK için: sadece Bearer Token yeterli
- OAuth 2.0 Client ID/Secret: kullanıcı login akışı için, bot tweet atmak için KULLANILMAZ

---

## Yaşanan Hatalar

1. **403 Forbidden** → App permissions "Read only" idi, "Read and Write" yapılmadı
2. **401 Unauthorized** → Permissions değişince Access Token geçersiz oldu, regenerate gerekti
3. **Yanlış credential**: OAuth 2.0 Client Secret, OAuth 1.0a API Secret sanıldı → çalışmadı
4. **Consumer Key regenerate** sonrası Access Token da geçersiz → ikisi birlikte yenilenecek

---

## Doğru Kurulum Sırası

```
1. console.x.com → Apps → [App] → Settings
   → App permissions: "Read and Write" seç
   → Type of App: "Web App, Automated App or Bot" seç
   → Callback URI: https://siteadresi.com (zorunlu, boş bırakılırsa Save aktif olmaz)
   → Website URL: https://siteadresi.com (zorunlu)
   → Save Changes

2. Keys and Tokens sekmesi → Consumer Keys → Regenerate
   → API Key (Consumer Key) kaydet
   → API Key Secret (Consumer Secret) kaydet

3. Keys and Tokens → Access Token and Secret → Regenerate
   → Access Token kaydet
   → Access Token Secret kaydet

4. Bearer Token → Regenerate (opsiyonel, sadece okuma için lazımsa)
```

---

## .env Yapısı (Doğru)

```bash
# OAuth 1.0a — Bot tweet atmak için (4 değer zorunlu)
TWITTER_API_KEY=<Consumer Key>
TWITTER_API_SECRET=<Consumer Key Secret>
TWITTER_BOT_ACCESS_TOKEN=<Access Token>
TWITTER_BOT_ACCESS_TOKEN_SECRET=<Access Token Secret>

# Bearer Token — Sadece okuma
TWITTER_BEARER_TOKEN=<Bearer Token>

# OAuth 2.0 — Kullanıcı login akışı (bot için KULLANILMAZ)
TWITTER_OAUTH2_CLIENT_ID=<Client ID>
TWITTER_OAUTH2_CLIENT_SECRET=<Client Secret>
```

---

## Tweepy Kullanımı

```python
import tweepy

# Tweet ATMAK için (OAuth 1.0a)
client = tweepy.Client(
    consumer_key=settings.TWITTER_API_KEY,
    consumer_secret=settings.TWITTER_API_SECRET,
    access_token=settings.TWITTER_BOT_ACCESS_TOKEN,
    access_token_secret=settings.TWITTER_BOT_ACCESS_TOKEN_SECRET,
)
resp = client.create_tweet(text="Tweet metni")
tweet_id = resp.data["id"]

# Tweet OKUMAK için (Bearer Token yeterli, ucuz)
reader = tweepy.Client(bearer_token=settings.TWITTER_BEARER_TOKEN)
user = reader.get_user(username="kullanici_adi")
tweets = reader.get_users_tweets(user.data.id, max_results=10)
```

---

## Fiyatlandırma (Pay-per-use, 2026)

| İşlem | Endpoint | Maliyet |
|-------|----------|---------|
| Tweet oku | GET /2/tweets | $0.005/post |
| User oku | GET /2/users | $0.01/user |
| Tweet at | POST /2/tweets | $0.01/request |
| DM | - | $0.01/event |

**Bot maliyeti**: Günde 7 tweet = $0.07 → Ayda ~$2.10

---

## Dikkat

- `client.get_me()` çağrısı arka planda 100 post çekebilir → $0.50 beklenmedik maliyet
- Permissions değişince Access Token + Consumer Key birlikte yenilenmeli
- developer.twitter.com → developer.x.com (yönlendirme var ama console.x.com kullan)
- Free tier'da write-only var (500 tweet/ay), ama permissions sorunlu → Pay-per-use önerilir

---

## Görsel Tweet (Güncelleme 2026-03-02)

Tweepy ile görsel tweet atma:

```python
# v1.1 API (media upload için şart)
auth = tweepy.OAuth1UserHandler(api_key, api_secret, access_token, access_token_secret)
api_v1 = tweepy.API(auth)

# Görsel yükle
media = api_v1.media_upload("/path/to/image.png")

# Tweet'e ekle (sadece ilk tweet'e, media_ids liste olmalı)
client.create_tweet(text="...", media_ids=[media.media_id])
```

- `media_ids` parametre list bekler: `[media_id]`
- Görsel upload ücretsiz, sadece create_tweet $0.01
- Thread'de sadece ilk tweet'e görsel eklenir (i == 0)
- Pillow ile üretilen local PNG direkt upload edilebilir
