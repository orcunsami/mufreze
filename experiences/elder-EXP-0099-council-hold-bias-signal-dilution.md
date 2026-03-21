# EXP-0099: Council HOLD Bias — Probabilistic Voting Signal Dilution

## Metadata
- **Proje**: Borsa Trading Team
- **Tarih**: 2026-02-28
- **Kategori**: Trading Engine, Council System, Voting
- **Durum**: DIAGNOSED (Partial Fix)
- **JIRA**: -

## Problem

Stratejiler "viable", daemon aktif, OHLCV fresh — ama trade yok. Daemon council kararı: `HOLD confidence=0.3, score=0`. Bot-filtered trade rate: %0.9.

## Root Cause

Council 20 expert'ten oluşuyor. Ordinarius her expert'ten oyunu topluyor ve consensus arıyor. Consensus olmayınca HOLD default değeri dönüyor.

**Matematiksel problem**: 20 expert → %20 BUY, %15 SHORT, %65 HOLD oyu verirse → basit çoğunluk → HOLD. Confidence 0.3 (çünkü consensus zayıf). Bot `confidence < 0.5` olan HOLD'ları filter ediyor → trade yok.

```
Coin trend belirsiz → 8 expert SELL, 7 expert BUY, 5 expert HOLD
→ Ordinarius: "no clear direction → HOLD, confidence=0.3"
→ Bot filter: confidence < 0.5 → SKIP
→ 0 trade
```

**Sonuç**: Council yüksek consensus gerektirince büyük çoğunlukta HOLD → sinyal kaybı.

## Patterns

### Consensus Threshold Çok Yüksekse
- Yüksek konsensüs = yalnız belirgin trendlerde sinyal
- Lateral/chop market = sonsuz HOLD
- Strateji "viable" görünür ama hiç trade yapmaz

### HOLD Default Bias
Voting sisteminde default = HOLD'tur (güvenli). Eğer threshold düşürülmezse:
- Bear market: %70+ HOLD, rare BUY/SHORT signal
- Chop market: %90+ HOLD
- Lateral trend %48 stratejinin yaşadığı durum

## Tanı Komutları

```python
# Trading activity'de HOLD vs BUY/SHORT dağılımı
db.trading_activity.aggregate([
    {"$group": {"_id": "$decision", "count": {"$sum": 1}}}
])

# Confidence distribution
db.trading_activity.aggregate([
    {"$bucket": {"groupBy": "$confidence", "boundaries": [0, 0.3, 0.5, 0.7, 1.0]}}
])

# Zero-trade stratejilerin council kararları
db.trading_activity.find({"decision": "HOLD", "confidence": {"$lt": 0.4}}).limit(10)
```

## Çözüm Yaklaşımları

1. **Confidence threshold düşür**: `min_confidence = 0.3` → `0.2` (daha fazla BUY/SHORT geçer)
2. **Majority threshold düşür**: 60% → 40% (zayıf konsensüs yeterli)
3. **Regime-aware voting**: Bull market'ta HOLD bias kaldır
4. **Expert specialization**: Coin/timeframe bazlı expert ağırlıklandırma

## Ders

1. Probabilistic voting sisteminde HOLD default bias kaçınılmaz
2. N uzman arttıkça consensus zorlaşır → HOLD oranı artar
3. Threshold'u düşürünce false signal riski artar → her iki yönde backtest yap
4. Regime-aware thresholds: bull=lower, bear=higher HOLD bias tolerance

## İlgili Dosyalar

- `borsa-trading-team/backend/app/services/council/voting.py`
- `borsa-trading-team/backend/app/services/council/ordinarius.py`
- `borsa-trading-team/backend/app/services/council/base_expert.py`

## Anahtar Kelimeler

`council`, `HOLD bias`, `voting`, `consensus`, `confidence`, `signal dilution`, `Ordinarius`, `expert`, `zero trade`, `lateral market`
