-- ELITE TUITION PROVIDER: initial Supabase schema
-- Apply this migration in the Supabase SQL Editor or with Supabase CLI.

create extension if not exists pgcrypto;

create table if not exists public.admin_users (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role in ('admin','staff')),
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create or replace function public.has_staff_access()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users
    where user_id = auth.uid() and active = true
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.admin_users
    where user_id = auth.uid() and active = true and role = 'admin'
  );
$$;

create table if not exists public.enquiries (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null,
  email text,
  service text not null default 'Home Tuition',
  student_class text,
  board text,
  subjects text,
  district text,
  area text,
  message text,
  source text not null default 'website',
  status text not null default 'New'
    check (status in ('New','Contacted','Follow-up','Demo Scheduled','Converted','Not Interested','Closed')),
  follow_up_at timestamptz,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  student_code text unique,
  name text not null,
  parent_name text,
  phone text,
  email text,
  class_name text,
  board text,
  subjects text[],
  medium text,
  district text,
  area text,
  address text,
  monthly_fee numeric(12,2) not null default 0 check (monthly_fee >= 0),
  status text not null default 'New'
    check (status in ('New','Demo Scheduled','Active','On Hold','Completed','Closed')),
  admission_date date,
  assigned_tutor_id uuid,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tutors (
  id uuid primary key default gen_random_uuid(),
  tutor_code text unique,
  name text not null,
  phone text,
  email text,
  qualification text,
  experience text,
  classes text[],
  subjects text[],
  teaching_medium text,
  preferred_districts text[],
  preferred_areas text[],
  availability text,
  expected_fee numeric(12,2) check (expected_fee is null or expected_fee >= 0),
  profile_image_path text,
  verification_status text not null default 'Pending'
    check (verification_status in ('Pending','Under Review','Verified','Rejected')),
  status text not null default 'New'
    check (status in ('New','Under Review','Active','On Hold','Inactive')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.students
  drop constraint if exists students_assigned_tutor_id_fkey;
alter table public.students
  add constraint students_assigned_tutor_id_fkey
  foreign key (assigned_tutor_id) references public.tutors(id) on delete set null;

create table if not exists public.courses (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  slug text unique,
  category text,
  description text,
  duration text,
  fee numeric(12,2) not null default 0 check (fee >= 0),
  image_path text,
  published boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.admissions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  course_id uuid references public.courses(id) on delete set null,
  admission_date date not null default current_date,
  agreed_fee numeric(12,2) not null default 0 check (agreed_fee >= 0),
  status text not null default 'Active'
    check (status in ('Enquiry','Demo','Active','On Hold','Completed','Cancelled')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.assignments (
  id uuid primary key default gen_random_uuid(),
  student_id uuid references public.students(id) on delete set null,
  tutor_id uuid references public.tutors(id) on delete set null,
  title text not null,
  description text,
  due_date date,
  status text not null default 'Pending'
    check (status in ('Pending','In Progress','Submitted','Completed','Cancelled')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.fee_transactions (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete restrict,
  tutor_id uuid references public.tutors(id) on delete set null,
  receipt_number text unique,
  period_label text not null,
  payment_month integer not null check (payment_month >= 1),
  amount_due numeric(12,2) not null default 0 check (amount_due >= 0),
  amount_received numeric(12,2) not null default 0 check (amount_received >= 0),
  payment_mode text check (payment_mode in ('Cash','UPI','Bank Transfer','Other')),
  transaction_reference text,
  payment_date date not null default current_date,
  tutor_share numeric(12,2) generated always as
    (round(amount_received * case when payment_month = 1 then 0.50 else 0.80 end, 2)) stored,
  company_share numeric(12,2) generated always as
    (round(amount_received * case when payment_month = 1 then 0.50 else 0.20 end, 2)) stored,
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.follow_ups (
  id uuid primary key default gen_random_uuid(),
  enquiry_id uuid references public.enquiries(id) on delete cascade,
  student_id uuid references public.students(id) on delete cascade,
  title text not null,
  task_type text not null default 'Call',
  due_at timestamptz,
  priority text not null default 'Medium' check (priority in ('High','Medium','Low')),
  status text not null default 'Pending' check (status in ('Pending','In Progress','Done','Cancelled')),
  notes text,
  created_at timestamptz not null default now()
);

create table if not exists public.testimonials (
  id uuid primary key default gen_random_uuid(),
  person_name text not null,
  relation_label text,
  content text not null,
  rating integer check (rating between 1 and 5),
  published boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.website_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  is_public boolean not null default false,
  updated_at timestamptz not null default now()
);

create index if not exists enquiries_created_at_idx on public.enquiries(created_at desc);
create index if not exists enquiries_status_idx on public.enquiries(status);
create index if not exists students_status_idx on public.students(status);
create index if not exists tutors_status_idx on public.tutors(status);
create index if not exists fee_transactions_student_idx on public.fee_transactions(student_id);
create index if not exists fee_transactions_payment_date_idx on public.fee_transactions(payment_date desc);
create index if not exists follow_ups_due_idx on public.follow_ups(due_at) where status = 'Pending';

-- Enable Row Level Security on every application table.
alter table public.admin_users enable row level security;
alter table public.enquiries enable row level security;
alter table public.students enable row level security;
alter table public.tutors enable row level security;
alter table public.courses enable row level security;
alter table public.admissions enable row level security;
alter table public.assignments enable row level security;
alter table public.fee_transactions enable row level security;
alter table public.follow_ups enable row level security;
alter table public.testimonials enable row level security;
alter table public.website_settings enable row level security;

-- Admins/staff can read their own role row; only an existing admin can manage roles.
create policy "Users can read own admin role"
on public.admin_users for select to authenticated
using (user_id = auth.uid() or public.is_admin());

create policy "Admins manage admin roles"
on public.admin_users for all to authenticated
using (public.is_admin()) with check (public.is_admin());

-- Private operational data: authorized admin/staff only.
do $$
declare t text;
begin
  foreach t in array array['enquiries','students','tutors','admissions','assignments','fee_transactions','follow_ups'] loop
    execute format('create policy %I on public.%I for all to authenticated using (public.has_staff_access()) with check (public.has_staff_access())', t || '_staff_all', t);
  end loop;
end $$;

-- Public visitors may read only published course/testimonial rows.
create policy "Public can read published courses"
on public.courses for select to anon, authenticated
using (published = true);

create policy "Staff manage courses"
on public.courses for all to authenticated
using (public.has_staff_access()) with check (public.has_staff_access());

create policy "Public can read published testimonials"
on public.testimonials for select to anon, authenticated
using (published = true);

create policy "Staff manage testimonials"
on public.testimonials for all to authenticated
using (public.has_staff_access()) with check (public.has_staff_access());

create policy "Public can read public website settings"
on public.website_settings for select to anon, authenticated
using (is_public = true);

create policy "Staff manage website settings"
on public.website_settings for all to authenticated
using (public.has_staff_access()) with check (public.has_staff_access());

-- No anonymous direct INSERT policy is intentionally provided for enquiries.
-- Website enquiry submissions must go through the validated submit-enquiry Edge Function.
