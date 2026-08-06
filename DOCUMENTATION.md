# Tricon Academy App — Technical Documentation

**Product:** Tricon Academy  
**Platform:** iOS (native)  
**Bundle ID:** `com.moses.Tricon-Academy-App`  
**Minimum iOS:** 16.2  
**Language:** Swift 5  

Tricon Academy is a curriculum learning app for secondary students (Form 1–4). Learners browse past papers, notes, and video lessons by level and subject. Tutors and admins upload and organise content. Super admins manage accounts, tutor applications, and access control.

---

## Table of contents

1. [Overview](#1-overview)
2. [Technology stack](#2-technology-stack)
3. [Frameworks & Apple APIs](#3-frameworks--apple-apis)
4. [Architecture](#4-architecture)
5. [How the app works](#5-how-the-app-works)
6. [User roles & permissions](#6-user-roles--permissions)
7. [Backend & data](#7-backend--data)
8. [Feature map](#8-feature-map)
9. [Project structure](#9-project-structure)
10. [Key flows](#10-key-flows)
11. [Local vs cloud modes](#11-local-vs-cloud-modes)
12. [Security](#12-security)
13. [Setup & configuration](#13-setup--configuration)
14. [Testing](#14-testing)
15. [Glossary](#15-glossary)

---

## 1. Overview

### What the app does

| Audience | Capabilities |
|----------|----------------|
| **Students** | Register, complete school profile, browse curriculum by Form 1–4, open papers/notes/videos, save bookmarks, use the Academy Library |
| **Tutors** | Register → verification form → wait for admin approval → upload lessons, create folders, manage assigned subjects |
| **Admins** | Full content management, student list, Super Admin dashboard (block/remove accounts, approve tutors) |

### Learning content model

```
Level (Form 1–4)
  └── Subject (Physics, Maths, Chemistry, Biology, English, Optionals…)
        └── Section (Papers | Notes | Videos)
              └── Folders (optional, nestable)
                    └── Library items (PDF / video files)
```

Sample curriculum entries can ship in-app (`CurriculumData`). Staff-uploaded content lives in **ContentLibrary** (local cache + Supabase Storage when cloud is on).

---

## 2. Technology stack

| Layer | Technology | Notes |
|-------|------------|--------|
| **UI** | SwiftUI | Declarative screens, navigation, forms, tabs |
| **Language** | Swift 5 | App + models + networking |
| **IDE / build** | Xcode | `.xcodeproj` native project |
| **Min OS** | iOS 16.2+ | Deployment target in project settings |
| **Backend** | Supabase | Auth, Postgres (PostgREST), Storage |
| **HTTP client** | `URLSession` | Custom lightweight Supabase client (no third-party SPM package required) |
| **Auth persistence** | Keychain + session tokens | Session restore on launch |
| **Local persistence** | `UserDefaults`, `FileManager` | Bookmarks, settings, uploaded file copies |
| **Crypto (local auth)** | CryptoKit | Password hashing in offline/local mode |
| **Email (optional)** | EmailJS or Resend | Verification codes via `EmailService` |
| **Deep links** | Custom URL scheme `triconacademy://` | Password recovery callback |
| **Database** | PostgreSQL (Supabase) | SQL schema + migrations under `supabase/` |
| **File storage** | Supabase Storage bucket `content` | Papers, notes, videos |
| **PDF viewing** | PDFKit | Native PDF UI |
| **Video playback** | AVKit | Native video player |
| **Tests** | XCTest | Unit + UI test targets |

### What is *not* used

- No CocoaPods / Carthage dependency manager for core backend
- No official `supabase-swift` SPM package — networking is a **first-party REST client** over Auth + PostgREST + Storage APIs
- Core Data model files were removed; content and profiles use Supabase + local stores instead

---

## 3. Frameworks & Apple APIs

| Framework / API | Used for |
|-----------------|----------|
| **SwiftUI** | All screens, layouts, animations, environment objects |
| **Foundation** | Models, networking, dates, JSON `Codable` |
| **Combine** | `ObservableObject` / `@Published` state |
| **UIKit** | Keyboard types, bridges (e.g. PDFKit `UIViewRepresentable`) |
| **PDFKit** | Past papers and note PDFs |
| **AVKit** | Video lessons |
| **CryptoKit** | Local password hashing (offline accounts) |
| **Security** | Keychain access for sessions / local accounts |
| **URLSession** | Supabase Auth, REST, Storage uploads/downloads |
| **FileManager** | Documents directory for uploaded / cached media |
| **UserDefaults** | Settings, bookmarks, library metadata cache |
| **os** (optional logging) | Library model diagnostics |

---

## 4. Architecture

### High-level diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Tricon_Academy_App (@main)              │
│  AuthManager + AppSettings as @EnvironmentObject            │
└──────────────────────────┬──────────────────────────────────┘
                           │
           ┌───────────────┴───────────────┐
           │ isLoggedIn?                   │
           ▼                               ▼
    Gate views                    Onboarding → Login / Register
    (student onboarding,          (NavigationView stack)
     tutor application/pending)
           │
           ▼
      MainTabView
      ├── Home
      ├── Browse → Level → Subject → ContentHub
      ├── Saved
      ├── Manage (staff only)
      └── Profile / Settings
           │
           ▼
   Domain managers (singletons)
   ├── AuthManager
   ├── ContentLibrary
   ├── LibraryBookStore
   ├── SavedItemsManager
   ├── StatsManager
   └── AppSettings
           │
           ▼
   SupabaseClient (URLSession)
   ├── Auth (sign up / in / out / reset / refresh)
   ├── PostgREST (profiles, folders, library_items, books)
   └── Storage (bucket: content)
```

### Pattern

- **MV-style with shared services:** SwiftUI views observe singleton `ObservableObject` managers.
- **Single source of truth for session:** `AuthManager.shared` drives root routing.
- **Hybrid data:** curriculum samples in code; dynamic library items from cloud/local cache.
- **Role-gated UI:** tabs and upload actions depend on `User.canManageContent` and subject specialism.

### Entry point

`Tricon_Academy_AppApp.swift`:

1. Injects `AuthManager` and `AppSettings`.
2. Routes signed-in users through verification gates (student school profile, tutor application / pending / rejected).
3. Shows `MainTabView` when fully onboarded.
4. Handles `onOpenURL` for password-reset deep links and presents `ResetPasswordConfirmView`.

---

## 5. How the app works

### 5.1 Launch & session restore

1. App starts → `AuthManager` initialises.
2. If Supabase is **not** configured, optional **local demo accounts** may be seeded (Keychain).
3. If Supabase **is** configured, session tokens are restored and the remote **profile** is loaded.
4. Blocked / removed accounts are denied access with a support message.

### 5.2 Authentication

**Cloud mode (default when Supabase is configured):**

- Register / login via Supabase Auth (email + password).
- On signup, a DB trigger (`handle_new_user`) inserts a row into `public.profiles` using auth metadata (`full_name`, `role`, `phone`).
- App may patch profile fields if the trigger left them incomplete.
- Password reset emails redirect to `triconacademy://auth/callback`; the app sets the session and opens the “set new password” sheet when `type=recovery`.

**Local mode (offline / no Supabase):**

- Accounts stored in Keychain with hashed passwords (CryptoKit).
- Same login/register API surface on `AuthManager`.

### 5.3 Post-registration gates

| Role | After register |
|------|----------------|
| **Student** | `StudentWelcomeOnboardingView` — school, district, grade (Form 1–4). Sets `profileCompleted`. |
| **Tutor** | `TutorApplicationView` — education, institution, phone, gender, address, subject major, references. Status → `pending`. |
| **Tutor pending** | `TutorPendingApprovalView` — cannot use Manage/upload until approved. Contact info shown. |
| **Tutor rejected** | `TutorRejectedView` — access restricted; support contacts. |
| **Admin** | Promoted only via SQL / dashboard (`profiles.role = 'admin'`), not via public registration. |

### 5.4 Main app (tabs)

| Tab | Who | Purpose |
|-----|-----|---------|
| **Home** | All | Greeting, search, form shortcuts, library entry, staff upload shortcuts |
| **Browse** | All | Pick Form → Subject → Content hub (papers / notes / videos) |
| **Saved** | All | Local bookmarks (`SavedItemsManager`) |
| **Manage** | Approved tutors + admins | Upload lessons, admin tools, student list, Super Admin |
| **Profile** | All | Account info, settings, sign out, cloud status |

### 5.5 Content browsing

1. User selects a **Level** (Form 1–4; A-Level exists in model but is hidden from active pickers).
2. Chooses a **Subject** (core grid or Optionals list).
3. `ContentHubView` shows three sections: **Papers**, **Notes**, **Videos**.
4. Each section merges:
   - **Uploaded items** from `ContentLibrary` (folders + files)
   - **Sample curriculum** from `CurriculumData` (when present)
5. PDF → `PDFViewerScreen` (PDFKit). Video → `VideoPlayerScreen` (AVKit).

### 5.6 Staff content management

- Staff open **Upload** (`UploadLessonView`) for a level/subject/section.
- Files copy to the device documents folder and, when cloud is on, upload to Supabase Storage (`content` bucket); metadata goes to `library_items`.
- Folders stored in `content_folders` (with optional nesting via parent folder id / migrations).
- **Subject specialism:** tutors may upload/delete only for `subjectMajor` + approved `allowedExtraSubjects`. Admins manage all subjects. Everyone can still *view* all subjects.

### 5.7 Academy Library (books)

- Separate from curriculum papers/notes/videos.
- `LibraryBookStore` + `LibraryModels` manage catalogue books and user-uploaded books.
- User uploads can require **approval** (`pending` / `approved` / `rejected`) depending on schema migrations.

### 5.8 Admin / Super Admin

- **Students admin:** list student profiles (school, district, grade).
- **Super Admin dashboard:** account counts; block/unblock; soft-remove accounts; demote tutors; approve/reject tutor applications.
- Privileges enforced in app logic and Postgres **RLS** (admins can update any profile).

---

## 6. User roles & permissions

| Capability | Student | Tutor (unapproved) | Tutor (approved) | Admin |
|------------|---------|--------------------|------------------|-------|
| Browse all subjects | ✓ | ✓ | ✓ | ✓ |
| Save items | ✓ | ✓ | ✓ | ✓ |
| Manage tab | ✗ | ✗ | ✓ | ✓ |
| Upload / folders (own subjects) | ✗ | ✗ | ✓ | ✓ (all) |
| Super Admin tools | ✗ | ✗ | ✗ | ✓ |
| Public self-register as role | ✓ | ✓ | ✓ | ✗ (not registrable) |

**Tutor approval states:** `none` → `pending` → `approved` | `rejected`.

**Account flags:** `is_blocked`, `is_removed` prevent sign-in (with optional `admin_status_reason`).

---

## 7. Backend & data

### 7.1 Supabase services

| Service | Usage |
|---------|--------|
| **Auth** | Email/password, session JWT, refresh, password update, recovery links |
| **Postgres + PostgREST** | `profiles`, `content_folders`, `library_items`, library books (via migrations) |
| **Storage** | Bucket `content` for media files |
| **RLS** | Authenticated read; staff write for content; users update own profile; admins update any profile |

### 7.2 Core tables (see `supabase/schema.sql`)

- **`profiles`** — one row per auth user: name, email, role, school fields, tutor application fields, block flags, subject specialism.
- **`content_folders`** — organisational folders per level + subject + section.
- **`library_items`** — uploaded papers, notes, videos with `storage_path`, uploader, optional `folder_id`.

### 7.3 SQL migrations (repo)

| File | Purpose |
|------|---------|
| `schema.sql` | Base tables, trigger, RLS |
| `migration_student_profile.sql` | School / district / grade columns |
| `migration_super_admin.sql` | Block / remove + admin policies |
| `migration_tutor_application.sql` | Tutor verification fields |
| `migration_tutor_subject_access.sql` | Extra subject access fields |
| `migration_nested_folders_library_books.sql` | Nested folders + library books |

### 7.4 Client implementation

`Model/Supabase/SupabaseClient.swift` implements:

- Sign up / sign in / sign out  
- Session persistence & proactive refresh  
- Profile fetch/upsert  
- REST CRUD for content  
- Storage upload / signed or public URL access  
- Parse of `triconacademy://auth/callback` tokens  

Config lives in `SupabaseConfig.swift` (project URL + **anon/publishable** key only).

---

## 8. Feature map

| Feature | Primary files |
|---------|----------------|
| Onboarding / marketing | `views/Authentication/Onboarding.swift` |
| Login / register | `LoginView.swift`, `RegisterView.swift` |
| Password reset | `LoginView` sheet + `ResetPasswordConfirmView` + deep link |
| Student onboarding | `StudentWelcomeOnboardingView.swift` |
| Tutor application | `TutorApplicationView.swift` |
| Home dashboard | `HomeView.swift` |
| Browse curriculum | `BrowseView`, `BrowseLevelsView`, `SubjectListView`, `ContentHubView` |
| PDF / video players | `PDFViewerScreen`, `VideoPlayerScreen` |
| Bookmarks | `SavedItemsView`, `SavedItemsManager` |
| Uploads | `UploadLessonView`, `ContentLibrary` |
| Admin home | `AdminHomeView` |
| Students list | `StudentsAdminView` |
| Super Admin | `SuperAdminDashboardView` |
| Profile / settings | `ProfileView`, `SettingsView` |
| Academy library | `TriconAcademyLibraryView`, `LibraryBookStore` |
| Theme | `AppSettings`, `AppTheme` in curriculum models |
| Support contacts | `AcademySupport.swift` |
| Email verification (optional) | `EmailService`, `EmailConfig`, `EmailVerificationView` |

---

## 9. Project structure

```
Tricon Academy App/
├── DOCUMENTATION.md              ← this file
├── SUPABASE_SETUP.md             ← backend setup steps
├── supabase/                     ← SQL schema & migrations
├── Tricon Academy App.xcodeproj
├── Tricon Academy App/           ← app sources
│   ├── Tricon_Academy_AppApp.swift
│   ├── AuthManger.swift          ← AuthManager (session & auth API)
│   ├── Info.plist                ← URL scheme triconacademy
│   ├── Model/
│   │   ├── User.swift
│   │   ├── AppSettings.swift
│   │   ├── ContentLibrary.swift
│   │   ├── SavedItemsManager.swift
│   │   ├── StatsManager.swift
│   │   ├── LibraryBookStore.swift / LibraryModels.swift
│   │   ├── EmailService.swift / EmailConfig.swift
│   │   ├── AcademySupport.swift
│   │   ├── Curriculum/
│   │   │   ├── CurriculumModels.swift   (Level, Subject, AppTheme…)
│   │   │   └── CurriculumData.swift     (sample content)
│   │   └── Supabase/
│   │       ├── SupabaseConfig.swift
│   │       ├── SupabaseClient.swift
│   │       └── SupabaseModels.swift
│   └── views/
│       ├── MainTabView.swift
│       ├── Authentication/       (auth, onboarding, admin, upload)
│       └── … browsing, library, players, profile
├── Tricon Academy AppTests/
└── Tricon Academy AppUITests/
```

---

## 10. Key flows

### Student journey

```
Onboarding → Create Account (Student) → Student school profile
  → Main tabs → Browse Form → Subject → Papers/Notes/Videos
  → Open PDF or video → Optional bookmark → Profile / Settings
```

### Tutor journey

```
Register as Tutor → Verification form → Pending screen
  → Admin approves → Full app + Manage tab
  → Upload lesson (allowed subjects) → Students see content after sync
```

### Admin journey

```
Promote profile.role = admin (SQL)
  → Login → Manage → Super Admin dashboard
  → Approve tutors / block users / review accounts
  → Upload content for any subject
```

### Password reset

```
Login → Forgot password → Email with recovery link
  → Opens triconacademy://auth/callback
  → ResetPasswordConfirmView → updatePassword → signed in
```

---

## 11. Local vs cloud modes

| | **Cloud (Supabase configured)** | **Local (not configured)** |
|--|----------------------------------|----------------------------|
| Auth | Supabase Auth + profiles | Keychain accounts |
| Content | Sync folders/items + Storage | Local `UserDefaults` + files only |
| Demo seeds | Disabled | Optional admin/tutor seeds |
| Multi-device | Yes (with same project) | Device-only |
| Profile UI | Shows cloud status | Local only |

Switching is automatic via `SupabaseConfig.isConfigured` and `AuthManager.isCloudEnabled`.

---

## 12. Security

- **Anon key only** in the client; never ship the service_role secret.
- **Row Level Security** on Postgres tables; staff helpers (`is_staff()`) gate writes.
- **Blocked / removed** profiles cannot keep a session.
- **Tutors** cannot self-promote to admin; admin is assigned server-side.
- **Deep link scheme** restricted to auth callback handling.
- **Password reset** requires allow-listed redirect URL in Supabase Dashboard.
- Local mode hashes passwords with CryptoKit (not a substitute for production cloud auth).

---

## 13. Setup & configuration

### Run the iOS app

1. Open `Tricon Academy App.xcodeproj` in Xcode.
2. Select a simulator or device (iOS 16.2+).
3. Build & run (`⌘R`).

### Configure Supabase

Follow **`SUPABASE_SETUP.md`** in short:

1. Confirm URL + anon key in `Model/Supabase/SupabaseConfig.swift`.
2. Run `supabase/schema.sql` (and needed migrations) in the SQL Editor.
3. Auth → URL Configuration:
   - Site URL / Redirect: `triconacademy://auth/callback`
4. Optional: disable email confirm for faster testing.
5. Promote an admin:

```sql
update public.profiles set role = 'admin' where email = 'YOUR_EMAIL_HERE';
```

6. Ensure Storage bucket `content` exists and policies allow authenticated staff uploads / authenticated reads (as defined in your project setup).

### Optional email (EmailJS / Resend)

Configure keys in `EmailConfig.swift` for verification code delivery outside Supabase Auth email.

---

## 14. Testing

| Target | Role |
|--------|------|
| `Tricon Academy AppTests` | Unit tests (XCTest) |
| `Tricon Academy AppUITests` | UI automation smoke tests |

Prefer testing registration, role gates, browse navigation, and upload/sync against a dedicated Supabase project when validating cloud features.

---

## 15. Glossary

| Term | Meaning |
|------|---------|
| **Level** | Academic form (Form 1–4) |
| **Subject** | Curriculum subject (e.g. Physics) |
| **Section** | Papers, Notes, or Videos under a subject |
| **Content hub** | Screen that lists folders + items for one level+subject |
| **Library item** | Staff-uploaded paper/note/video |
| **Academy Library** | Separate books catalogue (not the same as past papers) |
| **Staff** | Approved tutor or admin (`canManageContent`) |
| **RLS** | Postgres row-level security policies |
| **Anon key** | Public Supabase client key used with RLS |

---

## Related docs

- **`SUPABASE_SETUP.md`** — project URL, SQL steps, deep links, admin promotion, tutor verification
- **`supabase/*.sql`** — canonical database definitions

---

*Last updated from the Tricon Academy iOS codebase structure and implementation (SwiftUI + custom Supabase client + curriculum/content managers).*
