# EXP-0002: Instagram Monitor - CDN Image 429 Rate Limit (Concurrent Requests)

**Project**: Instagram Monitor & Analyzer
**Date**: 2026-02-27
**Category**: Performance / CDN / Caching
**Technologies**: FastAPI, Redis, httpx, Next.js
**Keywords**: 429 rate limit, Instagram CDN, Redis cache, image proxy, concurrent requests, pre-warm

---

## Problem Statement
60+ post aynı anda yüklendiğinde tüm thumbnail istekleri `/api/proxy/image` üzerinden Instagram CDN'e gidiyordu.
Instagram CDN eş zamanlı 10-20'den fazla isteği 429 (Too Many Requests) ile reddediyordu.
Redis cache vardı ama ilk yüklemede (cache MISS) hepsi CDN'e gidiyordu.

## Root Cause
**İki katmanlı sorun:**
1. İlk yüklemede cache boş → tüm resimler aynı anda CDN'e istek atar
2. Redis cache sadece proxy endpoint'te vardı (view time), fetch time'da yoktu

## Solution

### Katman 1: Redis Binary Cache (7 gün TTL)
```python
# image_cache_service.py
IMAGE_CACHE_TTL = 604800  # 7 gün
_DOWNLOAD_DELAY = 0.3    # CDN rate limit'e karşı

async def warm(url: str) -> bool:
    """Download & cache image in Redis"""
    if await is_cached(url):
        return True
    async with httpx.AsyncClient() as client:
        resp = await client.get(url, headers=_CDN_HEADERS)
        if resp.status_code == 200:
            await _store(url, resp.content, content_type)
    return True

async def warm_many(urls: list[str]) -> dict:
    """Sequential download with delay to avoid CDN rate limit"""
    for url in urls:
        await warm(url)
        await asyncio.sleep(_DOWNLOAD_DELAY)
```

### Katman 2: Pre-warm at Fetch Time (instagram_client.py)
```python
# Post/reel kaydedildiğinde thumbnail'ı hemen cache'le
if thumbnail_url:
    asyncio.create_task(warm_image(thumbnail_url))
```

### Katman 3: Admin Backfill Endpoint
```python
@router.post("/admin/warm-image-cache")
async def warm_image_cache():
    """Mevcut tüm post/reel thumbnail'larını cache'le"""
    posts = await posts_col.find({}, {"post_thumbnail_url": 1}).to_list(None)
    urls = [p["post_thumbnail_url"] for p in posts if p.get("post_thumbnail_url")]
    asyncio.create_task(warm_many(urls))  # Background task
    return {"message": f"Warming {len(urls)} images"}
```

### Redis Key Format
```python
def cache_key(url: str) -> str:
    return f"imgproxy:{hashlib.md5(url.encode()).hexdigest()}"
```

## Lessons Learned
- Instagram CDN'de `oe=` parametresi URL expiry date — URL'ler expire olabilir, cache key URL bazlı hash kullan
- Cache sadece proxy'de olması yetmez; **data fetch time'da pre-warm** et
- Sequential download (0.3s delay) CDN 429'u önler ama hız azalır
- Admin backfill endpoint'i olmadan mevcut data için cache doldurulamaz
- `asyncio.create_task()` ile fire-and-forget: response'u bekletmeden background'da warm yap
- CDN headers kritik: `Referer: https://www.instagram.com/` olmadan 403

## CDN Headers (Zorunlu)
```python
_CDN_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Macintosh; ...) Chrome/121.0.0.0 Safari/537.36",
    "Referer": "https://www.instagram.com/",
    "Origin": "https://www.instagram.com",
    "Sec-Fetch-Dest": "image",
    "Sec-Fetch-Mode": "no-cors",
    "Sec-Fetch-Site": "same-site",
}
```

## Prevention Checklist
- [ ] Harici CDN'den resim yüklerken: her zaman Redis cache katmanı ekle
- [ ] Cache pre-warming: data save time'da yap, view time'da değil
- [ ] Bulk image load durumunda: sequential + delay, concurrent değil
- [ ] Admin backfill endpoint: production'a ilk deploy'da çağır
- [ ] X-Cache: HIT/MISS header ekle → debugging kolaylaşır
