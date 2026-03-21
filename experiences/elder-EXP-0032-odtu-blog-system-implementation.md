# Blog System – Rich Text Blog Platform for ODTÜ Connect

**Created:** 2025-07-23 14:30 +03:00  
**Author:** Claude Development Assistant  
**Status:** implemented  
**Scope:** Full-Stack Blog System Implementation

---

## Table of Contents

1. [Problem Statement](#1-problem-statement)
2. [Context & References](#2-context--references)
3. [Implementation Overview](#3-implementation-overview)
4. [Technical Specifications](#4-technical-specifications)
5. [API Documentation](#5-api-documentation)
6. [Frontend Architecture](#6-frontend-architecture)
7. [User Guide](#7-user-guide)
8. [Testing & Validation](#8-testing--validation)
9. [Security & Performance](#9-security--performance)
10. [Future Enhancements](#10-future-enhancements)

---

## 1 Problem Statement

ODTÜ Connect platform needed a comprehensive blog system that allows authorized users to create, publish, and manage rich text blog content with image support, categorization, and department-specific filtering capabilities.

### Key Requirements Implemented
- ✅ Rich text editing with basic formatting (bold, italic, links, lists)
- ✅ Image embedding with predefined sizes (small/medium/big) and alignment
- ✅ Blog categories and tags system (similar to FAQ system)
- ✅ Department-specific filtering and association
- ✅ Star rating system (1-5 stars) without comments
- ✅ Content workflow (draft → published)
- ✅ Permission-based content creation via `account_can_write_blog` field

### Design Decisions
- **No SEO Overengineering**: Removed meta title/description fields to keep it simple
- **No Admin Dashboard**: Inline edit buttons for authorized users instead
- **Simple Rich Text**: Basic formatting only, no advanced features
- **Category vs Department**: Clear separation following FAQ pattern

---

## 2 Context & References

### Existing System Patterns Used
- **FAQ System**: Reference for CRUD operations, star ratings, category/department separation
- **Department Integration**: Pattern established in FAQ and dormitory systems
- **GridFS Implementation**: Existing file upload patterns for image storage
- **Authentication**: JWT system with role-based permissions

### Technology Stack
- **Backend**: FastAPI + MongoDB + GridFS
- **Frontend**: Next.js 14 App Router + TypeScript + TailwindCSS
- **Rich Text**: SimpleRichTextEditor (contentEditable-based, no external deps)
- **Images**: GridFS storage with crop functionality
- **Authentication**: Existing JWT system + `account_can_write_blog` field

---

## 3 Implementation Overview

### Backend Structure
```
backend/app/pages/blog/
├── __init__.py
├── blog_models.py              # Pydantic models
├── blog_router.py              # Main router
├── blog_create_post.py         # Create endpoint
├── blog_update_put.py          # Update endpoint
├── blog_list_get.py            # List endpoint
├── blog_detail_get.py          # Detail endpoint
├── blog_delete.py              # Delete endpoint
├── blog_star_post.py           # Star rating
├── blog_star_delete.py         # Remove rating
├── blog_categories_get.py      # List categories
├── blog_categories_post.py     # Create category
├── blog_image_upload_post.py   # Upload image
├── blog_image_get.py           # Get image
├── blog_logger.py              # Logging
└── router.py                   # Entry point
```

### Frontend Structure
```
frontend/src/
├── features/blog/
│   ├── blogApi.ts              # API client
│   └── index.ts
├── app/[locale]/blog/
│   ├── page.tsx                # Listing page
│   ├── create/page.tsx         # Create page
│   └── [slug]/
│       ├── page.tsx            # Detail page
│       ├── BlogDetailClient.tsx # Client components
│       └── edit/page.tsx       # Edit page
└── shared/components/
    ├── blog/
    │   ├── DepartmentBlogSection.tsx
    │   └── ImageUploadWithCrop.tsx
    └── ui/
        └── SimpleRichTextEditor.tsx
```

---

## 4 Technical Specifications

### Database Schema

#### Blog Posts Collection (`blog_posts`)
```json
{
  "post_id": "blog--uuid4",
  "post_title": "string (5-200 chars)",
  "post_slug": "string (URL-friendly, unique)",
  "post_content": "string (max 50000 chars, HTML)",
  "post_excerpt": "string (max 500 chars)",
  "post_featured_image": "string (GridFS ID, optional)",
  "post_images": ["string (GridFS IDs)"],
  "post_category_ids": ["string (1-3 required)"],
  "post_tags": ["string (max 10, optional)"],
  "post_departments": ["string (department codes, optional)"],
  "post_author_id": "string",
  "post_author_name": "string",
  "post_status": "draft|published",
  "post_view_count": 0,
  "post_read_time": "number (calculated)",
  "post_star_1_account_ids": [],
  "post_star_2_account_ids": [],
  "post_star_3_account_ids": [],
  "post_star_4_account_ids": [],
  "post_star_5_account_ids": [],
  "post_is_edited": false,
  "post_last_edited_at": null,
  "post_is_deleted": false,
  "post_created_at": "datetime",
  "post_updated_at": "datetime",
  "post_published_at": "datetime (when published)"
}
```

#### Blog Categories Collection (`blog_categories`)
```json
{
  "category_id": "blog_category--uuid4",
  "category_slug": "string (unique)",
  "category_name": "string",
  "category_description": "string (optional)",
  "category_icon_grid_id": "string (optional)",
  "category_order": 0,
  "category_is_active": true,
  "category_post_count": 0,
  "category_created_at": "datetime"
}
```

#### Account Schema Addition
```json
{
  "account_can_write_blog": false  // Default false, admin can grant
}
```

### Database Indexes
- `post_slug` - Unique index
- `post_status, post_published_at` - Compound index
- `post_category_ids` - Array index
- `post_author_id` - Single index
- `post_tags` - Array index
- `post_is_deleted` - Single index
- `post_title, post_content, post_excerpt` - Text index

---

## 5 API Documentation

### Public Endpoints

#### List Blog Posts
```
GET /api/v1/blog/posts
Query params: search, category_id, tag, department, author_id, 
              sort_by, limit, offset
Response: Paginated list of published posts
```

#### Get Blog Post Detail
```
GET /api/v1/blog/posts/{post_id}
Response: Full post data (increments view count)
```

#### List Categories
```
GET /api/v1/blog/categories
Response: All active categories with post counts
```

#### Star Rating
```
POST /api/v1/blog/posts/{post_id}/star
Body: { "stars": 1-5 }
Auth: Required
Response: Updated star summary

DELETE /api/v1/blog/posts/{post_id}/star
Auth: Required
Response: Updated star summary
```

### Authenticated Endpoints

#### Create Blog Post
```
POST /api/v1/blog/posts
Auth: account_can_write_blog=true OR admin
Body: BlogPostCreateRequest
Response: Created post
```

#### Update Blog Post
```
PUT /api/v1/blog/posts/{post_id}
Auth: Post author OR admin
Body: BlogPostUpdateRequest (partial)
Response: Updated post
```

#### Delete Blog Post
```
DELETE /api/v1/blog/posts/{post_id}
Auth: Post author OR admin
Response: Success (soft delete)
```

#### Upload Image
```
POST /api/v1/blog/images/upload
Auth: account_can_write_blog=true OR admin
Body: FormData with image file
Response: { file_id, filename, url }
```

### Admin Endpoints

#### Create Category
```
POST /api/v1/blog/categories
Auth: Admin only
Body: BlogCategoryCreateRequest
Response: Created category
```

#### Grant Blog Permission
```
PUT /api/v1/auth/admin/users/{account_id}/blog-permission
Auth: Admin only
Body: { "can_write_blog": true/false }
Response: Success
```

---

## 6 Frontend Architecture

### Key Components

#### SimpleRichTextEditor
- Browser's contentEditable API
- Basic formatting: Bold (B), Italic (I), Underline (U)
- Text sizes: Large (L), Medium (M), Small (S), Normal (N)
- Lists: Bullet, Numbered
- Links: Insert/Remove
- No external dependencies

#### ImageUploadWithCrop
- Upload up to 5 images
- Crop functionality
- Alignment options (left/center/right)
- First image auto-set as featured
- Drag to reorder

#### Blog Pages
1. **Listing Page** (`/blog`)
   - Grid layout with cards
   - Search and filters
   - Pagination
   - Sort options

2. **Detail Page** (`/blog/[slug]`)
   - Server-side rendering
   - Star rating widget
   - Share buttons
   - View tracking
   - Edit/Delete for authorized

3. **Create/Edit Pages**
   - Title with auto-slug generation
   - Rich text editor
   - Category selection (required)
   - Department selection (optional)
   - Image upload
   - Tag management
   - Draft/Publish options

### State Management
- React hooks (useState, useEffect)
- No complex state libraries
- Optimistic UI updates for ratings
- Form validation before submission

---

## 7 User Guide

### For Administrators
1. **Grant Permissions**: Use admin API endpoint to set `account_can_write_blog=true`
2. **Create Categories**: Use API to create blog categories
3. **Moderate Content**: View all posts, edit/delete any post

### For Blog Authors
1. **Create Post**: Click "Create Blog Post" on listing page
2. **Write Content**: Use rich text editor for formatting
3. **Add Images**: Upload and crop up to 5 images
4. **Categorize**: Select 1-3 categories (required)
5. **Tag**: Add optional tags and departments
6. **Publish**: Save as draft or publish immediately

### For Readers
1. **Browse**: View blog listing with filters
2. **Search**: Find posts by title or content
3. **Filter**: By category, department, or tags
4. **Rate**: Give 1-5 star ratings
5. **Share**: Use social share buttons

### Permission Model
- **Public**: View published posts, rate posts
- **Authenticated**: Same as public + star ratings
- **Blog Authors**: Create posts, edit/delete own posts
- **Admins**: All permissions + edit any post + manage categories

---

## 8 Testing & Validation

### Test Coverage

#### Backend Tests
- ✅ Permission validation
- ✅ CRUD operations
- ✅ Star rating logic
- ✅ Image upload/retrieval
- ✅ Category management
- ✅ Filtering and search
- ✅ Soft delete

#### Frontend Tests
- ✅ Page rendering
- ✅ Form validation
- ✅ Rich text editor
- ✅ Image upload/crop
- ✅ Star rating interaction
- ✅ Responsive design
- ✅ Internationalization

### Validation Rules
- Title: 5-200 characters
- Slug: Lowercase, alphanumeric, hyphens only
- Content: 50-50,000 characters
- Excerpt: Max 300 characters
- Categories: 1-3 required
- Tags: Max 10, alphanumeric
- Images: Max 5, JPEG/PNG/GIF/WebP, 5MB limit

---

## 9 Security & Performance

### Security Measures
- **Authentication**: JWT tokens for all write operations
- **Authorization**: Role and ownership checks
- **Content Security**: Basic HTML sanitization (TODO: Add DOMPurify)
- **File Validation**: Image type and size checks
- **SQL Injection**: N/A (MongoDB)
- **XSS Prevention**: React's built-in protections

### Performance Optimizations
- **Database Indexes**: On all commonly queried fields
- **Pagination**: 12 posts per page default
- **View Tracking**: Async, non-blocking
- **Image Caching**: 24-hour cache headers
- **Lazy Loading**: For images (can be added)
- **SSR**: SEO-friendly server-side rendering

### Known Limitations
- No full-text search (uses regex)
- No image optimization/resizing
- No CDN integration
- Basic HTML sanitization

---

## 10 Future Enhancements

### Phase 2 Features (Planned)
- **TipTap Integration**: Replace SimpleRichTextEditor
- **Image in Editor**: Embed images in content
- **Advanced Search**: Elasticsearch integration
- **Analytics**: Post performance metrics

### Phase 3 Features (Considered)
- **Comments System**: With moderation
- **Social Sharing**: Enhanced integration
- **Content Scheduling**: Future publish dates
- **Multi-language**: Per-post translations
- **Related Posts**: ML-based recommendations
- **RSS Feed**: For blog subscribers

### Technical Improvements
- **DOMPurify**: Proper HTML sanitization
- **Image CDN**: Cloudinary/similar integration
- **Caching Layer**: Redis for performance
- **Webhooks**: For external integrations
- **Backup System**: Automated blog backups

---

## Maintenance Notes

### Common Issues
1. **Cursor Position**: SimpleRichTextEditor may have cursor issues
2. **TipTap Install**: May need `--force` flag due to peer deps
3. **Category Loading**: Ensure categories exist before creating posts

### Deployment Checklist
- [ ] Run database migrations/indexes
- [ ] Create initial categories
- [ ] Grant blog permissions to users
- [ ] Test image upload paths
- [ ] Verify email notifications (if any)

### Monitoring
- Track error rates on blog endpoints
- Monitor image storage usage
- Check database query performance
- Review star rating patterns

---

**Last Updated:** 2025-07-23  
**Maintainer:** Development Team  
**Version:** 1.0.0

*End of blog system documentation.*