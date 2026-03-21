# EXP-0046: HocamClass Multi-Channel Messaging & Project Restructuring

**Date**: 2025-12-02
**Project**: HocamClass
**Type**: Architecture + Feature Implementation
**Outcome**: SUCCESS

---

## Problem Statement

1. **Messaging Need**: HocamClass needed multi-channel notification system (Telegram + WhatsApp) for user engagement
2. **Structure Problem**: Bot services were embedded inside backend, making deployment and tracking difficult

## Solution Implemented

### Part 1: Multi-Channel Messaging (TASK-2025-017)

**Backend Module** (`/backend/app/pages/features/messaging/`):
- `messaging_router.py` - 9 routes for linking, preferences, admin
- `messaging_models.py` - Pydantic models for all messaging entities
- `messaging_common.py` - FAQ data, rate limiting, link code generation
- `telegram/telegram_notifications.py` - Direct Bot API calls
- `whatsapp/whatsapp_notifications.py` - HTTP calls to Node.js service

**Account Linking Flow**:
```
1. User requests code → Backend generates 6-digit code (5 min TTL)
2. User sends to bot → /link XXXXXX or !link XXXXXX
3. Bot verifies with backend API
4. Account linked, notifications enabled
```

**Key Configuration** (config.py):
```python
TELEGRAM_BOT_TOKEN: str
TELEGRAM_ENABLED: bool
WHATSAPP_SERVICE_URL: str = "http://localhost:3001"
WHATSAPP_ENABLED: bool
WHATSAPP_DAILY_MESSAGE_LIMIT: int = 100
MESSAGING_SUPPORT_GPT_ENABLED: bool
```

### Part 2: Project Restructuring (TASK-2025-018)

**Before** (embedded):
```
hocamclass/
└── hocamclass-web/
    └── backend/
        └── whatsapp-bot/  # Embedded in backend
```

**After** (standalone):
```
hocamclass/
├── hocamclass-web/          # Main web app
├── hocamclass-mobile/       # Mobile app
├── hocamclass-telegram/     # Standalone (Python)
├── hocamclass-whatsapp/     # Standalone (Node.js)
└── README.md
```

**Telegram Bot Structure**:
```python
# bot.py - Main entry
from telegram.ext import Application, CommandHandler, MessageHandler

def main():
    app = Application.builder().token(TOKEN).build()
    app.add_handler(CommandHandler('start', start_handler))
    app.add_handler(CommandHandler('link', link_handler))
    # ... more handlers
    app.run_polling()
```

**Backend API Client** (`config/api.py`):
```python
class HocamClassAPI:
    def verify_link_code(self, code, chat_id, username) -> Dict
    def get_user_by_chat_id(self, chat_id) -> Optional[Dict]
    def get_gpt_response(self, message, context) -> Optional[str]
```

## Key Patterns

### 1. Service Separation Pattern
- **Outbound**: Backend calls external APIs directly (Telegram Bot API, WhatsApp service)
- **Inbound**: Standalone bots handle user messages, call backend for verification

### 2. Link Code Pattern
```python
def generate_link_code() -> str:
    return ''.join(random.choices(string.digits, k=6))

# MongoDB collection with TTL index
messaging_link_codes: {
    link_code, user_id, platform, expires_at, verified
}
```

### 3. FAQ + GPT Fallback Pattern
```python
FAQ_DATA = {
    "kayit": {"keywords": ["kayıt", "üye"], "answer": "..."},
    "sifre": {"keywords": ["şifre", "parola"], "answer": "..."}
}

def find_faq_answer(message: str) -> Optional[str]:
    for faq_data in FAQ_DATA.values():
        for keyword in faq_data["keywords"]:
            if keyword in message.lower():
                return faq_data["answer"]
    return None  # Falls through to GPT
```

## Benefits Achieved

1. **Reproducibility**: Each service has isolated dependencies
2. **Independent Deployment**: PM2 process per service
3. **Clear Separation**: Backend = notifications, Bots = user interaction
4. **Scalability**: Can scale bots independently

## Files Reference

| Category | Files |
|----------|-------|
| Backend Messaging | `/backend/app/pages/features/messaging/` (12 files) |
| Telegram Bot | `/hocamclass-telegram/` (10 files) |
| WhatsApp Bot | `/hocamclass-whatsapp/` (8 files) |
| Documentation | README.md, ARCHITECTURE.md, task_management.md |

## Lessons Learned

1. **Compare with similar projects**: HocamBilet's structure revealed better patterns
2. **Standalone > Embedded**: Bot services should be independent for maintainability
3. **Document communication patterns**: Clear diagrams help understanding

## Reusable Components

- Link code generation/verification system
- FAQ keyword matching with GPT fallback
- Rate limiting for WhatsApp (100/day, 3s delay)
- PM2 ecosystem config per service

---

**Tags**: #hocamclass #messaging #telegram #whatsapp #restructuring #architecture
**Related**: EXP-0045 (nh3 XSS prevention)
