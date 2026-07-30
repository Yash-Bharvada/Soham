-- =============================================
-- Soham PG Management App — Idempotent Initial Schema
-- Safe to run multiple times in Supabase SQL Editor
-- =============================================

-- Enable UUID extension
create extension if not exists "uuid-ossp";

-- =============================================
-- TABLES
-- =============================================

-- Profiles (extends auth.users)
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null default '',
  email text not null default '',
  phone text,
  role text not null default 'tenant' check (role in ('owner', 'tenant')),
  avatar_url text,
  fcm_token text,
  created_at timestamptz not null default now()
);

-- Beds (4 beds, pre-seeded)
create table if not exists public.beds (
  id serial primary key,
  bed_number text not null,
  tenant_id uuid references public.profiles(id) on delete set null,
  move_in_date date,
  rent_amount numeric not null default 8500
);

-- Insert 4 beds if not present
insert into public.beds (bed_number, rent_amount)
select 'Bed 1', 8500 where not exists (select 1 from public.beds where bed_number = 'Bed 1');
insert into public.beds (bed_number, rent_amount)
select 'Bed 2', 8500 where not exists (select 1 from public.beds where bed_number = 'Bed 2');
insert into public.beds (bed_number, rent_amount)
select 'Bed 3', 8500 where not exists (select 1 from public.beds where bed_number = 'Bed 3');
insert into public.beds (bed_number, rent_amount)
select 'Bed 4', 8500 where not exists (select 1 from public.beds where bed_number = 'Bed 4');

-- Payments
create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete cascade,
  amount numeric not null,
  due_date date not null,
  paid_date timestamptz,
  status text not null default 'pending' check (status in ('paid', 'due_today', 'overdue', 'pending')),
  screenshot_url text,
  payment_method text default 'online',
  month_year text,
  created_at timestamptz not null default now()
);

alter table public.payments add column if not exists payment_method text default 'online';

-- Documents (Aadhaar uploads)
create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete cascade,
  type text not null check (type in ('self', 'father', 'mother')),
  file_url text,
  status text not null default 'pending' check (status in ('pending', 'verified', 'rejected')),
  rejection_reason text,
  uploaded_at timestamptz default now(),
  reviewed_at timestamptz,
  unique(tenant_id, type)
);

alter table public.documents add column if not exists rejection_reason text;

-- In-app notifications log
create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  tenant_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null,
  is_read boolean not null default false,
  sent_at timestamptz not null default now()
);

-- Settings (UPI ID, etc.)
create table if not exists public.settings (
  key text primary key,
  value text not null
);

insert into public.settings (key, value) values
  ('upi_id', 'chetnabharvada1234@okhdfcbank'),
  ('pg_name', 'Soham'),
  ('rent_amount', '8500')
on conflict (key) do nothing;

-- =============================================
-- TRIGGERS & FUNCTIONS
-- =============================================

-- Auto-create profile & auto-confirm email on signup
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  -- Auto-confirm email so no confirmation link is needed
  update auth.users
  set email_confirmed_at = coalesce(email_confirmed_at, now())
  where id = new.id;

  insert into public.profiles (id, email, name, role)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data->>'name', ''),
    coalesce(new.raw_user_meta_data->>'role', 'tenant')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Auto-update payment status daily (called by cron)
create or replace function public.update_payment_statuses()
returns void
language plpgsql
security definer
as $$
begin
  -- Mark as overdue
  update public.payments
  set status = 'overdue'
  where status in ('pending', 'due_today')
    and due_date < current_date;

  -- Mark as due today
  update public.payments
  set status = 'due_today'
  where status = 'pending'
    and due_date = current_date;
end;
$$;

-- Helper: get current user role
create or replace function public.get_my_role()
returns text
language sql
security definer
stable
as $$
  select role from public.profiles where id = auth.uid();
$$;

-- =============================================
-- ROW LEVEL SECURITY
-- =============================================

alter table public.profiles enable row level security;
alter table public.beds enable row level security;
alter table public.payments enable row level security;
alter table public.documents enable row level security;
alter table public.notifications enable row level security;
alter table public.settings enable row level security;

-- PROFILES policies
drop policy if exists "Users can view own profile" on public.profiles;
create policy "Users can view own profile" on public.profiles
  for select using (auth.uid() = id);

drop policy if exists "Owner can view all profiles" on public.profiles;
create policy "Owner can view all profiles" on public.profiles
  for select using (get_my_role() = 'owner');

drop policy if exists "Users can update own profile" on public.profiles;
create policy "Users can update own profile" on public.profiles
  for update using (auth.uid() = id);

drop policy if exists "Trigger can insert profiles" on public.profiles;
create policy "Trigger can insert profiles" on public.profiles
  for insert with check (true);

-- BEDS policies
drop policy if exists "All authenticated can view beds" on public.beds;
create policy "All authenticated can view beds" on public.beds
  for select using (auth.role() = 'authenticated');

drop policy if exists "Owner can update beds" on public.beds;
create policy "Owner can update beds" on public.beds
  for update using (get_my_role() = 'owner');

-- PAYMENTS policies
drop policy if exists "Tenant views own payments" on public.payments;
create policy "Tenant views own payments" on public.payments
  for select using (auth.uid() = tenant_id);

drop policy if exists "Owner views all payments" on public.payments;
create policy "Owner views all payments" on public.payments
  for select using (get_my_role() = 'owner');

drop policy if exists "Tenant inserts own payments" on public.payments;
create policy "Tenant inserts own payments" on public.payments
  for insert with check (auth.uid() = tenant_id);

drop policy if exists "Tenant updates own payments (screenshot)" on public.payments;
create policy "Tenant updates own payments (screenshot)" on public.payments
  for update using (auth.uid() = tenant_id);

drop policy if exists "Owner updates any payment" on public.payments;
create policy "Owner updates any payment" on public.payments
  for update using (get_my_role() = 'owner');

-- DOCUMENTS policies
drop policy if exists "Tenant views own documents" on public.documents;
create policy "Tenant views own documents" on public.documents
  for select using (auth.uid() = tenant_id);

drop policy if exists "Owner views all documents" on public.documents;
create policy "Owner views all documents" on public.documents
  for select using (get_my_role() = 'owner');

drop policy if exists "Tenant inserts own documents" on public.documents;
create policy "Tenant inserts own documents" on public.documents
  for insert with check (auth.uid() = tenant_id);

drop policy if exists "Tenant updates own documents" on public.documents;
create policy "Tenant updates own documents" on public.documents
  for update using (auth.uid() = tenant_id);

drop policy if exists "Owner updates document status" on public.documents;
create policy "Owner updates document status" on public.documents
  for update using (get_my_role() = 'owner');

-- NOTIFICATIONS policies
drop policy if exists "Tenant views own notifications" on public.notifications;
create policy "Tenant views own notifications" on public.notifications
  for select using (auth.uid() = tenant_id);

drop policy if exists "Owner views all notifications" on public.notifications;
create policy "Owner views all notifications" on public.notifications
  for select using (get_my_role() = 'owner');

drop policy if exists "Service can insert notifications" on public.notifications;
create policy "Service can insert notifications" on public.notifications
  for insert with check (true);

drop policy if exists "Tenant marks own notifications read" on public.notifications;
create policy "Tenant marks own notifications read" on public.notifications
  for update using (auth.uid() = tenant_id);

-- SETTINGS policies
drop policy if exists "All authenticated can view settings" on public.settings;
create policy "All authenticated can view settings" on public.settings
  for select using (auth.role() = 'authenticated');

drop policy if exists "Owner can update settings" on public.settings;
create policy "Owner can update settings" on public.settings
  for update using (get_my_role() = 'owner');

-- =============================================
-- STORAGE BUCKETS
-- =============================================

insert into storage.buckets (id, name, public) values ('documents', 'documents', false) on conflict (id) do nothing;
insert into storage.buckets (id, name, public) values ('payments', 'payments', false) on conflict (id) do nothing;

drop policy if exists "Tenants upload own docs" on storage.objects;
create policy "Tenants upload own docs" on storage.objects
  for insert with check (
    bucket_id = 'documents'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Tenants update own docs" on storage.objects;
create policy "Tenants update own docs" on storage.objects
  for update using (
    bucket_id = 'documents'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Tenants view own docs" on storage.objects;
create policy "Tenants view own docs" on storage.objects
  for select using (
    bucket_id = 'documents'
    and (auth.uid()::text = (storage.foldername(name))[1] or get_my_role() = 'owner')
  );

-- =============================================
-- BACKFILL PROFILES FOR EXISTING AUTH USERS & AUTO-CONFIRM
-- =============================================
update auth.users set email_confirmed_at = now() where email_confirmed_at is null;

insert into public.profiles (id, email, name, role)
select 
  id, 
  email, 
  coalesce(raw_user_meta_data->>'name', split_part(email, '@', 1)), 
  coalesce(raw_user_meta_data->>'role', 'tenant')
from auth.users
on conflict (id) do update set
  email = excluded.email,
  name = case when public.profiles.name = '' or public.profiles.name is null then excluded.name else public.profiles.name end;

-- =============================================
-- REALTIME PUBLICATION (SAFE / IDEMPOTENT)
-- =============================================
do $$
begin
  begin
    alter publication supabase_realtime add table public.profiles;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.payments;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.documents;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.beds;
  exception when duplicate_object then null;
  end;
  begin
    alter publication supabase_realtime add table public.notifications;
  exception when duplicate_object then null;
  end;
end $$;
