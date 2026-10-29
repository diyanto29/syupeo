-- Base schema for:
-- Google Sign In via supabase.auth.signInWithIdToken(...)
-- First app role defaults to OWNER
-- Future-ready for waiter, kitchen, cashier, admin memberships

create extension if not exists pgcrypto;

do $$
begin
  if not exists (
    select 1
    from pg_type
    where typname = 'app_role'
  ) then
    create type public.app_role as enum (
      'owner',
      'admin',
      'cashier',
      'waiter',
      'kitchen',
      'customer'
    );
  end if;

  if not exists (
    select 1
    from pg_type
    where typname = 'membership_status'
  ) then
    create type public.membership_status as enum (
      'active',
      'invited',
      'disabled'
    );
  end if;
end
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text,
  phone text,
  full_name text,
  avatar_url text,
  auth_provider text not null default 'google',
  default_role public.app_role not null default 'owner',
  is_active boolean not null default true,
  onboarding_completed boolean not null default false,
  last_sign_in_at timestamptz,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create unique index if not exists profiles_email_unique_idx
  on public.profiles (lower(email))
  where email is not null;

create unique index if not exists profiles_phone_unique_idx
  on public.profiles (phone)
  where phone is not null;

create table if not exists public.businesses (
  id uuid primary key default gen_random_uuid(),
  owner_user_id uuid not null references public.profiles (id) on delete restrict,
  name text not null,
  slug text unique,
  legal_name text,
  phone text,
  email text,
  currency_code text not null default 'IDR',
  timezone text not null default 'Asia/Jakarta',
  settings jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create index if not exists businesses_owner_user_id_idx
  on public.businesses (owner_user_id);

create table if not exists public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.app_role not null,
  status public.membership_status not null default 'active',
  invited_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (business_id, user_id)
);

create index if not exists business_members_user_id_idx
  on public.business_members (user_id);

create index if not exists business_members_business_id_idx
  on public.business_members (business_id);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = timezone('utc', now());
  return new;
end;
$$;

drop trigger if exists set_profiles_updated_at on public.profiles;
create trigger set_profiles_updated_at
before update on public.profiles
for each row
execute function public.set_updated_at();

drop trigger if exists set_businesses_updated_at on public.businesses;
create trigger set_businesses_updated_at
before update on public.businesses
for each row
execute function public.set_updated_at();

drop trigger if exists set_business_members_updated_at on public.business_members;
create trigger set_business_members_updated_at
before update on public.business_members
for each row
execute function public.set_updated_at();

create or replace function public.handle_auth_user_upsert()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  provider_name text;
begin
  provider_name := coalesce(new.raw_app_meta_data ->> 'provider', 'google');

  insert into public.profiles (
    id,
    email,
    phone,
    full_name,
    avatar_url,
    auth_provider,
    default_role,
    last_sign_in_at
  )
  values (
    new.id,
    new.email,
    new.phone,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name'
    ),
    new.raw_user_meta_data ->> 'avatar_url',
    provider_name,
    'owner',
    timezone('utc', now())
  )
  on conflict (id) do update
  set
    email = excluded.email,
    phone = excluded.phone,
    full_name = coalesce(excluded.full_name, public.profiles.full_name),
    avatar_url = coalesce(excluded.avatar_url, public.profiles.avatar_url),
    auth_provider = coalesce(excluded.auth_provider, public.profiles.auth_provider),
    last_sign_in_at = timezone('utc', now()),
    updated_at = timezone('utc', now());

  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row
execute function public.handle_auth_user_upsert();

drop trigger if exists on_auth_user_updated on auth.users;
create trigger on_auth_user_updated
after update on auth.users
for each row
execute function public.handle_auth_user_upsert();

alter table public.profiles enable row level security;
alter table public.businesses enable row level security;
alter table public.business_members enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
on public.profiles
for select
to authenticated
using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
on public.profiles
for update
to authenticated
using (auth.uid() = id)
with check (auth.uid() = id);

drop policy if exists "businesses_select_member" on public.businesses;
create policy "businesses_select_member"
on public.businesses
for select
to authenticated
using (
  owner_user_id = auth.uid()
  or exists (
    select 1
    from public.business_members bm
    where bm.business_id = businesses.id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
  )
);

drop policy if exists "businesses_insert_owner" on public.businesses;
create policy "businesses_insert_owner"
on public.businesses
for insert
to authenticated
with check (owner_user_id = auth.uid());

drop policy if exists "businesses_update_owner" on public.businesses;
create policy "businesses_update_owner"
on public.businesses
for update
to authenticated
using (owner_user_id = auth.uid())
with check (owner_user_id = auth.uid());

drop policy if exists "business_members_select_related" on public.business_members;
create policy "business_members_select_related"
on public.business_members
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.businesses b
    where b.id = business_members.business_id
      and b.owner_user_id = auth.uid()
  )
);

drop policy if exists "business_members_insert_owner" on public.business_members;
create policy "business_members_insert_owner"
on public.business_members
for insert
to authenticated
with check (
  exists (
    select 1
    from public.businesses b
    where b.id = business_id
      and b.owner_user_id = auth.uid()
  )
  and (
    auth.uid() = user_id
    or exists (
      select 1
      from public.businesses b
      where b.id = business_id
        and b.owner_user_id = auth.uid()
    )
  )
);

drop policy if exists "business_members_update_owner" on public.business_members;
create policy "business_members_update_owner"
on public.business_members
for update
to authenticated
using (
  exists (
    select 1
    from public.businesses b
    where b.id = business_members.business_id
      and b.owner_user_id = auth.uid()
  )
)
with check (
  exists (
    select 1
    from public.businesses b
    where b.id = business_members.business_id
      and b.owner_user_id = auth.uid()
  )
);

comment on table public.profiles is
'Mirror table from auth.users for app-specific profile data. Default role is owner for Google sign-in onboarding.';

comment on table public.businesses is
'Tenant/store/business root entity owned by the first Google-authenticated owner.';

comment on table public.business_members is
'Role mapping per business for owner/admin/cashier/waiter/kitchen expansion.';
