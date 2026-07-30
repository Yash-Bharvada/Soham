-- ============================================================
-- 002_rls.sql  — Row Level Security Policies
-- Run AFTER 001_schema.sql
-- ============================================================

-- Enable RLS on all tables
alter table public.profiles        enable row level security;
alter table public.rooms           enable row level security;
alter table public.tenants         enable row level security;
alter table public.payments        enable row level security;
alter table public.notification_log enable row level security;

-- ============================================================
-- Helper: returns the calling user's role
-- ============================================================
create or replace function public.my_role()
returns text language sql security definer stable as $$
  select role from public.profiles where id = auth.uid();
$$;

-- ============================================================
-- Helper: returns the owner_id of the room a tenant is in
-- ============================================================
create or replace function public.tenant_owner_id(tenant_uuid uuid)
returns uuid language sql security definer stable as $$
  select r.owner_id
  from   public.tenants t
  join   public.rooms   r on r.id = t.room_id
  where  t.id = tenant_uuid;
$$;

-- ============================================================
-- profiles policies
-- ============================================================
drop policy if exists "profiles_select_own"   on public.profiles;
drop policy if exists "profiles_select_owner" on public.profiles;
drop policy if exists "profiles_update_own"   on public.profiles;

-- Any authenticated user can read their own profile
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

-- Owners can read any tenant profile whose room they own
create policy "profiles_select_owner"
  on public.profiles for select
  using (
    public.my_role() = 'owner'
    and exists (
      select 1 from public.tenants t
      join   public.rooms r on r.id = t.room_id
      where  t.id = public.profiles.id
      and    r.owner_id = auth.uid()
    )
  );

-- Any user can update their own profile
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Users can insert their own profile (triggered after signup)
create policy "profiles_insert_own"
  on public.profiles for insert
  with check (auth.uid() = id);

-- ============================================================
-- rooms policies
-- ============================================================
drop policy if exists "rooms_owner_all"    on public.rooms;
drop policy if exists "rooms_tenant_read"  on public.rooms;

-- Owner: full CRUD on their own rooms
create policy "rooms_owner_all"
  on public.rooms for all
  using (auth.uid() = owner_id)
  with check (auth.uid() = owner_id);

-- Tenant: can only read their own assigned room
create policy "rooms_tenant_read"
  on public.rooms for select
  using (
    public.my_role() = 'tenant'
    and exists (
      select 1 from public.tenants t
      where  t.room_id = public.rooms.id
      and    t.id = auth.uid()
    )
  );

-- ============================================================
-- tenants policies
-- ============================================================
drop policy if exists "tenants_select_own"    on public.tenants;
drop policy if exists "tenants_select_owner"  on public.tenants;
drop policy if exists "tenants_update_own"    on public.tenants;
drop policy if exists "tenants_update_owner"  on public.tenants;
drop policy if exists "tenants_insert_own"    on public.tenants;
drop policy if exists "tenants_insert_owner"  on public.tenants;

-- Tenant: read only their own row
create policy "tenants_select_own"
  on public.tenants for select
  using (auth.uid() = id);

-- Owner: read any tenant in their rooms
create policy "tenants_select_owner"
  on public.tenants for select
  using (
    public.my_role() = 'owner'
    and exists (
      select 1 from public.rooms r
      where  r.id = public.tenants.room_id
      and    r.owner_id = auth.uid()
    )
  );

-- Tenant: update their own row (e.g., document uploads)
create policy "tenants_update_own"
  on public.tenants for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Owner: update tenants in their rooms (e.g., doc_status)
create policy "tenants_update_owner"
  on public.tenants for update
  using (
    public.my_role() = 'owner'
    and exists (
      select 1 from public.rooms r
      where  r.id = public.tenants.room_id
      and    r.owner_id = auth.uid()
    )
  );

-- Tenant can insert their own tenants row (self-registration)
create policy "tenants_insert_own"
  on public.tenants for insert
  with check (auth.uid() = id);

-- Owner can insert a tenant row (owner-driven onboarding)
create policy "tenants_insert_owner"
  on public.tenants for insert
  with check (
    public.my_role() = 'owner'
    and exists (
      select 1 from public.rooms r
      where  r.id = public.tenants.room_id
      and    r.owner_id = auth.uid()
    )
  );

-- ============================================================
-- payments policies
-- ============================================================
drop policy if exists "payments_select_own"    on public.payments;
drop policy if exists "payments_select_owner"  on public.payments;
drop policy if exists "payments_update_owner"  on public.payments;
drop policy if exists "payments_insert_owner"  on public.payments;

-- Tenant: read only their own payments
create policy "payments_select_own"
  on public.payments for select
  using (auth.uid() = tenant_id);

-- Owner: read payments for their tenants
create policy "payments_select_owner"
  on public.payments for select
  using (
    public.my_role() = 'owner'
    and exists (
      select 1 from public.tenants t
      join   public.rooms r on r.id = t.room_id
      where  t.id = public.payments.tenant_id
      and    r.owner_id = auth.uid()
    )
  );

-- Owner: update payment status (mark paid / overdue)
create policy "payments_update_owner"
  on public.payments for update
  using (
    public.my_role() = 'owner'
    and exists (
      select 1 from public.tenants t
      join   public.rooms r on r.id = t.room_id
      where  t.id = public.payments.tenant_id
      and    r.owner_id = auth.uid()
    )
  );

-- Owner: create payment records for their tenants
create policy "payments_insert_owner"
  on public.payments for insert
  with check (
    public.my_role() = 'owner'
    and exists (
      select 1 from public.tenants t
      join   public.rooms r on r.id = t.room_id
      where  t.id = public.payments.tenant_id
      and    r.owner_id = auth.uid()
    )
  );

-- ============================================================
-- notification_log policies
-- Service role (Edge Functions) handles inserts — no user policy needed
-- ============================================================
create policy "notif_log_select_own"
  on public.notification_log for select
  using (auth.uid() = tenant_id);
