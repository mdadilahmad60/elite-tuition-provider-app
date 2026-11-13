# ELITE TUITION PROVIDER — Backend Setup

This repository currently contains a static HTML/CSS/JavaScript management app. GitHub Pages serves the frontend only; it does not run a private database server. This backend uses Supabase (hosted PostgreSQL + Auth + Edge Functions).

## Repository
- Frontend / management app: `index.html`
- Database migration: `supabase/migrations/202611130001_initial_schema.sql`
- Public enquiry endpoint: `supabase/functions/submit-enquiry/index.ts`
- Supabase config: `supabase/config.toml`

## 1. Create the Supabase project
1. Create a project at https://supabase.com/dashboard.
2. Project name: `elite-tuition-provider`.
3. Select a region close to your users.
4. Save the database password securely.
5. In Project Settings → API, copy the Project URL and publishable key. These are used by the browser client; never expose the service-role/secret key.

## 2. Create database tables
Open SQL Editor in Supabase and run the complete migration:
`supabase/migrations/202611130001_initial_schema.sql`

The migration creates student, tutor, enquiry, course, admission, assignment, fee, follow-up, testimonial and website-settings tables, plus Row Level Security policies.

## 3. Create the first administrator
1. In Supabase Authentication → Users, create an administrator user with an email address you control.
2. Copy that user's UUID.
3. In SQL Editor, run the following statement after replacing the placeholder UUID:

```sql
insert into public.admin_users (user_id, role, active)
values ('REPLACE-WITH-AUTH-USER-UUID', 'admin', true);
```

Do not create a public admin registration form. Only a trusted project owner should provision the first admin.

## 4. Deploy the enquiry function
Install the Supabase CLI on a computer, sign in, link this project, then deploy:

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy submit-enquiry
```

The hosted Edge Function receives `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from the Supabase runtime. Do not put either secret in GitHub frontend files. If your project requires manually setting function secrets, configure them in the Supabase dashboard / CLI secrets manager.

## 5. Connect the frontend
Add a browser client module using the Supabase JavaScript v2 library and your Project URL + publishable key. Configure forms to call the `submit-enquiry` Edge Function. The function validates and stores public submissions.

Example browser module:

```js
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

export const supabase = createClient(
  'YOUR_SUPABASE_PROJECT_URL',
  'YOUR_SUPABASE_PUBLISHABLE_KEY'
);
```

Example form call:

```js
const { data, error } = await supabase.functions.invoke('submit-enquiry', {
  body: {
    name: 'Parent name',
    phone: '9876543210',
    service: 'Home Tuition',
    student_class: 'Class 6',
    board: 'CBSE',
    district: 'Ranchi',
    area: 'Doranda'
  }
});
if (error) throw error;
```

Replace the example values with values from the actual form. Never collect or send more personal information than necessary.

## 6. Important security notes
- Keep RLS enabled on all tables.
- Never place a Supabase service-role/secret key in HTML, JavaScript, GitHub Pages, or a public repository.
- Public users can read only published courses and testimonials.
- Student, tutor, enquiry, fee and other operational records require an authenticated admin/staff account.
- The public enquiry function is unauthenticated by design; before advertising the form widely, add CAPTCHA/Turnstile and server-side rate limiting/abuse controls.
- Test policies with both anonymous and authenticated non-admin accounts before storing real student/parent information.

## 7. Current frontend limitation
The existing `index.html` management panel stores records in browser localStorage. Adding the database migration does not automatically migrate those records or switch the panel to cloud storage. The next integration step is to replace its localStorage data adapter with authenticated Supabase queries, preserving the current interface, and to test migration using a backup copy first.

## 8. Deploying the frontend
Continue using GitHub Pages for static files. Supabase hosts the database and Edge Functions separately. After frontend integration, commit the updated static files and confirm GitHub Pages is publishing the intended branch/folder.
