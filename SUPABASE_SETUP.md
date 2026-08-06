# Supabase — Tricon Academy (your project)

**Project ID:** `xkwxgvfagilznywuptgk`  
**URL:** `https://xkwxgvfagilznywuptgk.supabase.co`  
**Keys:** configured in `Tricon Academy App/Model/Supabase/SupabaseConfig.swift` (publishable only)

---

## Full wipe (keep admin only) and start fresh

Deletes **all content** and **all student/tutor accounts**.  
Keeps only profiles with `role = 'admin'`.

### 1. Run the wipe SQL

1. Open SQL Editor:  
   **https://supabase.com/dashboard/project/xkwxgvfagilznywuptgk/sql/new**
2. Open and run: **`supabase/wipe_all_content.sql`**
3. Check the result:
   - First table lists **admins kept**
   - Final counts: only admin profiles, content tables = **0**

If you have **no admin yet**, promote yourself **before** the wipe:

```sql
update public.profiles set role = 'admin' where email = 'YOUR_EMAIL_HERE';
```

### 2. Clear Storage files (PDFs / videos)

1. **Storage → `content` bucket**  
   https://supabase.com/dashboard/project/xkwxgvfagilznywuptgk/storage/buckets/content  
2. Delete all folders and files inside the bucket

### 3. Clear the iOS app cache

1. **Delete the app** from the simulator/device and reinstall, **or**
2. Log out → log back in as admin

### 4. Upload new content

1. Log in as **admin**
2. **Manage → Upload Document or Lesson**
3. Create folders and upload papers / notes / videos

Students and tutors must **register again** after this wipe.

---

## One required step left: create the database tables

Auth already works. The app still needs tables (`profiles`, folders, library items).

### Do this once (2 minutes)

1. Open the SQL Editor (already on your project):  
   **https://supabase.com/dashboard/project/xkwxgvfagilznywuptgk/sql/new**

2. Open the file in this repo:  
   **`supabase/schema.sql`**

3. Select all → copy → paste into the SQL Editor → click **Run**

4. You should see **Success**. No red errors.

5. (Optional but recommended for testing)  
   **Authentication → Providers → Email** → turn **off** “Confirm email”

---

## After schema is run

1. Build & run the iOS app in Xcode  
2. **Register** a new account (or log in)  
3. **Profile** should show **Supabase cloud**  
4. Promote yourself to admin (SQL Editor):

```sql
update public.profiles set role = 'admin' where email = 'YOUR_EMAIL_HERE';
```

Log out and log in again so the app reloads your role.

---

## Student school / district / grade (if you already ran schema once)

Run this once so profiles can store onboarding fields:

**`supabase/migration_student_profile.sql`**

(or re-run the full `schema.sql` — the `ADD COLUMN IF NOT EXISTS` lines are safe)

After a **student** registers they see a congratulations screen and enter:

- School name  
- District  
- Grade (Form 1–4)

Staff can open **Manage → Student accounts** to view each student.

---

## Super Admin dashboard (block / remove / tutors)

If you already ran the schema once, also run:

**`supabase/migration_super_admin.sql`**

This adds `is_blocked` / `is_removed` and lets admins update any profile.

Then in the app (admin account only): **Manage → Super Admin dashboard**

- Counts of pupils, tutors, and total accounts  
- Open any account for full details  
- **Block** / **Unblock**  
- **Remove tutor access** (tutor → student)  
- **Remove account** (soft-delete; cannot sign in)  
- **Approve / reject tutor applications**

---

## Tutor verification (application form)

Run once:

**`supabase/migration_tutor_application.sql`**

Flow:

1. User registers as **Tutor**  
2. Fills verification form (education, institution, phone, gender, address, subject major, reference contacts)  
3. Waits for super admin approval (shows **0976134025** and `support@triconacademy.com`)  
4. Super admin opens **Manage → Super Admin dashboard → Tutors → Approve**  

Until approved, tutors cannot use Manage / upload.

---

## Password reset (stop blank localhost)

The app opens reset links via deep link:

`triconacademy://auth/callback`

In Supabase Dashboard go to:

**Authentication → URL Configuration**

Set:

| Field | Value |
|--------|--------|
| **Site URL** | `triconacademy://auth/callback` |
| **Redirect URLs** | add `triconacademy://auth/callback` |

Save. Then request a new “Forgot password” email from the app and open it **on the iPhone** with Tricon Academy installed.

---

## Security note

- **Publishable / anon** key → allowed in the iOS app (with RLS).  
- **Secret / service_role** key → never put in the app. Keep it only in the dashboard.

You shared the publishable key; that is what we stored in the app.

---

## Dashboard shortcuts

| Task | Link |
|------|------|
| SQL Editor | https://supabase.com/dashboard/project/xkwxgvfagilznywuptgk/sql/new |
| API keys | https://supabase.com/dashboard/project/xkwxgvfagilznywuptgk/settings/api |
| Users | https://supabase.com/dashboard/project/xkwxgvfagilznywuptgk/auth/users |
| Tables | https://supabase.com/dashboard/project/xkwxgvfagilznywuptgk/editor |
| Storage | https://supabase.com/dashboard/project/xkwxgvfagilznywuptgk/storage/buckets |
