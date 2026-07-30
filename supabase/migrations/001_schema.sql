-- ============================================================
-- 001_schema.sql  — PG Management App Core Schema
-- Run this in: Supabase SQL Editor → New Query
-- ============================================================

-- Enable UUID generation
create extension if not exists "uuid-ossp";

-- ============================================================
-- profiles
-- One row per auth.users entry; role is either 'owner' or 'tenant'
-- ============================================================
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  role        text not null check (role in ('owner', 'tenant')),
  full_name   text not null,
  phone       text,
  upi_id      text,                    -- only populated for owners
  push_token  text,                    -- Expo push notification token
  created_at  timestamptz default now()
);

-- ============================================================
-- rooms
-- Created by owners; tenants are assigned to a room
-- ============================================================
create table if not exists public.rooms (
  id            uuid primary key default uuid_generate_v4(),
  owner_id      uuid not null references public.profiles(id) on delete cascade,
  room_number   text not null,
  rent_amount   numeric(10,2) not null,
  capacity      integer not null default 1,
  status        text not null default 'vacant' check (status in ('vacant', 'occupied')),
  created_at    timestamptz default now()
);

-- ============================================================
-- tenants
-- Extends the profiles row for a tenant; links to a room
-- ============================================================
create table if not exists public.tenants (
  id                  uuid primary key references public.profiles(id) on delete cascade,
  room_id             uuid references public.rooms(id) on delete set null,
  move_in_date        date,
  aadhaar_self_url    text,
  aadhaar_father_url  text,
  aadhaar_mother_url  text,
  doc_status          text not null default 'pending'
                        check (doc_status in ('pending', 'verified', 'rejected')),
  created_at          timestamptz default now()
);

-- ============================================================
-- payments
-- One row per monthly (or any periodic) payment due
-- ============================================================
create table if not exists public.payments (
  id          uuid primary key default uuid_generate_v4(),
  tenant_id   uuid not null references public.tenants(id) on delete cascade,
  due_date    date not null,
  amount      numeric(10,2) not null,
  status      text not null default 'pending'
                check (status in ('pending', 'paid', 'overdue')),
  paid_date   date,
  created_at  timestamptz default now()
);

-- ============================================================
-- notification_log
-- Prevents duplicate push/email sends for the same event
-- ============================================================
create table if not exists public.notification_log (
  id          uuid primary key default uuid_generate_v4(),
  tenant_id   uuid not null references public.tenants(id) on delete cascade,
  payment_id  uuid not null references public.payments(id) on delete cascade,
  type        text not null check (type in ('push', 'email')),
  sent_at     timestamptz default now(),
  unique (tenant_id, payment_id, type)
);

-- ============================================================
-- Indexes for common query patterns
-- ============================================================
create index if not exists idx_rooms_owner         on public.rooms(owner_id);
create index if not exists idx_tenants_room        on public.tenants(room_id);
create index if not exists idx_payments_tenant     on public.payments(tenant_id);
create index if not exists idx_payments_due_date   on public.payments(due_date);
create index if not exists idx_payments_status     on public.payments(status);
create index if not exists idx_notif_log_payment   on public.notification_log(payment_id);
