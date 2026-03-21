# EXP-0094: Resmi Gazete Scraper — CSS Selectors & Windows-1254 Encoding

## Metadata
- **Date**: 2026-02-28
- **Project**: resmigazete (Resmi Gazete Bulten Platform)
- **Severity**: HIGH (without this, scraper returns empty)
- **Category**: Web Scraping, Encoding
- **Status**: SOLVED

## Problem Statement
resmigazete.gov.tr scraping fails with empty results or encoding garbage (â€™, Ã¶, ÅŸ etc.) despite the site being accessible. Standard UTF-8 decoding produces garbled Turkish characters.

## Root Cause
1. resmigazete.gov.tr uses **Windows-1254** encoding (Turkish Windows code page), NOT UTF-8
2. CSS selectors changed over time — outdated selectors (`div.fihrist-item > a`) return empty
3. Gazette issue number lives in `span#spanGazeteTarih`, NOT in article text
4. The `_id` field for MongoDB must be YYYYMMDD string format (e.g. "20260228"), not datetime

## Solution

### Correct CSS Selectors (as of 2026-02)
```python
# Index page selectors
SECTION_SELECTOR = 'div.card-title.html-title'      # Top-level sections
SUBSECTION_SELECTOR = 'div.html-subtitle'            # Sub-sections
ARTICLE_SELECTOR = 'div.fihrist-item.mb-1 > a'      # Individual articles

# Gazette number (NOT from article text!)
GAZETTE_NUMBER_SELECTOR = 'span#spanGazeteTarih'
```

### Correct Encoding
```python
import requests

response = requests.get(url)
response.encoding = 'windows-1254'   # CRITICAL: must set BEFORE .text
content = response.text              # Now Turkish chars work: ş, ğ, ü, ö, ç, ı

# Alternative with BeautifulSoup
from bs4 import BeautifulSoup
soup = BeautifulSoup(response.content, 'html.parser', from_encoding='windows-1254')
```

### MongoDB _id Format
```python
# CORRECT: YYYYMMDD string
gazette_doc = {
    "_id": "20260228",   # string, NOT datetime
    "date": "2026-02-28",
    "gazette_number": "32456",
    ...
}

# WRONG: datetime object as _id — causes query issues
gazette_doc = {"_id": datetime(2026, 2, 28)}  # DON'T DO THIS
```

### URL Pattern
```
# Index page
https://www.resmigazete.gov.tr/eskiler/YYYY/MM/YYYYMMDD.htm

# Article pages
https://www.resmigazete.gov.tr/eskiler/YYYY/MM/YYYYMMDD-N.htm
# N = article number (1, 2, 3...)
```

## Verification
```python
# Test scraper
from app.content.scraper import scrape_daily_index
result = scrape_daily_index("20260228")
assert result is not None
assert len(result['articles']) > 0
assert 'ş' in str(result)  # Turkish chars working
assert result['_id'] == "20260228"
print(f"Scraped {len(result['articles'])} articles")
```

## Applicable To
- Any project scraping resmigazete.gov.tr
- Any Turkish government site (many use Windows-1254)
- BeautifulSoup projects with Turkish content encoding issues

## Lessons Learned
1. **Always check encoding first** when scraping Turkish sites — Windows-1254 is common in older government sites
2. **Gazette number != article count** — it's a unique publication ID from `span#spanGazeteTarih`
3. **Use string _id for date-keyed MongoDB docs** — easier querying, no timezone issues
4. **Inspect actual HTML** — selector docs go stale; always verify with browser DevTools before coding
5. `response.encoding = 'windows-1254'` must be set BEFORE accessing `response.text`

## Related Experiences
- EXP-0095: MongoDB Motor async import trap (same project)
- EXP-0096: Celery + AsyncIO pattern (same project)

## Tags
`scraping` `encoding` `windows-1254` `turkish` `beautifulsoup` `mongodb` `resmigazete`
