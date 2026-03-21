# EXP-0105: Multi-Tenant SaaS Architecture — MetricsHub (24 Phases, 215 Routes)

## Metadata
- **Date**: 2026-02-28
- **Project**: MetricsHub (Jira MAC-142 through MAC-160)
- **Severity**: REFERENCE (architectural guide)
- **Category**: Architecture, SaaS, Multi-Tenant, FastAPI, Vue.js
- **Status**: COMPLETE

## Overview
Full multi-tenant SaaS implementation delivered in 24 phases. Scale: 215 routes, 30 database tables (21 new + 3 ALTER), 3 UI layouts, 40+ views, 8 demo organizations. Delivered in under 48 hours with phased approach.

## Architecture: Three-Tier Access Model

```
PUBLIC (unauthenticated)
|-- /plans          -> Pricing
|-- /contact        -> Contact form
|-- /blog           -> Blog posts
`-- /roadmap        -> Product roadmap

ADMIN PANEL (staff only, JWT with panel claim)
|-- /admin/dashboard    -> KPIs, overview
|-- /admin/orgs         -> Organization management
|-- /admin/orgs/:id     -> Org detail + settings
|-- /admin/tickets      -> Support tickets
`-- /admin/members      -> All users

PORTAL (customer, org-scoped JWT)
|-- /portal/dashboard   -> Org KPIs
|-- /portal/analytics   -> Usage analytics
|-- /portal/team        -> Team members
|-- /portal/tickets     -> Org's tickets
`-- /portal/settings    -> Account settings
```

## Database Migration Pattern (21 tables in one file)

```python
# migrations/003_metricshub_multitenant.py
def upgrade():
    # New tables
    op.create_table('organizations',
        sa.Column('id', sa.Integer(), primary_key=True),
        sa.Column('name', sa.String(255), nullable=False),
        sa.Column('plan_id', sa.Integer(), sa.ForeignKey('plans.id')),
        sa.Column('created_at', sa.DateTime(), default=datetime.utcnow),
    )

    op.create_table('org_members', ...)
    op.create_table('tickets', ...)
    # ... 18 more tables

    # ALTER existing tables
    op.add_column('users', sa.Column('org_id', sa.Integer(), sa.ForeignKey('organizations.id')))
    op.add_column('users', sa.Column('portal_role', sa.String(50)))

# Run all in one migration = atomic (all or nothing)
```

## JWT Multi-Audience Pattern

```python
# Two types of tokens, same JWT library
def create_panel_token(user_id: int) -> str:
    """Admin panel token — has 'panel' claim."""
    return jwt.encode({
        "sub": str(user_id),
        "type": "panel",    # Critical claim
        "exp": datetime.utcnow() + timedelta(hours=8)
    }, SECRET_KEY)

def create_portal_token(user_id: int, org_id: int) -> str:
    """Customer portal token — org-scoped."""
    return jwt.encode({
        "sub": str(user_id),
        "type": "portal",   # Different type
        "org_id": org_id,   # Org scope baked in
        "exp": datetime.utcnow() + timedelta(days=30)
    }, SECRET_KEY)

# Middleware
def require_panel(token = Depends(get_token)):
    if token["type"] != "panel":
        raise HTTPException(403, "Panel access required")
    return token

def require_portal(token = Depends(get_token)):
    if token["type"] != "portal":
        raise HTTPException(403, "Portal access required")
    return token, token["org_id"]  # org_id included
```

## Org-Scoped Queries (Tenant Isolation)

```python
# ALWAYS filter by org_id in portal endpoints
@router.get("/portal/tickets")
async def list_org_tickets(
    auth = Depends(require_portal),
    db: Session = Depends(get_db)
):
    token, org_id = auth

    # CRITICAL: always include org_id filter
    tickets = db.query(Ticket)\
        .filter(Ticket.org_id == org_id)\
        .all()
    return tickets
```

## Three-Layout Frontend Structure

```
layouts/
|-- PublicLayout.vue     -> Header (marketing nav) + Footer
|-- AdminLayout.vue      -> Sidebar (admin links) + Top bar + Content
`-- PortalLayout.vue     -> Sidebar (portal links) + Org switcher + Content
```

```vue
<!-- router/index.ts — route meta for layout selection -->
{
  path: '/admin',
  meta: { layout: 'admin', requiresPanel: true },
  children: [...]
},
{
  path: '/portal',
  meta: { layout: 'portal', requiresPortal: true },
  children: [...]
}
```

## Phase-Based Delivery Model

| Phase | Scope | Parallelizable? |
|-------|-------|----------------|
| 1: DB Migrations | Schema only | No (foundation) |
| 2: Auth Extension | JWT + RBAC | No (needed by all) |
| 3-4: Backend CRUD | Orgs, tickets, etc. | Yes (parallel per module) |
| 5-6: API Endpoints | Portal + public | Yes |
| 7-8: Frontend Foundation | Layouts + router | No (needed by views) |
| 9-12: Views | Admin + portal views | Yes (per page) |
| 13: Marketing Pages | 10 static pages | Yes |
| 14-16: Polish | Branding, seed, docs | Yes |
| 17-24: Features | Advanced features | Yes (per feature) |

## Demo Data Seeding

```python
# scripts/seed_demo.py — 8 demo orgs for sales/testing
DEMO_ORGS = [
    {"name": "TechStartup Alpha", "plan": "growth", "members": 12},
    {"name": "Enterprise Corp", "plan": "enterprise", "members": 150},
    # 6 more covering different plans and sizes...
]

def seed():
    for org_data in DEMO_ORGS:
        org = create_org(org_data)
        create_demo_members(org, count=org_data["members"])
        create_sample_tickets(org, count=5)
```

## Applicable To
- ANY multi-tenant SaaS project
- B2B platforms with customer portals
- Admin + customer dual-interface systems

## Lessons Learned
1. **Bake org_id into JWT** — simpler than querying per request
2. **Three layouts, not one** — admin UX != portal UX != public UX
3. **Phase-based = testable at each step** — not a "big bang" deploy
4. **Demo data critical** — sales can't demo an empty app
5. **All migrations in one file** — atomic, no partial state
6. **Portal routes are always org-scoped** — make it impossible to forget the filter

## Related Experiences
- EXP-0073: TABUR system (multi-agent, same project era)
- EXP-0102: Config centralization (same best practices)

## Tags
`saas` `multi-tenant` `fastapi` `vue` `architecture` `jwt` `rbac` `migration` `portal`
