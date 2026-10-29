-- ====================================================================
-- MANGGA POS - SUPABASE FULL SCHEMA INITIALIZATION BUNDLE
-- Target Project: https://kjekiseloobdxomicolo.supabase.co
-- Generated automatically with correct table dependency order
-- ====================================================================

-- ==========================================
-- >>> START FILE: 20260415_google_owner_auth_base.sql >>>
-- ==========================================
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
-- <<< END FILE: 20260415_google_owner_auth_base.sql <<<

-- ==========================================
-- >>> START FILE: 20260415_fix_business_rls_recursion.sql >>>
-- ==========================================
-- Fix infinite recursion between:
-- - businesses_select_member
-- - business_members_select_related
--
-- Root cause:
-- businesses policy checks business_members,
-- while business_members policy checks businesses.
-- This creates recursive RLS evaluation.

create or replace function public.is_business_owner(target_business_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.businesses b
    where b.id = target_business_id
      and b.owner_user_id = auth.uid()
  );
end;
$$;

create or replace function public.is_business_member(
  target_business_id uuid,
  target_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.business_members bm
    where bm.business_id = target_business_id
      and bm.user_id = target_user_id
      and bm.status = 'active'
  );
end;
$$;

revoke all on function public.is_business_owner(uuid) from public;
revoke all on function public.is_business_member(uuid, uuid) from public;
grant execute on function public.is_business_owner(uuid) to authenticated;
grant execute on function public.is_business_member(uuid, uuid) to authenticated;

drop policy if exists "businesses_select_member" on public.businesses;
create policy "businesses_select_member"
on public.businesses
for select
to authenticated
using (
  owner_user_id = auth.uid()
  or public.is_business_member(id, auth.uid())
);

drop policy if exists "business_members_select_related" on public.business_members;
create policy "business_members_select_related"
on public.business_members
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_business_owner(business_id)
);

drop policy if exists "business_members_insert_owner" on public.business_members;
create policy "business_members_insert_owner"
on public.business_members
for insert
to authenticated
with check (
  public.is_business_owner(business_id)
  or (
    auth.uid() = user_id
    and role = 'owner'
    and public.is_business_owner(business_id)
  )
);

drop policy if exists "business_members_update_owner" on public.business_members;
create policy "business_members_update_owner"
on public.business_members
for update
to authenticated
using (public.is_business_owner(business_id))
with check (public.is_business_owner(business_id));
-- <<< END FILE: 20260415_fix_business_rls_recursion.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_multi_outlet_foundation.sql >>>
-- ==========================================
create table if not exists public.outlets (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null,
  code text,
  address text,
  phone text,
  timezone text not null default 'Asia/Jakarta',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (business_id, code)
);

create index if not exists outlets_business_id_idx
  on public.outlets (business_id);

create table if not exists public.outlet_members (
  id uuid primary key default gen_random_uuid(),
  outlet_id uuid not null references public.outlets (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.app_role not null,
  status public.membership_status not null default 'active',
  assigned_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (outlet_id, user_id)
);

create index if not exists outlet_members_outlet_id_idx
  on public.outlet_members (outlet_id);

create index if not exists outlet_members_user_id_idx
  on public.outlet_members (user_id);

drop trigger if exists set_outlets_updated_at on public.outlets;
create trigger set_outlets_updated_at
before update on public.outlets
for each row
execute function public.set_updated_at();

drop trigger if exists set_outlet_members_updated_at on public.outlet_members;
create trigger set_outlet_members_updated_at
before update on public.outlet_members
for each row
execute function public.set_updated_at();

alter table public.outlets enable row level security;
alter table public.outlet_members enable row level security;

drop policy if exists "outlets_select_related" on public.outlets;
create policy "outlets_select_related"
on public.outlets
for select
to authenticated
using (
  exists (
    select 1
    from public.businesses b
    where b.id = outlets.business_id
      and b.owner_user_id = auth.uid()
  )
  or exists (
    select 1
    from public.business_members bm
    where bm.business_id = outlets.business_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
  )
  or exists (
    select 1
    from public.outlet_members om
    where om.outlet_id = outlets.id
      and om.user_id = auth.uid()
      and om.status = 'active'
  )
);

drop policy if exists "outlets_insert_owner" on public.outlets;
create policy "outlets_insert_owner"
on public.outlets
for insert
to authenticated
with check (public.is_business_owner(business_id));

drop policy if exists "outlets_update_owner" on public.outlets;
create policy "outlets_update_owner"
on public.outlets
for update
to authenticated
using (public.is_business_owner(business_id))
with check (public.is_business_owner(business_id));

drop policy if exists "outlet_members_select_related" on public.outlet_members;
create policy "outlet_members_select_related"
on public.outlet_members
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.outlets o
    where o.id = outlet_members.outlet_id
      and public.is_business_owner(o.business_id)
  )
);

drop policy if exists "outlet_members_insert_owner" on public.outlet_members;
create policy "outlet_members_insert_owner"
on public.outlet_members
for insert
to authenticated
with check (
  exists (
    select 1
    from public.outlets o
    where o.id = outlet_id
      and public.is_business_owner(o.business_id)
  )
);

drop policy if exists "outlet_members_update_owner" on public.outlet_members;
create policy "outlet_members_update_owner"
on public.outlet_members
for update
to authenticated
using (
  exists (
    select 1
    from public.outlets o
    where o.id = outlet_members.outlet_id
      and public.is_business_owner(o.business_id)
  )
)
with check (
  exists (
    select 1
    from public.outlets o
    where o.id = outlet_id
      and public.is_business_owner(o.business_id)
  )
);

insert into public.outlets (
  business_id,
  name,
  code,
  phone,
  timezone,
  is_active
)
select
  b.id,
  b.name,
  'main',
  b.phone,
  b.timezone,
  true
from public.businesses b
where not exists (
  select 1
  from public.outlets o
  where o.business_id = b.id
);

insert into public.outlet_members (
  outlet_id,
  user_id,
  role,
  status,
  assigned_by
)
select
  o.id,
  bm.user_id,
  bm.role,
  bm.status,
  bm.invited_by
from public.outlets o
join public.business_members bm
  on bm.business_id = o.business_id
where not exists (
  select 1
  from public.outlet_members om
  where om.outlet_id = o.id
    and om.user_id = bm.user_id
);
-- <<< END FILE: 20260416_multi_outlet_foundation.sql <<<

-- ==========================================
-- >>> START FILE: 202604161500_fix_outlets_rls_recursion.sql >>>
-- ==========================================
-- Fix infinite recursion between:
-- - outlets_select_related
-- - outlet_members_select_related
--
-- Root cause:
-- outlets policy queries outlet_members,
-- while outlet_members policy queries outlets.
-- This creates recursive RLS evaluation during outlet bootstrap after login.

create or replace function public.is_outlet_member(
  target_outlet_id uuid,
  target_user_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.outlet_members om
    where om.outlet_id = target_outlet_id
      and om.user_id = target_user_id
      and om.status = 'active'
  );
end;
$$;

create or replace function public.is_outlet_business_owner(
  target_outlet_id uuid
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  return exists (
    select 1
    from public.outlets o
    join public.businesses b
      on b.id = o.business_id
    where o.id = target_outlet_id
      and b.owner_user_id = auth.uid()
  );
end;
$$;

revoke all on function public.is_outlet_member(uuid, uuid) from public;
revoke all on function public.is_outlet_business_owner(uuid) from public;
grant execute on function public.is_outlet_member(uuid, uuid) to authenticated;
grant execute on function public.is_outlet_business_owner(uuid) to authenticated;

drop policy if exists "outlets_select_related" on public.outlets;
create policy "outlets_select_related"
on public.outlets
for select
to authenticated
using (
  public.is_business_owner(business_id)
  or public.is_business_member(business_id, auth.uid())
  or public.is_outlet_member(id, auth.uid())
);

drop policy if exists "outlet_members_select_related" on public.outlet_members;
create policy "outlet_members_select_related"
on public.outlet_members
for select
to authenticated
using (
  user_id = auth.uid()
  or public.is_outlet_business_owner(outlet_id)
);

drop policy if exists "outlet_members_insert_owner" on public.outlet_members;
create policy "outlet_members_insert_owner"
on public.outlet_members
for insert
to authenticated
with check (
  public.is_outlet_business_owner(outlet_id)
);

drop policy if exists "outlet_members_update_owner" on public.outlet_members;
create policy "outlet_members_update_owner"
on public.outlet_members
for update
to authenticated
using (
  public.is_outlet_business_owner(outlet_id)
)
with check (
  public.is_outlet_business_owner(outlet_id)
);
-- <<< END FILE: 202604161500_fix_outlets_rls_recursion.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_staff_avatar_storage.sql >>>
-- ==========================================
insert into storage.buckets (id, name, public)
values ('staff-avatars', 'staff-avatars', true)
on conflict (id) do nothing;

drop policy if exists "staff_avatars_public_read" on storage.objects;
create policy "staff_avatars_public_read"
on storage.objects
for select
to public
using (bucket_id = 'staff-avatars');

drop policy if exists "staff_avatars_authenticated_upload" on storage.objects;
create policy "staff_avatars_authenticated_upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'staff-avatars');

drop policy if exists "staff_avatars_authenticated_update" on storage.objects;
create policy "staff_avatars_authenticated_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'staff-avatars')
with check (bucket_id = 'staff-avatars');
-- <<< END FILE: 20260416_staff_avatar_storage.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_add_staff_code_to_profiles.sql >>>
-- ==========================================
alter table public.profiles
add column if not exists staff_code text;

create unique index if not exists profiles_staff_code_unique_idx
  on public.profiles (lower(staff_code))
  where staff_code is not null;
-- <<< END FILE: 20260416_add_staff_code_to_profiles.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_staff_invitations_flow.sql >>>
-- ==========================================
create extension if not exists pgcrypto with schema extensions;

create table if not exists public.staff_invitations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  staff_code text not null,
  full_name text,
  email text,
  avatar_url text,
  role public.app_role not null,
  status public.membership_status not null default 'invited',
  initial_password_hash text,
  invited_by uuid references public.profiles (id) on delete set null,
  claimed_by_user_id uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (business_id, staff_code)
);

drop trigger if exists set_staff_invitations_updated_at on public.staff_invitations;
create trigger set_staff_invitations_updated_at
before update on public.staff_invitations
for each row
execute function public.set_updated_at();

alter table public.staff_invitations enable row level security;

drop policy if exists "staff_invitations_select_owner" on public.staff_invitations;
create policy "staff_invitations_select_owner"
on public.staff_invitations
for select
to authenticated
using (public.is_business_owner(business_id));

drop policy if exists "staff_invitations_insert_owner" on public.staff_invitations;
create policy "staff_invitations_insert_owner"
on public.staff_invitations
for insert
to authenticated
with check (public.is_business_owner(business_id));

drop policy if exists "staff_invitations_update_owner" on public.staff_invitations;
create policy "staff_invitations_update_owner"
on public.staff_invitations
for update
to authenticated
using (public.is_business_owner(business_id))
with check (public.is_business_owner(business_id));

drop function if exists public.upsert_business_staff_entry(
  uuid,
  text,
  public.app_role,
  public.membership_status,
  text,
  text,
  text,
  text
);

create or replace function public.upsert_business_staff_entry(
  target_business_id uuid,
  target_identifier text,
  target_role public.app_role,
  target_status public.membership_status default 'active',
  target_full_name text default null,
  target_avatar_url text default null,
  target_staff_code text default null,
  target_initial_password text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_identifier text;
  normalized_staff_code text;
  target_profile_id uuid;
  member_row public.business_members;
  invite_row public.staff_invitations;
begin
  if not public.is_business_owner(target_business_id) then
    raise exception 'Hanya owner bisnis yang dapat menambahkan user.';
  end if;

  normalized_identifier := lower(trim(target_identifier));
  normalized_staff_code := coalesce(nullif(lower(trim(target_staff_code)), ''), normalized_identifier);

  if normalized_identifier is null or normalized_identifier = '' then
    raise exception 'Staff ID wajib diisi.';
  end if;

  select p.id
  into target_profile_id
  from public.profiles p
  where lower(coalesce(p.staff_code, '')) = normalized_identifier
     or lower(coalesce(p.email, '')) = normalized_identifier
  limit 1;

  if target_profile_id is not null then
    update public.profiles
    set
      full_name = coalesce(nullif(trim(target_full_name), ''), full_name),
      avatar_url = coalesce(nullif(trim(target_avatar_url), ''), avatar_url),
      staff_code = coalesce(normalized_staff_code, staff_code),
      updated_at = timezone('utc', now())
    where id = target_profile_id;

    insert into public.business_members (
      business_id,
      user_id,
      role,
      status,
      invited_by
    )
    values (
      target_business_id,
      target_profile_id,
      target_role,
      target_status,
      auth.uid()
    )
    on conflict (business_id, user_id) do update
    set
      role = excluded.role,
      status = excluded.status,
      invited_by = excluded.invited_by,
      updated_at = timezone('utc', now())
    returning *
    into member_row;

    delete from public.staff_invitations
    where business_id = target_business_id
      and staff_code = normalized_staff_code;

    return jsonb_build_object(
      'kind', 'member',
      'business_member', to_jsonb(member_row)
    );
  end if;

  insert into public.staff_invitations (
    business_id,
    staff_code,
    full_name,
    email,
    avatar_url,
    role,
    status,
    initial_password_hash,
    invited_by
  )
  values (
    target_business_id,
    normalized_staff_code,
    nullif(trim(target_full_name), ''),
    case when position('@' in normalized_identifier) > 0 then normalized_identifier else null end,
    nullif(trim(target_avatar_url), ''),
    target_role,
    target_status,
    case
      when nullif(trim(target_initial_password), '') is null then null
      else extensions.crypt(
        trim(target_initial_password),
        extensions.gen_salt('bf')
      )
    end,
    auth.uid()
  )
  on conflict (business_id, staff_code) do update
  set
    full_name = excluded.full_name,
    email = coalesce(excluded.email, staff_invitations.email),
    avatar_url = coalesce(excluded.avatar_url, staff_invitations.avatar_url),
    role = excluded.role,
    status = excluded.status,
    initial_password_hash = coalesce(
      excluded.initial_password_hash,
      staff_invitations.initial_password_hash
    ),
    invited_by = excluded.invited_by,
    updated_at = timezone('utc', now())
  returning *
  into invite_row;

  return jsonb_build_object(
    'kind', 'invitation',
    'staff_invitation', to_jsonb(invite_row)
  );
end;
$$;

revoke all on function public.upsert_business_staff_entry(uuid, text, public.app_role, public.membership_status, text, text, text, text) from public;
grant execute on function public.upsert_business_staff_entry(uuid, text, public.app_role, public.membership_status, text, text, text, text) to authenticated;
-- <<< END FILE: 20260416_staff_invitations_flow.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_hash_staff_invitation_passwords.sql >>>
-- ==========================================
create extension if not exists pgcrypto with schema extensions;

alter table public.staff_invitations
add column if not exists initial_password_hash text;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'staff_invitations'
      and column_name = 'initial_password'
  ) then
    execute $sql$
      update public.staff_invitations
      set initial_password_hash = coalesce(
        initial_password_hash,
        case
          when nullif(trim(initial_password), '') is null then null
          else extensions.crypt(
            trim(initial_password),
            extensions.gen_salt('bf')
          )
        end
      )
      where initial_password is not null
    $sql$;

    execute 'alter table public.staff_invitations drop column initial_password';
  end if;
end
$$;
-- <<< END FILE: 20260416_hash_staff_invitation_passwords.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_claim_staff_invitation.sql >>>
-- ==========================================
create extension if not exists pgcrypto with schema extensions;

drop function if exists public.claim_staff_invitation(text, text);

create or replace function public.claim_staff_invitation(
  target_identifier text,
  target_initial_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_identifier text;
  invite_row public.staff_invitations;
  member_row public.business_members;
begin
  if auth.uid() is null then
    raise exception 'User auth belum tersedia.';
  end if;

  normalized_identifier := lower(trim(target_identifier));
  if normalized_identifier is null or normalized_identifier = '' then
    raise exception 'Staff ID wajib diisi.';
  end if;

  select *
  into invite_row
  from public.staff_invitations si
  where lower(si.staff_code) = normalized_identifier
     or lower(coalesce(si.email, '')) = normalized_identifier
  limit 1;

  if invite_row.id is null then
    raise exception 'Invitation tidak ditemukan untuk staff ID %.', normalized_identifier;
  end if;

  if invite_row.claimed_by_user_id is not null
     and invite_row.claimed_by_user_id <> auth.uid() then
    raise exception 'Invitation ini sudah diklaim user lain.';
  end if;

  if invite_row.initial_password_hash is null
     or extensions.crypt(
       coalesce(target_initial_password, ''),
       invite_row.initial_password_hash
     ) <> invite_row.initial_password_hash then
    raise exception 'Password awal tidak sesuai.';
  end if;

  update public.profiles
  set
    full_name = coalesce(invite_row.full_name, full_name),
    avatar_url = coalesce(invite_row.avatar_url, avatar_url),
    staff_code = coalesce(invite_row.staff_code, staff_code),
    default_role = invite_row.role,
    onboarding_completed = true,
    updated_at = timezone('utc', now())
  where id = auth.uid();

  insert into public.business_members (
    business_id,
    user_id,
    role,
    status,
    invited_by
  )
  values (
    invite_row.business_id,
    auth.uid(),
    invite_row.role,
    'active',
    invite_row.invited_by
  )
  on conflict (business_id, user_id) do update
  set
    role = excluded.role,
    status = excluded.status,
    invited_by = excluded.invited_by,
    updated_at = timezone('utc', now())
  returning *
  into member_row;

  update public.staff_invitations
  set
    claimed_by_user_id = auth.uid(),
    status = 'active',
    updated_at = timezone('utc', now())
  where id = invite_row.id;

  return jsonb_build_object(
    'business_member', to_jsonb(member_row),
    'business_id', invite_row.business_id,
    'role', invite_row.role
  );
end;
$$;

revoke all on function public.claim_staff_invitation(text, text) from public;
grant execute on function public.claim_staff_invitation(text, text) to authenticated;
-- <<< END FILE: 20260416_claim_staff_invitation.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_add_business_member_by_email.sql >>>
-- ==========================================
create or replace function public.add_business_member_by_email(
  target_business_id uuid,
  target_email text,
  target_role public.app_role,
  target_status public.membership_status default 'active'
)
returns public.business_members
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_email text;
  target_profile_id uuid;
  result_row public.business_members;
begin
  if not public.is_business_owner(target_business_id) then
    raise exception 'Hanya owner bisnis yang dapat menambahkan user.';
  end if;

  normalized_email := lower(trim(target_email));
  if normalized_email is null or normalized_email = '' then
    raise exception 'Email user wajib diisi.';
  end if;

  select p.id
  into target_profile_id
  from public.profiles p
  where lower(p.email) = normalized_email
  limit 1;

  if target_profile_id is null then
    raise exception 'User dengan email % belum terdaftar.', normalized_email;
  end if;

  insert into public.business_members (
    business_id,
    user_id,
    role,
    status,
    invited_by
  )
  values (
    target_business_id,
    target_profile_id,
    target_role,
    target_status,
    auth.uid()
  )
  on conflict (business_id, user_id) do update
  set
    role = excluded.role,
    status = excluded.status,
    invited_by = excluded.invited_by,
    updated_at = timezone('utc', now())
  returning *
  into result_row;

  return result_row;
end;
$$;

revoke all on function public.add_business_member_by_email(uuid, text, public.app_role, public.membership_status) from public;
grant execute on function public.add_business_member_by_email(uuid, text, public.app_role, public.membership_status) to authenticated;
-- <<< END FILE: 20260416_add_business_member_by_email.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_extend_add_business_member_by_email.sql >>>
-- ==========================================
drop function if exists public.add_business_member_by_email(
  uuid,
  text,
  public.app_role,
  public.membership_status
);

create or replace function public.add_business_member_by_email(
  target_business_id uuid,
  target_identifier text,
  target_role public.app_role,
  target_status public.membership_status default 'active',
  target_full_name text default null,
  target_avatar_url text default null,
  target_staff_code text default null
)
returns public.business_members
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_identifier text;
  normalized_staff_code text;
  target_profile_id uuid;
  result_row public.business_members;
begin
  if not public.is_business_owner(target_business_id) then
    raise exception 'Hanya owner bisnis yang dapat menambahkan user.';
  end if;

  normalized_identifier := lower(trim(target_identifier));
  normalized_staff_code := nullif(trim(target_staff_code), '');

  if normalized_identifier is null or normalized_identifier = '' then
    raise exception 'Staff ID wajib diisi.';
  end if;

  select p.id
  into target_profile_id
  from public.profiles p
  where lower(coalesce(p.staff_code, '')) = normalized_identifier
     or lower(coalesce(p.email, '')) = normalized_identifier
  limit 1;

  if target_profile_id is null then
    raise exception 'User dengan staff ID % belum terdaftar.', normalized_identifier;
  end if;

  update public.profiles
  set
    full_name = coalesce(nullif(trim(target_full_name), ''), full_name),
    avatar_url = coalesce(nullif(trim(target_avatar_url), ''), avatar_url),
    staff_code = coalesce(normalized_staff_code, staff_code),
    updated_at = timezone('utc', now())
  where id = target_profile_id;

  insert into public.business_members (
    business_id,
    user_id,
    role,
    status,
    invited_by
  )
  values (
    target_business_id,
    target_profile_id,
    target_role,
    target_status,
    auth.uid()
  )
  on conflict (business_id, user_id) do update
  set
    role = excluded.role,
    status = excluded.status,
    invited_by = excluded.invited_by,
    updated_at = timezone('utc', now())
  returning *
  into result_row;

  return result_row;
end;
$$;

revoke all on function public.add_business_member_by_email(uuid, text, public.app_role, public.membership_status, text, text, text) from public;
grant execute on function public.add_business_member_by_email(uuid, text, public.app_role, public.membership_status, text, text, text) to authenticated;
-- <<< END FILE: 20260416_extend_add_business_member_by_email.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_fix_add_business_member_function_upgrade.sql >>>
-- ==========================================
drop function if exists public.add_business_member_by_email(
  uuid,
  text,
  public.app_role,
  public.membership_status
);

drop function if exists public.add_business_member_by_email(
  uuid,
  text,
  public.app_role,
  public.membership_status,
  text,
  text
);

drop function if exists public.add_business_member_by_email(
  uuid,
  text,
  public.app_role,
  public.membership_status,
  text,
  text,
  text
);

create or replace function public.add_business_member_by_email(
  target_business_id uuid,
  target_identifier text,
  target_role public.app_role,
  target_status public.membership_status default 'active',
  target_full_name text default null,
  target_avatar_url text default null,
  target_staff_code text default null
)
returns public.business_members
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_identifier text;
  normalized_staff_code text;
  target_profile_id uuid;
  result_row public.business_members;
begin
  if not public.is_business_owner(target_business_id) then
    raise exception 'Hanya owner bisnis yang dapat menambahkan user.';
  end if;

  normalized_identifier := lower(trim(target_identifier));
  normalized_staff_code := nullif(trim(target_staff_code), '');

  if normalized_identifier is null or normalized_identifier = '' then
    raise exception 'Staff ID wajib diisi.';
  end if;

  select p.id
  into target_profile_id
  from public.profiles p
  where lower(coalesce(p.staff_code, '')) = normalized_identifier
     or lower(coalesce(p.email, '')) = normalized_identifier
  limit 1;

  if target_profile_id is null then
    raise exception 'User dengan staff ID % belum terdaftar.', normalized_identifier;
  end if;

  update public.profiles
  set
    full_name = coalesce(nullif(trim(target_full_name), ''), full_name),
    avatar_url = coalesce(nullif(trim(target_avatar_url), ''), avatar_url),
    staff_code = coalesce(normalized_staff_code, staff_code),
    updated_at = timezone('utc', now())
  where id = target_profile_id;

  insert into public.business_members (
    business_id,
    user_id,
    role,
    status,
    invited_by
  )
  values (
    target_business_id,
    target_profile_id,
    target_role,
    target_status,
    auth.uid()
  )
  on conflict (business_id, user_id) do update
  set
    role = excluded.role,
    status = excluded.status,
    invited_by = excluded.invited_by,
    updated_at = timezone('utc', now())
  returning *
  into result_row;

  return result_row;
end;
$$;

revoke all on function public.add_business_member_by_email(uuid, text, public.app_role, public.membership_status, text, text, text) from public;
grant execute on function public.add_business_member_by_email(uuid, text, public.app_role, public.membership_status, text, text, text) to authenticated;
-- <<< END FILE: 20260416_fix_add_business_member_function_upgrade.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_fix_pgcrypto_staff_functions.sql >>>
-- ==========================================
create extension if not exists pgcrypto with schema extensions;

drop function if exists public.upsert_business_staff_entry(
  uuid,
  text,
  public.app_role,
  public.membership_status,
  text,
  text,
  text,
  text
);

create or replace function public.upsert_business_staff_entry(
  target_business_id uuid,
  target_identifier text,
  target_role public.app_role,
  target_status public.membership_status default 'active',
  target_full_name text default null,
  target_avatar_url text default null,
  target_staff_code text default null,
  target_initial_password text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_identifier text;
  normalized_staff_code text;
  target_profile_id uuid;
  member_row public.business_members;
  invite_row public.staff_invitations;
begin
  if not public.is_business_owner(target_business_id) then
    raise exception 'Hanya owner bisnis yang dapat menambahkan user.';
  end if;

  normalized_identifier := lower(trim(target_identifier));
  normalized_staff_code := coalesce(
    nullif(lower(trim(target_staff_code)), ''),
    normalized_identifier
  );

  if normalized_identifier is null or normalized_identifier = '' then
    raise exception 'Staff ID wajib diisi.';
  end if;

  select p.id
  into target_profile_id
  from public.profiles p
  where lower(coalesce(p.staff_code, '')) = normalized_identifier
     or lower(coalesce(p.email, '')) = normalized_identifier
  limit 1;

  if target_profile_id is not null then
    update public.profiles
    set
      full_name = coalesce(nullif(trim(target_full_name), ''), full_name),
      avatar_url = coalesce(nullif(trim(target_avatar_url), ''), avatar_url),
      staff_code = coalesce(normalized_staff_code, staff_code),
      updated_at = timezone('utc', now())
    where id = target_profile_id;

    insert into public.business_members (
      business_id,
      user_id,
      role,
      status,
      invited_by
    )
    values (
      target_business_id,
      target_profile_id,
      target_role,
      target_status,
      auth.uid()
    )
    on conflict (business_id, user_id) do update
    set
      role = excluded.role,
      status = excluded.status,
      invited_by = excluded.invited_by,
      updated_at = timezone('utc', now())
    returning *
    into member_row;

    delete from public.staff_invitations
    where business_id = target_business_id
      and staff_code = normalized_staff_code;

    return jsonb_build_object(
      'kind', 'member',
      'business_member', to_jsonb(member_row)
    );
  end if;

  insert into public.staff_invitations (
    business_id,
    staff_code,
    full_name,
    email,
    avatar_url,
    role,
    status,
    initial_password_hash,
    invited_by
  )
  values (
    target_business_id,
    normalized_staff_code,
    nullif(trim(target_full_name), ''),
    case
      when position('@' in normalized_identifier) > 0 then normalized_identifier
      else null
    end,
    nullif(trim(target_avatar_url), ''),
    target_role,
    target_status,
    case
      when nullif(trim(target_initial_password), '') is null then null
      else extensions.crypt(
        trim(target_initial_password),
        extensions.gen_salt('bf')
      )
    end,
    auth.uid()
  )
  on conflict (business_id, staff_code) do update
  set
    full_name = excluded.full_name,
    email = coalesce(excluded.email, staff_invitations.email),
    avatar_url = coalesce(excluded.avatar_url, staff_invitations.avatar_url),
    role = excluded.role,
    status = excluded.status,
    initial_password_hash = coalesce(
      excluded.initial_password_hash,
      staff_invitations.initial_password_hash
    ),
    invited_by = excluded.invited_by,
    updated_at = timezone('utc', now())
  returning *
  into invite_row;

  return jsonb_build_object(
    'kind', 'invitation',
    'staff_invitation', to_jsonb(invite_row)
  );
end;
$$;

revoke all on function public.upsert_business_staff_entry(uuid, text, public.app_role, public.membership_status, text, text, text, text) from public;
grant execute on function public.upsert_business_staff_entry(uuid, text, public.app_role, public.membership_status, text, text, text, text) to authenticated;

drop function if exists public.claim_staff_invitation(text, text);

create or replace function public.claim_staff_invitation(
  target_identifier text,
  target_initial_password text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_identifier text;
  invite_row public.staff_invitations;
  member_row public.business_members;
begin
  if auth.uid() is null then
    raise exception 'User auth belum tersedia.';
  end if;

  normalized_identifier := lower(trim(target_identifier));
  if normalized_identifier is null or normalized_identifier = '' then
    raise exception 'Staff ID wajib diisi.';
  end if;

  select *
  into invite_row
  from public.staff_invitations si
  where lower(si.staff_code) = normalized_identifier
     or lower(coalesce(si.email, '')) = normalized_identifier
  limit 1;

  if invite_row.id is null then
    raise exception 'Invitation tidak ditemukan untuk staff ID %.', normalized_identifier;
  end if;

  if invite_row.claimed_by_user_id is not null
     and invite_row.claimed_by_user_id <> auth.uid() then
    raise exception 'Invitation ini sudah diklaim user lain.';
  end if;

  if invite_row.initial_password_hash is null
     or extensions.crypt(
       coalesce(target_initial_password, ''),
       invite_row.initial_password_hash
     ) <> invite_row.initial_password_hash then
    raise exception 'Password awal tidak sesuai.';
  end if;

  update public.profiles
  set
    full_name = coalesce(invite_row.full_name, full_name),
    avatar_url = coalesce(invite_row.avatar_url, avatar_url),
    staff_code = coalesce(invite_row.staff_code, staff_code),
    default_role = invite_row.role,
    onboarding_completed = true,
    updated_at = timezone('utc', now())
  where id = auth.uid();

  insert into public.business_members (
    business_id,
    user_id,
    role,
    status,
    invited_by
  )
  values (
    invite_row.business_id,
    auth.uid(),
    invite_row.role,
    'active',
    invite_row.invited_by
  )
  on conflict (business_id, user_id) do update
  set
    role = excluded.role,
    status = excluded.status,
    invited_by = excluded.invited_by,
    updated_at = timezone('utc', now())
  returning *
  into member_row;

  update public.staff_invitations
  set
    claimed_by_user_id = auth.uid(),
    status = 'active',
    updated_at = timezone('utc', now())
  where id = invite_row.id;

  return jsonb_build_object(
    'business_member', to_jsonb(member_row),
    'business_id', invite_row.business_id,
    'role', invite_row.role
  );
end;
$$;

revoke all on function public.claim_staff_invitation(text, text) from public;
grant execute on function public.claim_staff_invitation(text, text) to authenticated;

drop function if exists public.update_business_staff_entry(
  uuid,
  uuid,
  text,
  public.app_role,
  public.membership_status,
  text,
  text,
  text,
  text
);

create or replace function public.update_business_staff_entry(
  target_business_id uuid,
  target_entry_id uuid,
  target_kind text,
  target_role public.app_role,
  target_status public.membership_status default 'active',
  target_full_name text default null,
  target_avatar_url text default null,
  target_staff_code text default null,
  target_initial_password text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_kind text;
  normalized_staff_code text;
  member_row public.business_members;
  invite_row public.staff_invitations;
  member_user_id uuid;
begin
  if not public.is_business_owner(target_business_id) then
    raise exception 'Hanya owner bisnis yang dapat mengubah user.';
  end if;

  normalized_kind := lower(trim(target_kind));
  normalized_staff_code := nullif(lower(trim(target_staff_code)), '');

  if normalized_kind = 'member' then
    select bm.user_id
    into member_user_id
    from public.business_members bm
    where bm.id = target_entry_id
      and bm.business_id = target_business_id;

    if member_user_id is null then
      raise exception 'Membership staff tidak ditemukan.';
    end if;

    if member_user_id = auth.uid() then
      raise exception 'Owner utama tidak bisa diubah dari halaman ini.';
    end if;

    update public.profiles
    set
      full_name = coalesce(nullif(trim(target_full_name), ''), full_name),
      avatar_url = coalesce(nullif(trim(target_avatar_url), ''), avatar_url),
      staff_code = coalesce(normalized_staff_code, staff_code),
      updated_at = timezone('utc', now())
    where id = member_user_id;

    update public.business_members
    set
      role = target_role,
      status = target_status,
      updated_at = timezone('utc', now())
    where id = target_entry_id
      and business_id = target_business_id
    returning *
    into member_row;

    return jsonb_build_object(
      'kind', 'member',
      'business_member', to_jsonb(member_row)
    );
  elsif normalized_kind = 'invitation' then
    update public.staff_invitations
    set
      full_name = nullif(trim(target_full_name), ''),
      avatar_url = coalesce(nullif(trim(target_avatar_url), ''), avatar_url),
      staff_code = coalesce(normalized_staff_code, staff_code),
      role = target_role,
      status = target_status,
      initial_password_hash = coalesce(
        case
          when nullif(trim(target_initial_password), '') is null then null
          else extensions.crypt(
            trim(target_initial_password),
            extensions.gen_salt('bf')
          )
        end,
        initial_password_hash
      ),
      updated_at = timezone('utc', now())
    where id = target_entry_id
      and business_id = target_business_id
    returning *
    into invite_row;

    if invite_row.id is null then
      raise exception 'Invitation staff tidak ditemukan.';
    end if;

    return jsonb_build_object(
      'kind', 'invitation',
      'staff_invitation', to_jsonb(invite_row)
    );
  else
    raise exception 'Jenis staff entry tidak dikenali.';
  end if;
end;
$$;

revoke all on function public.update_business_staff_entry(uuid, uuid, text, public.app_role, public.membership_status, text, text, text, text) from public;
grant execute on function public.update_business_staff_entry(uuid, uuid, text, public.app_role, public.membership_status, text, text, text, text) to authenticated;
-- <<< END FILE: 20260416_fix_pgcrypto_staff_functions.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_owner_can_read_business_member_profiles.sql >>>
-- ==========================================
-- Allow business owners to read profile basics of users who belong to
-- their business so the management-user screen can show real names/avatars.

drop policy if exists "profiles_select_related_business_owner" on public.profiles;
create policy "profiles_select_related_business_owner"
on public.profiles
for select
to authenticated
using (
  auth.uid() = id
  or exists (
    select 1
    from public.business_members bm
    where bm.user_id = profiles.id
      and public.is_business_owner(bm.business_id)
  )
);
-- <<< END FILE: 20260416_owner_can_read_business_member_profiles.sql <<<

-- ==========================================
-- >>> START FILE: 20260416_update_delete_business_staff_entry.sql >>>
-- ==========================================
create extension if not exists pgcrypto with schema extensions;

drop function if exists public.update_business_staff_entry(
  uuid,
  uuid,
  text,
  public.app_role,
  public.membership_status,
  text,
  text,
  text,
  text
);

create or replace function public.update_business_staff_entry(
  target_business_id uuid,
  target_entry_id uuid,
  target_kind text,
  target_role public.app_role,
  target_status public.membership_status default 'active',
  target_full_name text default null,
  target_avatar_url text default null,
  target_staff_code text default null,
  target_initial_password text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_kind text;
  normalized_staff_code text;
  member_row public.business_members;
  invite_row public.staff_invitations;
  member_user_id uuid;
begin
  if not public.is_business_owner(target_business_id) then
    raise exception 'Hanya owner bisnis yang dapat mengubah user.';
  end if;

  normalized_kind := lower(trim(target_kind));
  normalized_staff_code := nullif(lower(trim(target_staff_code)), '');

  if normalized_kind = 'member' then
    select bm.user_id
    into member_user_id
    from public.business_members bm
    where bm.id = target_entry_id
      and bm.business_id = target_business_id;

    if member_user_id is null then
      raise exception 'Membership staff tidak ditemukan.';
    end if;

    if member_user_id = auth.uid() then
      raise exception 'Owner utama tidak bisa diubah dari halaman ini.';
    end if;

    update public.profiles
    set
      full_name = coalesce(nullif(trim(target_full_name), ''), full_name),
      avatar_url = coalesce(nullif(trim(target_avatar_url), ''), avatar_url),
      staff_code = coalesce(normalized_staff_code, staff_code),
      updated_at = timezone('utc', now())
    where id = member_user_id;

    update public.business_members
    set
      role = target_role,
      status = target_status,
      updated_at = timezone('utc', now())
    where id = target_entry_id
      and business_id = target_business_id
    returning *
    into member_row;

    return jsonb_build_object(
      'kind', 'member',
      'business_member', to_jsonb(member_row)
    );
  elsif normalized_kind = 'invitation' then
    update public.staff_invitations
    set
      full_name = nullif(trim(target_full_name), ''),
      avatar_url = coalesce(nullif(trim(target_avatar_url), ''), avatar_url),
      staff_code = coalesce(normalized_staff_code, staff_code),
      role = target_role,
      status = target_status,
      initial_password_hash = coalesce(
        case
          when nullif(trim(target_initial_password), '') is null then null
          else extensions.crypt(
            trim(target_initial_password),
            extensions.gen_salt('bf')
          )
        end,
        initial_password_hash
      ),
      updated_at = timezone('utc', now())
    where id = target_entry_id
      and business_id = target_business_id
    returning *
    into invite_row;

    if invite_row.id is null then
      raise exception 'Invitation staff tidak ditemukan.';
    end if;

    return jsonb_build_object(
      'kind', 'invitation',
      'staff_invitation', to_jsonb(invite_row)
    );
  else
    raise exception 'Jenis staff entry tidak dikenali.';
  end if;
end;
$$;

revoke all on function public.update_business_staff_entry(uuid, uuid, text, public.app_role, public.membership_status, text, text, text, text) from public;
grant execute on function public.update_business_staff_entry(uuid, uuid, text, public.app_role, public.membership_status, text, text, text, text) to authenticated;

drop function if exists public.delete_business_staff_entry(uuid, uuid, text);

create or replace function public.delete_business_staff_entry(
  target_business_id uuid,
  target_entry_id uuid,
  target_kind text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_kind text;
  member_user_id uuid;
begin
  if not public.is_business_owner(target_business_id) then
    raise exception 'Hanya owner bisnis yang dapat menghapus user.';
  end if;

  normalized_kind := lower(trim(target_kind));

  if normalized_kind = 'member' then
    select bm.user_id
    into member_user_id
    from public.business_members bm
    where bm.id = target_entry_id
      and bm.business_id = target_business_id;

    if member_user_id is null then
      raise exception 'Membership staff tidak ditemukan.';
    end if;

    if member_user_id = auth.uid() then
      raise exception 'Owner utama tidak bisa dihapus.';
    end if;

    delete from public.business_members
    where id = target_entry_id
      and business_id = target_business_id;
  elsif normalized_kind = 'invitation' then
    delete from public.staff_invitations
    where id = target_entry_id
      and business_id = target_business_id;
  else
    raise exception 'Jenis staff entry tidak dikenali.';
  end if;
end;
$$;

revoke all on function public.delete_business_staff_entry(uuid, uuid, text) from public;
grant execute on function public.delete_business_staff_entry(uuid, uuid, text) to authenticated;
-- <<< END FILE: 20260416_update_delete_business_staff_entry.sql <<<

-- ==========================================
-- >>> START FILE: 20260422172500_create_menu_categories_table.sql >>>
-- ==========================================
-- Create menu_categories table
CREATE TABLE IF NOT EXISTS menu_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    visual_index INT NOT NULL DEFAULT 0,
    is_visible_in_all_outlets BOOLEAN NOT NULL DEFAULT true,
    visible_outlet_ids UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add comment to the table
COMMENT ON TABLE menu_categories IS 'Table to store menu categories for the catalog management.';

-- Enable Row Level Security (optional, depends on project requirements)
-- ALTER TABLE menu_categories ENABLE ROW LEVEL SECURITY;

-- Create policy to allow all for now (development mode)
-- CREATE POLICY "Allow all for authenticated users" ON menu_categories
--     FOR ALL USING (auth.role() = 'authenticated');

-- Function to handle updated_at
CREATE OR REPLACE FUNCTION handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Trigger for updated_at
CREATE TRIGGER update_menu_categories_updated_at
    BEFORE UPDATE ON menu_categories
    FOR EACH ROW
    EXECUTE PROCEDURE handle_updated_at();
-- <<< END FILE: 20260422172500_create_menu_categories_table.sql <<<

-- ==========================================
-- >>> START FILE: 20260422172900_create_menu_items_table.sql >>>
-- ==========================================
-- Create menu_items table
CREATE TABLE IF NOT EXISTS menu_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    category TEXT NOT NULL, -- Corresponds to MenuCategory enum name
    price NUMERIC NOT NULL DEFAULT 0,
    description TEXT DEFAULT '',
    image_url TEXT,
    stock_available BOOLEAN NOT NULL DEFAULT true,
    ingredients TEXT[] DEFAULT '{}',
    recipe_cost NUMERIC DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add comment to the table
COMMENT ON TABLE menu_items IS 'Table to store menu items (products) for the catalog.';

-- Trigger for updated_at
CREATE TRIGGER update_menu_items_updated_at
    BEFORE UPDATE ON menu_items
    FOR EACH ROW
    EXECUTE PROCEDURE handle_updated_at();
-- <<< END FILE: 20260422172900_create_menu_items_table.sql <<<

-- ==========================================
-- >>> START FILE: 20260422173500_fix_rls_policies.sql >>>
-- ==========================================
-- Disable RLS for development to fix "violates row-level security policy" error
-- You can run this in Supabase SQL Editor
ALTER TABLE menu_categories DISABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items DISABLE ROW LEVEL SECURITY;

-- Alternatively, if you want to keep RLS enabled but allow access:
-- CREATE POLICY "Allow all access" ON menu_categories FOR ALL USING (true) WITH CHECK (true);
-- CREATE POLICY "Allow all access" ON menu_items FOR ALL USING (true) WITH CHECK (true);
-- <<< END FILE: 20260422173500_fix_rls_policies.sql <<<

-- ==========================================
-- >>> START FILE: 20260422174100_add_rbac_to_menu_management.sql >>>
-- ==========================================
-- Add business_id to menu management tables
ALTER TABLE menu_categories 
ADD COLUMN business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE menu_items 
ADD COLUMN business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS menu_categories_business_id_idx ON menu_categories(business_id);
CREATE INDEX IF NOT EXISTS menu_items_business_id_idx ON menu_items(business_id);

-- Enable RLS
ALTER TABLE menu_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE menu_items ENABLE ROW LEVEL SECURITY;

-- RBAC Policies for menu_categories
DROP POLICY IF EXISTS "menu_categories_select_policy" ON menu_categories;
CREATE POLICY "menu_categories_select_policy" ON menu_categories
FOR SELECT TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_categories.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
  ) OR
  EXISTS (
    SELECT 1 FROM public.outlet_members om
    JOIN public.outlets o ON o.id = om.outlet_id
    WHERE o.business_id = menu_categories.business_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
  )
);

DROP POLICY IF EXISTS "menu_categories_manage_policy" ON menu_categories;
CREATE POLICY "menu_categories_manage_policy" ON menu_categories
FOR ALL TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_categories.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
)
WITH CHECK (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_categories.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
);

-- RBAC Policies for menu_items
DROP POLICY IF EXISTS "menu_items_select_policy" ON menu_items;
CREATE POLICY "menu_items_select_policy" ON menu_items
FOR SELECT TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_items.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
  ) OR
  EXISTS (
    SELECT 1 FROM public.outlet_members om
    JOIN public.outlets o ON o.id = om.outlet_id
    WHERE o.business_id = menu_items.business_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
  )
);

DROP POLICY IF EXISTS "menu_items_manage_policy" ON menu_items;
CREATE POLICY "menu_items_manage_policy" ON menu_items
FOR ALL TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_items.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
)
WITH CHECK (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1 FROM public.business_members bm
    WHERE bm.business_id = menu_items.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
);
-- <<< END FILE: 20260422174100_add_rbac_to_menu_management.sql <<<

-- ==========================================
-- >>> START FILE: 20260422174800_add_item_variants_and_barcode.sql >>>
-- ==========================================
-- Migration to add variants and barcode support to menu items
-- 1. Add barcode/sku to menu_items (optional, for the item itself)
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS sku TEXT;
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS barcode TEXT;

-- 2. Create menu_item_variants table
CREATE TABLE IF NOT EXISTS menu_item_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    name TEXT NOT NULL, -- e.g., 'Small', 'Large', 'Pack of 10'
    price NUMERIC NOT NULL DEFAULT 0,
    sku TEXT,
    barcode TEXT,
    stock_available BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Add business_id to variants for RBAC if needed (though cascading from menu_items might be enough)
-- But for better RLS performance, adding business_id here is good practice.
ALTER TABLE menu_item_variants ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

-- Create indexes
CREATE INDEX IF NOT EXISTS menu_item_variants_menu_item_id_idx ON menu_item_variants(menu_item_id);
CREATE INDEX IF NOT EXISTS menu_item_variants_business_id_idx ON menu_item_variants(business_id);
CREATE INDEX IF NOT EXISTS menu_item_variants_barcode_idx ON menu_item_variants(barcode);

-- Add comment
COMMENT ON TABLE menu_item_variants IS 'Table to store product variants (sizes, versions) with distinct pricing and barcodes.';

-- Trigger for updated_at
CREATE TRIGGER update_menu_item_variants_updated_at
    BEFORE UPDATE ON menu_item_variants
    FOR EACH ROW
    EXECUTE PROCEDURE handle_updated_at();

-- RLS Policies
ALTER TABLE menu_item_variants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "menu_item_variants_manage_policy" ON menu_item_variants
    FOR ALL
    TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_variants.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
    )
    WITH CHECK (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_variants.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
    );

CREATE POLICY "menu_item_variants_select_policy" ON menu_item_variants
    FOR SELECT
    TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_variants.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
        ) OR
        EXISTS (
            SELECT 1 FROM public.outlet_members om
            JOIN public.outlets o ON o.id = om.outlet_id
            WHERE o.business_id = menu_item_variants.business_id
              AND om.user_id = auth.uid()
              AND om.status = 'active'
        )
    );
-- <<< END FILE: 20260422174800_add_item_variants_and_barcode.sql <<<

-- ==========================================
-- >>> START FILE: 20260422180000_create_master_catalog.sql >>>
-- ==========================================
-- Enable search extension if not exists
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Create a master catalog table for global product reference
CREATE TABLE IF NOT EXISTS public.master_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    barcode TEXT UNIQUE,
    name TEXT NOT NULL,
    category TEXT,
    brand TEXT,
    base_price NUMERIC DEFAULT 0, -- Modal / HPP reference
    selling_price NUMERIC DEFAULT 0, -- Harga jual reference
    unit TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- Index for fast barcode lookup
CREATE INDEX IF NOT EXISTS master_catalog_barcode_idx ON master_catalog(barcode);
CREATE INDEX IF NOT EXISTS master_catalog_name_idx ON master_catalog USING gin(name gin_trgm_ops); -- Requires pg_trgm extension

-- RLS: Read-only for all authenticated users
ALTER TABLE master_catalog ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow read access for all users" ON master_catalog
    FOR SELECT
    TO authenticated
    USING (true);
-- <<< END FILE: 20260422180000_create_master_catalog.sql <<<

-- ==========================================
-- >>> START FILE: 20260423090000_normalize_menu_item_category_relation.sql >>>
-- ==========================================
-- Normalize menu_items to reference menu_categories by id instead of storing
-- a mutable category name. This keeps renames safe and scopes data to a business.

ALTER TABLE public.menu_categories
ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE;

ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS category_id UUID;

WITH normalized_item_categories AS (
  SELECT DISTINCT
    mi.business_id,
    CASE lower(btrim(mi.category))
      WHEN 'food' THEN 'Makanan'
      WHEN 'drink' THEN 'Minuman'
      WHEN 'dessert' THEN 'Dessert'
      WHEN 'retail' THEN 'Retail/Toko'
      WHEN 'grocery' THEN 'Sembako'
      ELSE nullif(btrim(mi.category), '')
    END AS normalized_name
  FROM public.menu_items mi
  WHERE mi.business_id IS NOT NULL
    AND mi.category IS NOT NULL
),
missing_categories AS (
  SELECT
    nic.business_id,
    nic.normalized_name,
    row_number() OVER (
      PARTITION BY nic.business_id
      ORDER BY nic.normalized_name
    ) - 1 AS visual_offset
  FROM normalized_item_categories nic
  WHERE nic.normalized_name IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.menu_categories mc
      WHERE mc.business_id = nic.business_id
        AND lower(btrim(mc.name)) = lower(btrim(nic.normalized_name))
    )
),
current_visual_index AS (
  SELECT
    business_id,
    coalesce(max(visual_index), -1) AS max_visual_index
  FROM public.menu_categories
  WHERE business_id IS NOT NULL
  GROUP BY business_id
)
INSERT INTO public.menu_categories (
  id,
  name,
  visual_index,
  is_visible_in_all_outlets,
  visible_outlet_ids,
  created_at,
  updated_at,
  business_id
)
SELECT
  gen_random_uuid(),
  mc.normalized_name,
  coalesce(cvi.max_visual_index, -1) + mc.visual_offset + 1,
  true,
  '{}'::uuid[],
  now(),
  now(),
  mc.business_id
FROM missing_categories mc
LEFT JOIN current_visual_index cvi
  ON cvi.business_id = mc.business_id;

UPDATE public.menu_items mi
SET category_id = mc.id
FROM public.menu_categories mc
WHERE mi.category_id IS NULL
  AND mi.business_id = mc.business_id
  AND lower(btrim(mc.name)) = lower(
    btrim(
      CASE lower(btrim(mi.category))
        WHEN 'food' THEN 'Makanan'
        WHEN 'drink' THEN 'Minuman'
        WHEN 'dessert' THEN 'Dessert'
        WHEN 'retail' THEN 'Retail/Toko'
        WHEN 'grocery' THEN 'Sembako'
        ELSE coalesce(mi.category, '')
      END
    )
  );

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM public.menu_categories
    WHERE business_id IS NULL
  ) THEN
    RAISE EXCEPTION
      'menu_categories.business_id masih ada yang NULL. Backfill dulu sebelum enforce NOT NULL.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.menu_items
    WHERE business_id IS NULL
  ) THEN
    RAISE EXCEPTION
      'menu_items.business_id masih ada yang NULL. Backfill dulu sebelum enforce NOT NULL.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.menu_items
    WHERE category_id IS NULL
  ) THEN
    RAISE EXCEPTION
      'Masih ada menu_items yang belum berhasil di-map ke category_id. Periksa data kategori legacy sebelum lanjut.';
  END IF;
END $$;

ALTER TABLE public.menu_categories
ALTER COLUMN business_id SET NOT NULL;

ALTER TABLE public.menu_items
ALTER COLUMN business_id SET NOT NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'menu_items_category_id_fkey'
      AND conrelid = 'public.menu_items'::regclass
  ) THEN
    ALTER TABLE public.menu_items
    ADD CONSTRAINT menu_items_category_id_fkey
    FOREIGN KEY (category_id)
    REFERENCES public.menu_categories(id)
    ON DELETE RESTRICT;
  END IF;
END $$;

ALTER TABLE public.menu_items
ALTER COLUMN category_id SET NOT NULL;

CREATE INDEX IF NOT EXISTS menu_items_category_id_idx
ON public.menu_items(category_id);

ALTER TABLE public.menu_items
DROP COLUMN IF EXISTS category;
-- <<< END FILE: 20260423090000_normalize_menu_item_category_relation.sql <<<

-- ==========================================
-- >>> START FILE: 20260423100000_add_stock_quantity_tracking_to_menu_items.sql >>>
-- ==========================================
-- Separate manual sellability from optional quantity tracking.
-- stock_available stays as the manual "can sell" switch.
-- track_stock_quantity + stock_quantity add optional counted inventory.

ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS track_stock_quantity BOOLEAN NOT NULL DEFAULT false;

ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS stock_quantity INTEGER NOT NULL DEFAULT 0;

UPDATE public.menu_items
SET stock_quantity = 0
WHERE stock_quantity IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'menu_items_stock_quantity_nonnegative'
      AND conrelid = 'public.menu_items'::regclass
  ) THEN
    ALTER TABLE public.menu_items
    ADD CONSTRAINT menu_items_stock_quantity_nonnegative
    CHECK (stock_quantity >= 0);
  END IF;
END $$;

COMMENT ON COLUMN public.menu_items.stock_available IS
  'Manual sellability toggle. False means the item is hidden/unavailable for sale even if stock exists.';

COMMENT ON COLUMN public.menu_items.track_stock_quantity IS
  'When true, stock_quantity is enforced as the counted inventory for this item.';

COMMENT ON COLUMN public.menu_items.stock_quantity IS
  'Current counted stock for items that use quantity tracking.';
-- <<< END FILE: 20260423100000_add_stock_quantity_tracking_to_menu_items.sql <<<

-- ==========================================
-- >>> START FILE: 20260423103000_add_unit_to_menu_items.sql >>>
-- ==========================================
-- Add a flexible sales unit for menu items.
-- Keep this as free text so retail, cafe, and restaurant businesses can use
-- their own labels such as pcs, botol, cup, porsi, slice, bowl, or set.

ALTER TABLE public.menu_items
ADD COLUMN IF NOT EXISTS unit TEXT DEFAULT 'pcs';

UPDATE public.menu_items
SET unit = 'pcs'
WHERE unit IS NULL OR btrim(unit) = '';

COMMENT ON COLUMN public.menu_items.unit IS
  'Sales unit label for this item, e.g. pcs, cup, porsi, slice, bottle, or set.';
-- <<< END FILE: 20260423103000_add_unit_to_menu_items.sql <<<

-- ==========================================
-- >>> START FILE: 20260423113500_create_menu_item_images_storage.sql >>>
-- ==========================================
insert into storage.buckets (id, name, public)
values ('menu-item-images', 'menu-item-images', true)
on conflict (id) do nothing;

drop policy if exists "menu_item_images_public_read" on storage.objects;
create policy "menu_item_images_public_read"
on storage.objects
for select
to public
using (bucket_id = 'menu-item-images');

drop policy if exists "menu_item_images_authenticated_upload" on storage.objects;
create policy "menu_item_images_authenticated_upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'menu-item-images');

drop policy if exists "menu_item_images_authenticated_update" on storage.objects;
create policy "menu_item_images_authenticated_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'menu-item-images')
with check (bucket_id = 'menu-item-images');

drop policy if exists "menu_item_images_authenticated_delete" on storage.objects;
create policy "menu_item_images_authenticated_delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'menu-item-images');
-- <<< END FILE: 20260423113500_create_menu_item_images_storage.sql <<<

-- ==========================================
-- >>> START FILE: 20260423124500_create_discounts_table.sql >>>
-- ==========================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'discount_type'
  ) THEN
    CREATE TYPE public.discount_type AS ENUM ('percentage', 'fixed_amount');
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  code TEXT,
  description TEXT,
  type public.discount_type NOT NULL,
  percentage_value NUMERIC(5, 2),
  amount_value NUMERIC(14, 2),
  max_discount_amount NUMERIC(14, 2),
  is_active BOOLEAN NOT NULL DEFAULT true,
  starts_at TIMESTAMPTZ,
  ends_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT discounts_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT discounts_code_not_blank CHECK (
    code IS NULL OR btrim(code) <> ''
  ),
  CONSTRAINT discounts_value_check CHECK (
    (
      type = 'percentage' AND
      percentage_value IS NOT NULL AND
      percentage_value > 0 AND
      percentage_value <= 100 AND
      amount_value IS NULL AND
      (
        max_discount_amount IS NULL OR
        max_discount_amount >= 0
      )
    ) OR (
      type = 'fixed_amount' AND
      amount_value IS NOT NULL AND
      amount_value > 0 AND
      percentage_value IS NULL AND
      max_discount_amount IS NULL
    )
  ),
  CONSTRAINT discounts_period_check CHECK (
    starts_at IS NULL OR
    ends_at IS NULL OR
    starts_at <= ends_at
  )
);

COMMENT ON TABLE public.discounts IS
  'Master metadata diskon per bisnis untuk dipakai fleksibel di item, cart, atau transaksi.';

COMMENT ON COLUMN public.discounts.type IS
  'Jenis diskon: percentage untuk persen, fixed_amount untuk potongan rupiah langsung.';

COMMENT ON COLUMN public.discounts.max_discount_amount IS
  'Batas potongan maksimal dalam rupiah, hanya berlaku untuk discount percentage.';

CREATE INDEX IF NOT EXISTS discounts_business_id_idx
ON public.discounts (business_id);

CREATE INDEX IF NOT EXISTS discounts_business_active_idx
ON public.discounts (business_id, is_active);

CREATE INDEX IF NOT EXISTS discounts_business_type_idx
ON public.discounts (business_id, type);

CREATE UNIQUE INDEX IF NOT EXISTS discounts_business_code_unique_idx
ON public.discounts (business_id, lower(code))
WHERE code IS NOT NULL AND btrim(code) <> '';

DROP TRIGGER IF EXISTS update_discounts_updated_at ON public.discounts;
CREATE TRIGGER update_discounts_updated_at
  BEFORE UPDATE ON public.discounts
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_updated_at();

ALTER TABLE public.discounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "discounts_select_policy" ON public.discounts;
CREATE POLICY "discounts_select_policy" ON public.discounts
FOR SELECT TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1
    FROM public.business_members bm
    WHERE bm.business_id = discounts.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
  ) OR
  EXISTS (
    SELECT 1
    FROM public.outlet_members om
    JOIN public.outlets o ON o.id = om.outlet_id
    WHERE o.business_id = discounts.business_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
  )
);

DROP POLICY IF EXISTS "discounts_manage_policy" ON public.discounts;
CREATE POLICY "discounts_manage_policy" ON public.discounts
FOR ALL TO authenticated
USING (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1
    FROM public.business_members bm
    WHERE bm.business_id = discounts.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
)
WITH CHECK (
  public.is_business_owner(business_id) OR
  EXISTS (
    SELECT 1
    FROM public.business_members bm
    WHERE bm.business_id = discounts.business_id
      AND bm.user_id = auth.uid()
      AND bm.status = 'active'
      AND bm.role IN ('owner', 'admin')
  )
);
-- <<< END FILE: 20260423124500_create_discounts_table.sql <<<

-- ==========================================
-- >>> START FILE: 20260428100000_create_outlet_payment_methods.sql >>>
-- ==========================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'payment_method_type'
  ) THEN
    CREATE TYPE public.payment_method_type AS ENUM (
      'cash',
      'card',
      'qris',
      'bank_transfer',
      'e_wallet',
      'custom'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.outlet_payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  code TEXT NOT NULL,
  name TEXT NOT NULL,
  type public.payment_method_type NOT NULL DEFAULT 'custom',
  provider TEXT,
  account_label TEXT,
  account_number TEXT,
  instructions TEXT,
  is_active BOOLEAN NOT NULL DEFAULT true,
  sort_order INTEGER NOT NULL DEFAULT 0,
  requires_reference BOOLEAN NOT NULL DEFAULT false,
  allows_change BOOLEAN NOT NULL DEFAULT false,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT outlet_payment_methods_code_not_blank CHECK (btrim(code) <> ''),
  CONSTRAINT outlet_payment_methods_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT outlet_payment_methods_code_format CHECK (
    code = lower(code) AND
    code ~ '^[a-z0-9][a-z0-9_]{0,62}$'
  )
);

COMMENT ON TABLE public.outlet_payment_methods IS
  'Konfigurasi metode pembayaran per outlet supaya owner multi-outlet bisa mengatur kanal bayar berbeda per cabang.';

COMMENT ON COLUMN public.outlet_payment_methods.outlet_id IS
  'Scope konfigurasi pembayaran. Setiap outlet memiliki daftar metode sendiri.';

COMMENT ON COLUMN public.outlet_payment_methods.requires_reference IS
  'Jika true, kasir perlu mengisi nomor referensi/approval saat metode ini dipakai.';

COMMENT ON COLUMN public.outlet_payment_methods.allows_change IS
  'Jika true, metode dapat menghasilkan kembalian, umumnya hanya cash.';

CREATE INDEX IF NOT EXISTS outlet_payment_methods_outlet_id_idx
ON public.outlet_payment_methods (outlet_id);

CREATE INDEX IF NOT EXISTS outlet_payment_methods_active_idx
ON public.outlet_payment_methods (outlet_id, is_active, sort_order);

CREATE UNIQUE INDEX IF NOT EXISTS outlet_payment_methods_outlet_code_unique_idx
ON public.outlet_payment_methods (outlet_id, code);

DROP TRIGGER IF EXISTS set_outlet_payment_methods_updated_at
ON public.outlet_payment_methods;
CREATE TRIGGER set_outlet_payment_methods_updated_at
  BEFORE UPDATE ON public.outlet_payment_methods
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

CREATE OR REPLACE FUNCTION public.seed_default_outlet_payment_methods(
  target_outlet_id UUID
)
RETURNS VOID
LANGUAGE SQL
SECURITY DEFINER
SET search_path = public
AS $$
  INSERT INTO public.outlet_payment_methods (
    outlet_id,
    code,
    name,
    type,
    provider,
    is_active,
    sort_order,
    requires_reference,
    allows_change
  )
  VALUES
    (
      target_outlet_id,
      'cash',
      'Cash',
      'cash',
      NULL,
      true,
      0,
      false,
      true
    ),
    (
      target_outlet_id,
      'debit_credit',
      'Debit/Credit',
      'card',
      NULL,
      true,
      10,
      true,
      false
    ),
    (
      target_outlet_id,
      'qris',
      'QRIS',
      'qris',
      'QRIS',
      true,
      20,
      true,
      false
    )
  ON CONFLICT (outlet_id, code) DO NOTHING;
$$;

CREATE OR REPLACE FUNCTION public.handle_outlet_payment_methods_seed()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.seed_default_outlet_payment_methods(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS seed_outlet_payment_methods_after_insert
ON public.outlets;
CREATE TRIGGER seed_outlet_payment_methods_after_insert
  AFTER INSERT ON public.outlets
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_outlet_payment_methods_seed();

SELECT public.seed_default_outlet_payment_methods(id)
FROM public.outlets;

ALTER TABLE public.outlet_payment_methods ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "outlet_payment_methods_select_related"
ON public.outlet_payment_methods;
CREATE POLICY "outlet_payment_methods_select_related"
ON public.outlet_payment_methods
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = outlet_payment_methods.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR public.is_business_member(o.business_id, auth.uid())
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
        )
      )
  )
);

DROP POLICY IF EXISTS "outlet_payment_methods_manage_owner_admin"
ON public.outlet_payment_methods;
CREATE POLICY "outlet_payment_methods_manage_owner_admin"
ON public.outlet_payment_methods
FOR ALL
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = outlet_payment_methods.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin')
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = outlet_payment_methods.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin')
        )
      )
  )
);
-- <<< END FILE: 20260428100000_create_outlet_payment_methods.sql <<<

-- ==========================================
-- >>> START FILE: 20260428114000_allow_owner_reset_staff_password.sql >>>
-- ==========================================
create extension if not exists pgcrypto with schema extensions;

create or replace function public.update_business_staff_entry(
  target_business_id uuid,
  target_entry_id uuid,
  target_kind text,
  target_role public.app_role,
  target_status public.membership_status default 'active',
  target_full_name text default null,
  target_avatar_url text default null,
  target_staff_code text default null,
  target_initial_password text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_kind text;
  normalized_staff_code text;
  member_row public.business_members;
  invite_row public.staff_invitations;
  member_user_id uuid;
begin
  if not public.is_business_owner(target_business_id) then
    raise exception 'Hanya owner bisnis yang dapat mengubah user.';
  end if;

  normalized_kind := lower(trim(target_kind));
  normalized_staff_code := nullif(lower(trim(target_staff_code)), '');

  if normalized_kind = 'member' then
    select bm.user_id
    into member_user_id
    from public.business_members bm
    where bm.id = target_entry_id
      and bm.business_id = target_business_id;

    if member_user_id is null then
      raise exception 'Membership staff tidak ditemukan.';
    end if;

    if member_user_id = auth.uid() then
      raise exception 'Owner utama tidak bisa diubah dari halaman ini.';
    end if;

    update public.profiles
    set
      full_name = coalesce(nullif(trim(target_full_name), ''), full_name),
      avatar_url = coalesce(nullif(trim(target_avatar_url), ''), avatar_url),
      staff_code = coalesce(normalized_staff_code, staff_code),
      updated_at = timezone('utc', now())
    where id = member_user_id;

    update public.business_members
    set
      role = target_role,
      status = target_status,
      updated_at = timezone('utc', now())
    where id = target_entry_id
      and business_id = target_business_id
    returning *
    into member_row;

    -- Update the password in auth.users if provided
    if target_initial_password is not null and trim(target_initial_password) <> '' then
      update auth.users
      set encrypted_password = extensions.crypt(trim(target_initial_password), extensions.gen_salt('bf')),
          updated_at = timezone('utc', now())
      where id = member_user_id;
    end if;

    return jsonb_build_object(
      'kind', 'member',
      'business_member', to_jsonb(member_row)
    );
  elsif normalized_kind = 'invitation' then
    update public.staff_invitations
    set
      full_name = nullif(trim(target_full_name), ''),
      avatar_url = coalesce(nullif(trim(target_avatar_url), ''), avatar_url),
      staff_code = coalesce(normalized_staff_code, staff_code),
      role = target_role,
      status = target_status,
      initial_password_hash = coalesce(
        case
          when nullif(trim(target_initial_password), '') is null then null
          else extensions.crypt(
            trim(target_initial_password),
            extensions.gen_salt('bf')
          )
        end,
        initial_password_hash
      ),
      updated_at = timezone('utc', now())
    where id = target_entry_id
      and business_id = target_business_id
    returning *
    into invite_row;

    if invite_row.id is null then
      raise exception 'Invitation staff tidak ditemukan.';
    end if;

    return jsonb_build_object(
      'kind', 'invitation',
      'staff_invitation', to_jsonb(invite_row)
    );
  else
    raise exception 'Jenis staff entry tidak dikenali.';
  end if;
end;
$$;
-- <<< END FILE: 20260428114000_allow_owner_reset_staff_password.sql <<<

-- ==========================================
-- >>> START FILE: 20260428114500_delete_staff_auth_user.sql >>>
-- ==========================================
create extension if not exists pgcrypto with schema extensions;

create or replace function public.delete_business_staff_entry(
  target_business_id uuid,
  target_entry_id uuid,
  target_kind text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized_kind text;
  member_user_id uuid;
begin
  if not public.is_business_owner(target_business_id) then
    raise exception 'Hanya owner bisnis yang dapat menghapus user.';
  end if;

  normalized_kind := lower(trim(target_kind));

  if normalized_kind = 'member' then
    select bm.user_id
    into member_user_id
    from public.business_members bm
    where bm.id = target_entry_id
      and bm.business_id = target_business_id;

    if member_user_id is null then
      raise exception 'Membership staff tidak ditemukan.';
    end if;

    if member_user_id = auth.uid() then
      raise exception 'Owner utama tidak bisa dihapus.';
    end if;

    -- Delete from business_members
    delete from public.business_members
    where id = target_entry_id
      and business_id = target_business_id;

    -- Also delete the user from auth.users entirely
    -- This will cascade and delete their profile as well,
    -- preventing orphaned accounts and freeing up the staff ID/email.
    delete from auth.users where id = member_user_id;

  elsif normalized_kind = 'invitation' then
    delete from public.staff_invitations
    where id = target_entry_id
      and business_id = target_business_id;
  else
    raise exception 'Jenis staff entry tidak dikenali.';
  end if;
end;
$$;
-- <<< END FILE: 20260428114500_delete_staff_auth_user.sql <<<

-- ==========================================
-- >>> START FILE: 20260428130000_create_transactions_tables.sql >>>
-- ==========================================
-- =============================================================
-- TRANSACTION MODULE: orders, order_items, order_discounts, order_payments
-- =============================================================

-- ─── ENUM: order_status ──────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'order_status'
  ) THEN
    CREATE TYPE public.order_status AS ENUM (
      'draft',        -- Belum bayar, masih bisa edit
      'confirmed',    -- Sudah dikonfirmasi, menunggu bayar
      'paid',         -- Sudah lunas
      'partial_paid', -- Sebagian dibayar
      'void',         -- Dibatalkan
      'refunded'      -- Dikembalikan
    );
  END IF;
END $$;

-- ─── TABLE: orders ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  invoice_number TEXT NOT NULL,
  customer_name TEXT,
  customer_phone TEXT,
  customer_email TEXT,
  table_number INT,
  status public.order_status NOT NULL DEFAULT 'draft',
  notes TEXT,
  subtotal NUMERIC(14,2) NOT NULL DEFAULT 0,
  discount_total NUMERIC(14,2) NOT NULL DEFAULT 0,
  tax_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  grand_total NUMERIC(14,2) NOT NULL DEFAULT 0,
  paid_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  change_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  cashier_id UUID REFERENCES auth.users(id),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  paid_at TIMESTAMPTZ,
  CONSTRAINT orders_invoice_not_blank CHECK (btrim(invoice_number) <> ''),
  CONSTRAINT orders_subtotal_positive CHECK (subtotal >= 0),
  CONSTRAINT orders_grand_total_positive CHECK (grand_total >= 0)
);

COMMENT ON TABLE public.orders IS
  'Transaksi utama per outlet. Bisa draft (belum bayar) atau langsung paid.';

COMMENT ON COLUMN public.orders.status IS
  'Status order: draft=belum bayar, confirmed=tunggu bayar, paid=lunas, void=batal.';

CREATE INDEX IF NOT EXISTS orders_outlet_idx ON public.orders (outlet_id);
CREATE INDEX IF NOT EXISTS orders_business_idx ON public.orders (business_id);
CREATE INDEX IF NOT EXISTS orders_status_idx ON public.orders (outlet_id, status);
CREATE INDEX IF NOT EXISTS orders_created_idx ON public.orders (outlet_id, created_at DESC);
CREATE UNIQUE INDEX IF NOT EXISTS orders_invoice_unique_idx ON public.orders (outlet_id, invoice_number);

-- ─── TABLE: order_items ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  menu_item_id UUID REFERENCES public.menu_items(id) ON DELETE SET NULL,
  variant_id UUID REFERENCES public.menu_item_variants(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  variant_name TEXT,
  quantity INT NOT NULL DEFAULT 1,
  unit_price NUMERIC(14,2) NOT NULL DEFAULT 0,
  subtotal NUMERIC(14,2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT order_items_name_not_blank CHECK (btrim(name) <> ''),
  CONSTRAINT order_items_quantity_positive CHECK (quantity > 0),
  CONSTRAINT order_items_price_positive CHECK (unit_price >= 0)
);

CREATE INDEX IF NOT EXISTS order_items_order_idx ON public.order_items (order_id);

-- ─── TABLE: order_discounts ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.order_discounts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  discount_id UUID REFERENCES public.discounts(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  type public.discount_type NOT NULL,
  percentage_value NUMERIC(5,2),
  amount_value NUMERIC(14,2),
  max_discount_amount NUMERIC(14,2),
  applied_amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT order_discounts_name_not_blank CHECK (btrim(name) <> '')
);

CREATE INDEX IF NOT EXISTS order_discounts_order_idx ON public.order_discounts (order_id);

-- ─── TABLE: order_payments ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.order_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  payment_method_id UUID REFERENCES public.outlet_payment_methods(id) ON DELETE SET NULL,
  method_name TEXT NOT NULL,
  method_type public.payment_method_type NOT NULL DEFAULT 'cash',
  amount NUMERIC(14,2) NOT NULL DEFAULT 0,
  reference_number TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT order_payments_amount_positive CHECK (amount > 0)
);

CREATE INDEX IF NOT EXISTS order_payments_order_idx ON public.order_payments (order_id);

-- ─── TRIGGERS: updated_at ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS set_orders_updated_at ON public.orders;
CREATE TRIGGER set_orders_updated_at
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.set_updated_at();

-- ─── FUNCTION: generate invoice number ───────────────────────
CREATE OR REPLACE FUNCTION public.generate_invoice_number(
  target_outlet_id UUID
)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  today_date TEXT;
  seq INT;
  result TEXT;
BEGIN
  today_date := to_char(timezone('Asia/Jakarta', now()), 'YYYYMMDD');

  SELECT COUNT(*) + 1
  INTO seq
  FROM public.orders
  WHERE outlet_id = target_outlet_id
    AND created_at >= (date_trunc('day', timezone('Asia/Jakarta', now())) AT TIME ZONE 'Asia/Jakarta')
    AND created_at < ((date_trunc('day', timezone('Asia/Jakarta', now())) + interval '1 day') AT TIME ZONE 'Asia/Jakarta');

  result := 'INV-' || today_date || '-' || lpad(seq::text, 4, '0');
  RETURN result;
END;
$$;

-- ─── RLS: orders ─────────────────────────────────────────────
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "orders_select_related" ON public.orders;
CREATE POLICY "orders_select_related" ON public.orders
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR public.is_business_member(o.business_id, auth.uid())
        OR EXISTS (
          SELECT 1 FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
        )
      )
  )
);

DROP POLICY IF EXISTS "orders_manage_related" ON public.orders;
CREATE POLICY "orders_manage_related" ON public.orders
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin', 'cashier')
        )
        OR EXISTS (
          SELECT 1 FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin', 'cashier')
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        public.is_business_owner(o.business_id)
        OR EXISTS (
          SELECT 1 FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin', 'cashier')
        )
        OR EXISTS (
          SELECT 1 FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role IN ('owner', 'admin', 'cashier')
        )
      )
  )
);

-- ─── RLS: order_items ────────────────────────────────────────
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "order_items_select" ON public.order_items;
CREATE POLICY "order_items_select" ON public.order_items
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_items.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol
        WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR public.is_business_member(ol.business_id, auth.uid())
            OR EXISTS (
              SELECT 1 FROM public.outlet_members om
              WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active'
            )
          )
      )
  )
);

DROP POLICY IF EXISTS "order_items_manage" ON public.order_items;
CREATE POLICY "order_items_manage" ON public.order_items
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_items.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol
        WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (
              SELECT 1 FROM public.business_members bm
              WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid()
                AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier')
            )
            OR EXISTS (
              SELECT 1 FROM public.outlet_members om
              WHERE om.outlet_id = ol.id AND om.user_id = auth.uid()
                AND om.status = 'active' AND om.role IN ('owner','admin','cashier')
            )
          )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_items.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol
        WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (
              SELECT 1 FROM public.business_members bm
              WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid()
                AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier')
            )
            OR EXISTS (
              SELECT 1 FROM public.outlet_members om
              WHERE om.outlet_id = ol.id AND om.user_id = auth.uid()
                AND om.status = 'active' AND om.role IN ('owner','admin','cashier')
            )
          )
      )
  )
);

-- ─── RLS: order_discounts ────────────────────────────────────
ALTER TABLE public.order_discounts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "order_discounts_select" ON public.order_discounts;
CREATE POLICY "order_discounts_select" ON public.order_discounts
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_discounts.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol
        WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR public.is_business_member(ol.business_id, auth.uid())
            OR EXISTS (
              SELECT 1 FROM public.outlet_members om
              WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active'
            )
          )
      )
  )
);

DROP POLICY IF EXISTS "order_discounts_manage" ON public.order_discounts;
CREATE POLICY "order_discounts_manage" ON public.order_discounts
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_discounts.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (SELECT 1 FROM public.business_members bm WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid() AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier'))
            OR EXISTS (SELECT 1 FROM public.outlet_members om WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active' AND om.role IN ('owner','admin','cashier'))
          )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_discounts.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (SELECT 1 FROM public.business_members bm WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid() AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier'))
            OR EXISTS (SELECT 1 FROM public.outlet_members om WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active' AND om.role IN ('owner','admin','cashier'))
          )
      )
  )
);

-- ─── RLS: order_payments ─────────────────────────────────────
ALTER TABLE public.order_payments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "order_payments_select" ON public.order_payments;
CREATE POLICY "order_payments_select" ON public.order_payments
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_payments.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR public.is_business_member(ol.business_id, auth.uid())
            OR EXISTS (SELECT 1 FROM public.outlet_members om WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active')
          )
      )
  )
);

DROP POLICY IF EXISTS "order_payments_manage" ON public.order_payments;
CREATE POLICY "order_payments_manage" ON public.order_payments
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_payments.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (SELECT 1 FROM public.business_members bm WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid() AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier'))
            OR EXISTS (SELECT 1 FROM public.outlet_members om WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active' AND om.role IN ('owner','admin','cashier'))
          )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o WHERE o.id = order_payments.order_id
      AND EXISTS (
        SELECT 1 FROM public.outlets ol WHERE ol.id = o.outlet_id
          AND (
            public.is_business_owner(ol.business_id)
            OR EXISTS (SELECT 1 FROM public.business_members bm WHERE bm.business_id = ol.business_id AND bm.user_id = auth.uid() AND bm.status = 'active' AND bm.role IN ('owner','admin','cashier'))
            OR EXISTS (SELECT 1 FROM public.outlet_members om WHERE om.outlet_id = ol.id AND om.user_id = auth.uid() AND om.status = 'active' AND om.role IN ('owner','admin','cashier'))
          )
      )
  )
);
-- <<< END FILE: 20260428130000_create_transactions_tables.sql <<<

-- ==========================================
-- >>> START FILE: 20260428130500_add_item_discount_columns.sql >>>
-- ==========================================
-- =============================================================
-- Tambah kolom diskon per item pada order_items
-- =============================================================

ALTER TABLE public.order_items
  ADD COLUMN IF NOT EXISTS discount_id UUID REFERENCES public.discounts(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS discount_name TEXT,
  ADD COLUMN IF NOT EXISTS discount_type public.discount_type,
  ADD COLUMN IF NOT EXISTS discount_percentage NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS discount_amount NUMERIC(14,2) DEFAULT 0,
  ADD COLUMN IF NOT EXISTS discount_applied NUMERIC(14,2) NOT NULL DEFAULT 0;

COMMENT ON COLUMN public.order_items.discount_applied IS
  'Jumlah diskon yang di-apply pada item ini (sudah dikalkulasi).';

-- Ubah constraint amount pada order_payments agar >= 0
-- (untuk menangani kasus grand_total = 0 karena full discount)
ALTER TABLE public.order_payments DROP CONSTRAINT IF EXISTS order_payments_amount_positive;
ALTER TABLE public.order_payments ADD CONSTRAINT order_payments_amount_nonnegative CHECK (amount >= 0);
-- <<< END FILE: 20260428130500_add_item_discount_columns.sql <<<

-- ==========================================
-- >>> START FILE: 20260428133700_add_order_source_column.sql >>>
-- ==========================================
-- =============================================================
-- Tambah kolom order_source pada orders untuk track asal order
-- =============================================================

-- Buat enum type untuk order source
DO $$ BEGIN
  CREATE TYPE public.order_source AS ENUM ('pos', 'qr_self_order', 'waiter', 'online');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS order_source public.order_source NOT NULL DEFAULT 'pos';

COMMENT ON COLUMN public.orders.order_source IS
  'Asal pesanan: pos (kasir), qr_self_order (QR mandiri), waiter (pelayan), online (online order).';
-- <<< END FILE: 20260428133700_add_order_source_column.sql <<<

-- ==========================================
-- >>> START FILE: 20260428140500_add_cashier_name.sql >>>
-- ==========================================
-- =============================================================
-- Tambah kolom cashier_name pada orders
-- =============================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS cashier_name text;

COMMENT ON COLUMN public.orders.cashier_name IS
  'Nama kasir yang memproses transaksi.';
-- <<< END FILE: 20260428140500_add_cashier_name.sql <<<

-- ==========================================
-- >>> START FILE: 20260429112000_add_waiter_assignment_to_orders.sql >>>
-- ==========================================
-- =============================================================
-- Keep waiter ownership separate from cashier settlement
-- =============================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS waiter_id UUID REFERENCES auth.users(id);

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS waiter_name text;

COMMENT ON COLUMN public.orders.waiter_id IS
  'User waiter yang membuat / menangani order sebelum dibayar.';

COMMENT ON COLUMN public.orders.waiter_name IS
  'Nama waiter saat order dibuat, disimpan untuk histori.';

UPDATE public.orders
SET
  waiter_id = cashier_id,
  waiter_name = COALESCE(waiter_name, cashier_name)
WHERE order_source = 'waiter'
  AND waiter_id IS NULL
  AND cashier_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS orders_waiter_idx
  ON public.orders (outlet_id, waiter_id, created_at DESC);
-- <<< END FILE: 20260429112000_add_waiter_assignment_to_orders.sql <<<

-- ==========================================
-- >>> START FILE: 20260429113000_enable_waiter_order_management.sql >>>
-- ==========================================
-- =============================================================
-- Enable waiter to create and maintain their own unpaid orders
-- =============================================================

-- Ensure columns exist before creating policies
DO $$ 
BEGIN
  -- Add order_source if it doesn't exist (added in previous migration but just in case)
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'order_source' AND typnamespace = 'public'::regnamespace) THEN
    CREATE TYPE public.order_source AS ENUM ('pos', 'qr_self_order', 'waiter', 'online');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name='orders' AND column_name='order_source') THEN
    ALTER TABLE public.orders ADD COLUMN order_source public.order_source NOT NULL DEFAULT 'pos';
  END IF;

  -- Add waiter_id if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name='orders' AND column_name='waiter_id') THEN
    ALTER TABLE public.orders ADD COLUMN waiter_id UUID REFERENCES auth.users(id);
  END IF;

  -- Add waiter_name if it doesn't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name='orders' AND column_name='waiter_name') THEN
    ALTER TABLE public.orders ADD COLUMN waiter_name text;
  END IF;
END $$;


DROP POLICY IF EXISTS "orders_manage_waiter_own_unpaid" ON public.orders;
CREATE POLICY "orders_manage_waiter_own_unpaid" ON public.orders
FOR ALL TO authenticated
USING (
  orders.order_source = 'waiter'
  AND orders.status IN ('draft', 'confirmed')
  AND orders.waiter_id = auth.uid()
  AND COALESCE(orders.paid_amount, 0) = 0
  AND COALESCE(orders.change_amount, 0) = 0
  AND orders.paid_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
)
WITH CHECK (
  orders.order_source = 'waiter'
  AND orders.status IN ('draft', 'confirmed')
  AND orders.waiter_id = auth.uid()
  AND COALESCE(orders.paid_amount, 0) = 0
  AND COALESCE(orders.change_amount, 0) = 0
  AND orders.paid_at IS NULL
  AND EXISTS (
    SELECT 1
    FROM public.outlets o
    WHERE o.id = orders.outlet_id
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = o.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = o.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
);

DROP POLICY IF EXISTS "order_items_manage_waiter_own_unpaid" ON public.order_items;
CREATE POLICY "order_items_manage_waiter_own_unpaid" ON public.order_items
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.outlets ol ON ol.id = o.outlet_id
    WHERE o.id = order_items.order_id
      AND o.order_source = 'waiter'
      AND o.status IN ('draft', 'confirmed')
      AND o.waiter_id = auth.uid()
      AND COALESCE(o.paid_amount, 0) = 0
      AND COALESCE(o.change_amount, 0) = 0
      AND o.paid_at IS NULL
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = ol.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = ol.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.outlets ol ON ol.id = o.outlet_id
    WHERE o.id = order_items.order_id
      AND o.order_source = 'waiter'
      AND o.status IN ('draft', 'confirmed')
      AND o.waiter_id = auth.uid()
      AND COALESCE(o.paid_amount, 0) = 0
      AND COALESCE(o.change_amount, 0) = 0
      AND o.paid_at IS NULL
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = ol.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = ol.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
);

DROP POLICY IF EXISTS "order_discounts_manage_waiter_own_unpaid" ON public.order_discounts;
CREATE POLICY "order_discounts_manage_waiter_own_unpaid" ON public.order_discounts
FOR ALL TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.outlets ol ON ol.id = o.outlet_id
    WHERE o.id = order_discounts.order_id
      AND o.order_source = 'waiter'
      AND o.status IN ('draft', 'confirmed')
      AND o.waiter_id = auth.uid()
      AND COALESCE(o.paid_amount, 0) = 0
      AND COALESCE(o.change_amount, 0) = 0
      AND o.paid_at IS NULL
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = ol.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = ol.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.orders o
    JOIN public.outlets ol ON ol.id = o.outlet_id
    WHERE o.id = order_discounts.order_id
      AND o.order_source = 'waiter'
      AND o.status IN ('draft', 'confirmed')
      AND o.waiter_id = auth.uid()
      AND COALESCE(o.paid_amount, 0) = 0
      AND COALESCE(o.change_amount, 0) = 0
      AND o.paid_at IS NULL
      AND (
        EXISTS (
          SELECT 1
          FROM public.business_members bm
          WHERE bm.business_id = ol.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role = 'waiter'
        )
        OR EXISTS (
          SELECT 1
          FROM public.outlet_members om
          WHERE om.outlet_id = ol.id
            AND om.user_id = auth.uid()
            AND om.status = 'active'
            AND om.role = 'waiter'
        )
      )
  )
);
-- <<< END FILE: 20260429113000_enable_waiter_order_management.sql <<<

-- ==========================================
-- >>> START FILE: 20260429154500_enable_anonymous_self_ordering.sql >>>
-- ==========================================
-- =============================================================
-- Enable customers to create self-orders via QR Code (Anonymous)
-- =============================================================

-- 1. Allow anyone (including anon) to read menu items and outlets (needed for the web menu)
DROP POLICY IF EXISTS "allow_anon_read_outlets" ON public.outlets;
CREATE POLICY "allow_anon_read_outlets" ON public.outlets
FOR SELECT TO anon, authenticated
USING (is_active = true);

DROP POLICY IF EXISTS "allow_anon_read_menu_items" ON public.menu_items;
CREATE POLICY "allow_anon_read_menu_items" ON public.menu_items
FOR SELECT TO anon, authenticated
USING (stock_available = true);

DROP POLICY IF EXISTS "allow_anon_read_menu_categories" ON public.menu_categories;
CREATE POLICY "allow_anon_read_menu_categories" ON public.menu_categories
FOR SELECT TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "allow_anon_read_menu_variants" ON public.menu_item_variants;
CREATE POLICY "allow_anon_read_menu_variants" ON public.menu_item_variants
FOR SELECT TO anon, authenticated
USING (stock_available = true);

-- 2. Allow anon to INSERT into orders if order_source is qr_self_order
DROP POLICY IF EXISTS "orders_insert_self_service" ON public.orders;
CREATE POLICY "orders_insert_self_service" ON public.orders
FOR INSERT TO anon, authenticated
WITH CHECK (
  order_source = 'qr_self_order'
  AND status = 'confirmed'
  AND cashier_id IS NULL
  AND waiter_id IS NULL
  AND paid_at IS NULL
);

-- 3. Allow anon to INSERT into order_items for their own self-orders
-- Note: Simplified check to allow insert if the order is a qr_self_order
DROP POLICY IF EXISTS "order_items_insert_self_service" ON public.order_items;
CREATE POLICY "order_items_insert_self_service" ON public.order_items
FOR INSERT TO anon, authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_id
      AND o.order_source = 'qr_self_order'
  )
);
-- <<< END FILE: 20260429154500_enable_anonymous_self_ordering.sql <<<

-- ==========================================
-- >>> START FILE: 20260429183000_create_self_order_rpc.sql >>>
-- ==========================================
-- =============================================================
-- Self-order RPC for anonymous / web customer checkout
-- =============================================================

CREATE OR REPLACE FUNCTION public.create_self_order(
  target_outlet_id UUID,
  target_table_number INTEGER,
  target_customer_name TEXT DEFAULT NULL,
  target_customer_phone TEXT DEFAULT NULL,
  target_customer_email TEXT DEFAULT NULL,
  items_payload JSONB DEFAULT '[]'::jsonb
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_business_id UUID;
  requested_count INTEGER;
  calculated_subtotal NUMERIC(14,2);
  new_order_id UUID := gen_random_uuid();
  new_invoice_number TEXT;
  attempt_count INTEGER := 0;
BEGIN
  IF items_payload IS NULL
     OR jsonb_typeof(items_payload) <> 'array'
     OR jsonb_array_length(items_payload) = 0 THEN
    RAISE EXCEPTION 'Keranjang pesanan kosong.';
  END IF;

  SELECT business_id
  INTO resolved_business_id
  FROM public.outlets
  WHERE id = target_outlet_id
    AND is_active = true;

  IF resolved_business_id IS NULL THEN
    RAISE EXCEPTION 'Outlet tidak ditemukan atau sedang nonaktif.';
  END IF;

  SELECT COUNT(*)
  INTO requested_count
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID,
    variant_id UUID,
    quantity INTEGER,
    notes TEXT
  );

  IF requested_count = 0 THEN
    RAISE EXCEPTION 'Keranjang pesanan kosong.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(items_payload) AS requested(
      menu_item_id UUID,
      variant_id UUID,
      quantity INTEGER,
      notes TEXT
    )
    WHERE requested.menu_item_id IS NULL
      OR COALESCE(requested.quantity, 0) <= 0
  ) THEN
    RAISE EXCEPTION 'Data item pesanan tidak valid.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(items_payload) AS requested(
      menu_item_id UUID,
      variant_id UUID,
      quantity INTEGER,
      notes TEXT
    )
    LEFT JOIN public.menu_items mi
      ON mi.id = requested.menu_item_id
     AND mi.business_id = resolved_business_id
     AND mi.stock_available = true
    LEFT JOIN public.menu_item_variants mv
      ON requested.variant_id IS NOT NULL
     AND mv.id = requested.variant_id
     AND mv.menu_item_id = mi.id
     AND mv.stock_available = true
    WHERE mi.id IS NULL
       OR (requested.variant_id IS NOT NULL AND mv.id IS NULL)
  ) THEN
    RAISE EXCEPTION
      'Ada item atau varian yang sudah tidak tersedia. Silakan refresh menu lalu coba lagi.';
  END IF;

  SELECT COALESCE(SUM(COALESCE(mv.price, mi.price) * requested.quantity), 0)
  INTO calculated_subtotal
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID,
    variant_id UUID,
    quantity INTEGER,
    notes TEXT
  )
  JOIN public.menu_items mi
    ON mi.id = requested.menu_item_id
   AND mi.business_id = resolved_business_id
   AND mi.stock_available = true
  LEFT JOIN public.menu_item_variants mv
    ON requested.variant_id IS NOT NULL
   AND mv.id = requested.variant_id
   AND mv.menu_item_id = mi.id
   AND mv.stock_available = true;

  LOOP
    attempt_count := attempt_count + 1;
    new_invoice_number := public.generate_invoice_number(target_outlet_id);

    BEGIN
      INSERT INTO public.orders (
        id,
        outlet_id,
        business_id,
        invoice_number,
        customer_name,
        customer_phone,
        customer_email,
        table_number,
        status,
        order_source,
        subtotal,
        discount_total,
        tax_amount,
        grand_total,
        paid_amount,
        change_amount,
        cashier_id,
        cashier_name,
        waiter_id,
        waiter_name,
        paid_at
      )
      VALUES (
        new_order_id,
        target_outlet_id,
        resolved_business_id,
        new_invoice_number,
        NULLIF(btrim(target_customer_name), ''),
        NULLIF(btrim(target_customer_phone), ''),
        NULLIF(lower(btrim(target_customer_email)), ''),
        target_table_number,
        'confirmed',
        'qr_self_order',
        calculated_subtotal,
        0,
        0,
        calculated_subtotal,
        0,
        0,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
      );
      EXIT;
    EXCEPTION
      WHEN unique_violation THEN
        IF attempt_count >= 5 THEN
          RAISE EXCEPTION
            'Gagal membuat nomor invoice unik untuk pesanan ini.';
        END IF;
    END;
  END LOOP;

  INSERT INTO public.order_items (
    id,
    order_id,
    menu_item_id,
    variant_id,
    name,
    variant_name,
    quantity,
    unit_price,
    subtotal,
    notes
  )
  SELECT
    gen_random_uuid(),
    new_order_id,
    requested.menu_item_id,
    requested.variant_id,
    mi.name,
    mv.name,
    requested.quantity,
    COALESCE(mv.price, mi.price),
    COALESCE(mv.price, mi.price) * requested.quantity,
    NULLIF(btrim(requested.notes), '')
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID,
    variant_id UUID,
    quantity INTEGER,
    notes TEXT
  )
  JOIN public.menu_items mi
    ON mi.id = requested.menu_item_id
   AND mi.business_id = resolved_business_id
   AND mi.stock_available = true
  LEFT JOIN public.menu_item_variants mv
    ON requested.variant_id IS NOT NULL
   AND mv.id = requested.variant_id
   AND mv.menu_item_id = mi.id
   AND mv.stock_available = true;

  RETURN new_order_id;
END;
$$;

GRANT EXECUTE
ON FUNCTION public.create_self_order(UUID, INTEGER, TEXT, TEXT, TEXT, JSONB)
TO anon, authenticated;
-- <<< END FILE: 20260429183000_create_self_order_rpc.sql <<<

-- ==========================================
-- >>> START FILE: 20260429191500_add_self_order_history_rpc.sql >>>
-- ==========================================
-- =============================================================
-- Public self-order history lookup for customer web
-- =============================================================

CREATE OR REPLACE FUNCTION public.get_self_order_history(
  target_outlet_id UUID,
  known_order_ids JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result JSONB;
BEGIN
  IF known_order_ids IS NULL
     OR jsonb_typeof(known_order_ids) <> 'array'
     OR jsonb_array_length(known_order_ids) = 0 THEN
    RETURN '[]'::jsonb;
  END IF;

  SELECT COALESCE(
    jsonb_agg(history_rows.order_payload ORDER BY history_rows.created_at DESC),
    '[]'::jsonb
  )
  INTO result
  FROM (
    SELECT
      o.created_at,
      jsonb_build_object(
        'id', o.id,
        'outlet_id', o.outlet_id,
        'business_id', o.business_id,
        'invoice_number', o.invoice_number,
        'customer_name', o.customer_name,
        'customer_phone', o.customer_phone,
        'customer_email', o.customer_email,
        'table_number', o.table_number,
        'status', o.status,
        'order_source', o.order_source,
        'notes', o.notes,
        'subtotal', o.subtotal,
        'discount_total', o.discount_total,
        'tax_amount', o.tax_amount,
        'grand_total', o.grand_total,
        'paid_amount', o.paid_amount,
        'change_amount', o.change_amount,
        'cashier_id', o.cashier_id,
        'cashier_name', o.cashier_name,
        'waiter_id', o.waiter_id,
        'waiter_name', o.waiter_name,
        'created_at', o.created_at,
        'updated_at', o.updated_at,
        'paid_at', o.paid_at,
        'order_items', (
          SELECT COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'id', oi.id,
                'menu_item_id', oi.menu_item_id,
                'variant_id', oi.variant_id,
                'name', oi.name,
                'variant_name', oi.variant_name,
                'quantity', oi.quantity,
                'unit_price', oi.unit_price,
                'subtotal', oi.subtotal,
                'notes', oi.notes,
                'discount_id', oi.discount_id,
                'discount_name', oi.discount_name,
                'discount_type', oi.discount_type,
                'discount_percentage', oi.discount_percentage,
                'discount_amount', oi.discount_amount,
                'discount_applied', oi.discount_applied
              )
              ORDER BY oi.created_at ASC
            ),
            '[]'::jsonb
          )
          FROM public.order_items oi
          WHERE oi.order_id = o.id
        ),
        'order_discounts', '[]'::jsonb,
        'order_payments', '[]'::jsonb
      ) AS order_payload
    FROM public.orders o
    WHERE o.outlet_id = target_outlet_id
      AND o.order_source = 'qr_self_order'
      AND o.id IN (
        SELECT value::uuid
        FROM jsonb_array_elements_text(known_order_ids)
      )
  ) AS history_rows;

  RETURN result;
END;
$$;

GRANT EXECUTE
ON FUNCTION public.get_self_order_history(UUID, JSONB)
TO anon, authenticated;
-- <<< END FILE: 20260429191500_add_self_order_history_rpc.sql <<<

-- ==========================================
-- >>> START FILE: 20260429200000_create_inventory_movements_audit.sql >>>
-- ==========================================
-- =============================================================
-- INVENTORY AUDIT TRAIL
-- Records every tracked stock change with date/time and actor.
-- Current stock snapshot remains on public.menu_items.stock_quantity
-- so the existing app can adopt auditing without breaking queries.
-- =============================================================

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type
    WHERE typname = 'inventory_movement_type'
  ) THEN
    CREATE TYPE public.inventory_movement_type AS ENUM (
      'initial_stock',
      'manual_addition',
      'manual_reduction',
      'stock_opname',
      'sale',
      'void_restore',
      'refund'
    );
  END IF;
END $$;

CREATE TABLE IF NOT EXISTS public.inventory_movements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
  movement_type public.inventory_movement_type NOT NULL,
  quantity_before INTEGER NOT NULL,
  quantity_delta INTEGER NOT NULL,
  quantity_after INTEGER NOT NULL,
  note TEXT,
  reference_type TEXT,
  reference_id UUID,
  performed_by_user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  CONSTRAINT inventory_movements_quantity_before_nonnegative
    CHECK (quantity_before >= 0),
  CONSTRAINT inventory_movements_quantity_after_nonnegative
    CHECK (quantity_after >= 0),
  CONSTRAINT inventory_movements_quantity_delta_nonzero
    CHECK (quantity_delta <> 0),
  CONSTRAINT inventory_movements_quantity_consistent
    CHECK (quantity_after = quantity_before + quantity_delta)
);

COMMENT ON TABLE public.inventory_movements IS
  'Audit trail untuk setiap perubahan stok item menu, termasuk tanggal/jam, outlet, dan pelakunya.';

COMMENT ON COLUMN public.inventory_movements.created_at IS
  'Waktu perubahan stok tercatat dalam UTC. Gunakan konversi timezone di client bila perlu.';

COMMENT ON COLUMN public.inventory_movements.note IS
  'Catatan bebas, misalnya alasan restock atau koreksi stok.';

CREATE INDEX IF NOT EXISTS inventory_movements_menu_item_created_idx
  ON public.inventory_movements (menu_item_id, created_at DESC);

CREATE INDEX IF NOT EXISTS inventory_movements_outlet_created_idx
  ON public.inventory_movements (outlet_id, created_at DESC);

CREATE INDEX IF NOT EXISTS inventory_movements_business_created_idx
  ON public.inventory_movements (business_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.can_manage_inventory_for_outlet(
  target_outlet_id UUID
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_business_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN false;
  END IF;

  SELECT o.business_id
  INTO target_business_id
  FROM public.outlets o
  WHERE o.id = target_outlet_id;

  IF target_business_id IS NULL THEN
    RETURN false;
  END IF;

  RETURN
    public.is_business_owner(target_business_id)
    OR EXISTS (
      SELECT 1
      FROM public.business_members bm
      WHERE bm.business_id = target_business_id
        AND bm.user_id = auth.uid()
        AND bm.status = 'active'
        AND bm.role IN ('owner', 'admin')
    )
    OR EXISTS (
      SELECT 1
      FROM public.outlet_members om
      WHERE om.outlet_id = target_outlet_id
        AND om.user_id = auth.uid()
        AND om.status = 'active'
        AND om.role IN ('owner', 'admin')
    );
END;
$$;

REVOKE ALL ON FUNCTION public.can_manage_inventory_for_outlet(UUID) FROM public;
GRANT EXECUTE ON FUNCTION public.can_manage_inventory_for_outlet(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.adjust_menu_item_stock(
  target_menu_item_id UUID,
  target_outlet_id UUID,
  target_new_quantity INTEGER,
  target_note TEXT DEFAULT NULL,
  target_reference_type TEXT DEFAULT 'manual_adjustment'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  item_business_id UUID;
  current_quantity INTEGER;
  quantity_delta INTEGER;
  movement_kind public.inventory_movement_type;
  movement_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Anda harus login untuk mengubah stok.';
  END IF;

  IF target_menu_item_id IS NULL THEN
    RAISE EXCEPTION 'Produk tujuan wajib diisi.';
  END IF;

  IF target_outlet_id IS NULL THEN
    RAISE EXCEPTION 'Outlet tujuan wajib diisi.';
  END IF;

  IF target_new_quantity IS NULL OR target_new_quantity < 0 THEN
    RAISE EXCEPTION 'Stok baru tidak boleh negatif.';
  END IF;

  IF NOT public.can_manage_inventory_for_outlet(target_outlet_id) THEN
    RAISE EXCEPTION 'Anda tidak punya akses untuk mengubah stok outlet ini.';
  END IF;

  SELECT mi.business_id, COALESCE(mi.stock_quantity, 0)
  INTO item_business_id, current_quantity
  FROM public.menu_items mi
  JOIN public.outlets o
    ON o.id = target_outlet_id
   AND o.business_id = mi.business_id
  WHERE mi.id = target_menu_item_id
  FOR UPDATE;

  IF item_business_id IS NULL THEN
    RAISE EXCEPTION 'Produk tidak ditemukan pada outlet yang dipilih.';
  END IF;

  IF current_quantity = target_new_quantity THEN
    RETURN NULL;
  END IF;

  quantity_delta := target_new_quantity - current_quantity;

  IF current_quantity = 0
     AND target_new_quantity > 0
     AND NOT EXISTS (
       SELECT 1
       FROM public.inventory_movements im
       WHERE im.menu_item_id = target_menu_item_id
         AND im.outlet_id = target_outlet_id
     ) THEN
    movement_kind := 'initial_stock';
  ELSIF quantity_delta > 0 THEN
    movement_kind := 'manual_addition';
  ELSE
    movement_kind := 'manual_reduction';
  END IF;

  UPDATE public.menu_items
  SET stock_quantity = target_new_quantity
  WHERE id = target_menu_item_id;

  INSERT INTO public.inventory_movements (
    business_id,
    outlet_id,
    menu_item_id,
    movement_type,
    quantity_before,
    quantity_delta,
    quantity_after,
    note,
    reference_type,
    performed_by_user_id
  )
  VALUES (
    item_business_id,
    target_outlet_id,
    target_menu_item_id,
    movement_kind,
    current_quantity,
    quantity_delta,
    target_new_quantity,
    NULLIF(btrim(target_note), ''),
    NULLIF(btrim(target_reference_type), ''),
    auth.uid()
  )
  RETURNING id INTO movement_id;

  RETURN movement_id;
END;
$$;

REVOKE ALL ON FUNCTION public.adjust_menu_item_stock(UUID, UUID, INTEGER, TEXT, TEXT) FROM public;
GRANT EXECUTE ON FUNCTION public.adjust_menu_item_stock(UUID, UUID, INTEGER, TEXT, TEXT) TO authenticated;

ALTER TABLE public.inventory_movements ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "inventory_movements_select_related" ON public.inventory_movements;
CREATE POLICY "inventory_movements_select_related" ON public.inventory_movements
FOR SELECT TO authenticated
USING (
  public.is_business_owner(business_id)
  OR public.is_business_member(business_id, auth.uid())
  OR EXISTS (
    SELECT 1
    FROM public.outlet_members om
    WHERE om.outlet_id = inventory_movements.outlet_id
      AND om.user_id = auth.uid()
      AND om.status = 'active'
  )
);
-- <<< END FILE: 20260429200000_create_inventory_movements_audit.sql <<<

-- ==========================================
-- >>> START FILE: 20260429210000_create_inventory_system.sql >>>
-- ==========================================
-- =============================================================
-- INVENTORY SYSTEM: SUPPLIERS & PURCHASE ORDERS
-- =============================================================

-- 1. Suppliers Table
CREATE TABLE IF NOT EXISTS public.suppliers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  contact_name TEXT,
  phone TEXT,
  email TEXT,
  address TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 2. PO Status Enum
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'purchase_order_status') THEN
    CREATE TYPE public.purchase_order_status AS ENUM (
      'draft',
      'pending',
      'received',
      'cancelled'
    );
  END IF;
END $$;

-- 3. Purchase Orders Table
CREATE TABLE IF NOT EXISTS public.purchase_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  outlet_id UUID NOT NULL REFERENCES public.outlets(id) ON DELETE CASCADE,
  supplier_id UUID REFERENCES public.suppliers(id) ON DELETE SET NULL,
  po_number TEXT NOT NULL,
  status public.purchase_order_status NOT NULL DEFAULT 'draft',
  total_amount NUMERIC(15,2) NOT NULL DEFAULT 0,
  notes TEXT,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now()),
  received_at TIMESTAMPTZ,
  
  -- Ensure PO number is unique within business
  CONSTRAINT purchase_orders_number_business_unique UNIQUE(business_id, po_number)
);

-- 4. Purchase Order Items Table
CREATE TABLE IF NOT EXISTS public.purchase_order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  po_id UUID NOT NULL REFERENCES public.purchase_orders(id) ON DELETE CASCADE,
  menu_item_id UUID NOT NULL REFERENCES public.menu_items(id) ON DELETE CASCADE,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  received_quantity INTEGER NOT NULL DEFAULT 0 CHECK (received_quantity >= 0),
  cost_price NUMERIC(15,2) NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

-- 5. Add 'purchase_order_receive' to inventory_movement_type if not exists
ALTER TYPE public.inventory_movement_type ADD VALUE IF NOT EXISTS 'purchase_order_receive';

-- 6. RPC Function to Receive PO
CREATE OR REPLACE FUNCTION public.receive_purchase_order(
  target_po_id UUID,
  received_items JSONB -- Array of {item_id, received_qty}
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  po_rec RECORD;
  item_rec RECORD;
  current_stock INTEGER;
  new_stock INTEGER;
BEGIN
  -- 1. Get PO details and lock for update
  SELECT * INTO po_rec 
  FROM public.purchase_orders 
  WHERE id = target_po_id 
  FOR UPDATE;

  IF po_rec IS NULL THEN
    RAISE EXCEPTION 'Purchase Order tidak ditemukan.';
  END IF;

  IF po_rec.status = 'received' THEN
    RAISE EXCEPTION 'Purchase Order sudah berstatus diterima.';
  END IF;

  IF po_rec.status = 'cancelled' THEN
    RAISE EXCEPTION 'Purchase Order sudah dibatalkan.';
  END IF;

  -- 2. Check permissions
  IF NOT public.can_manage_inventory_for_outlet(po_rec.outlet_id) THEN
    RAISE EXCEPTION 'Anda tidak punya akses untuk memproses PO ini.';
  END IF;

  -- 3. Process each item in the received_items JSON
  FOR item_rec IN SELECT * FROM jsonb_to_recordset(received_items) AS x(item_id UUID, received_qty INTEGER)
  LOOP
    -- Update received quantity in PO items
    UPDATE public.purchase_order_items
    SET received_quantity = received_quantity + item_rec.received_qty
    WHERE po_id = target_po_id AND menu_item_id = item_rec.item_id;

    -- Update stock in menu_items
    SELECT stock_quantity INTO current_stock
    FROM public.menu_items
    WHERE id = item_rec.item_id
    FOR UPDATE;

    new_stock := COALESCE(current_stock, 0) + item_rec.received_qty;

    UPDATE public.menu_items
    SET stock_quantity = new_stock
    WHERE id = item_rec.item_id;

    -- Record inventory movement
    INSERT INTO public.inventory_movements (
      business_id,
      outlet_id,
      menu_item_id,
      movement_type,
      quantity_before,
      quantity_delta,
      quantity_after,
      note,
      reference_type,
      reference_id,
      performed_by_user_id
    )
    VALUES (
      po_rec.business_id,
      po_rec.outlet_id,
      item_rec.item_id,
      'purchase_order_receive',
      COALESCE(current_stock, 0),
      item_rec.received_qty,
      new_stock,
      'Received from PO: ' || po_rec.po_number,
      'purchase_order',
      target_po_id,
      auth.uid()
    );
  END LOOP;

  -- 4. Update PO status
  UPDATE public.purchase_orders
  SET 
    status = 'received',
    received_at = timezone('utc', now())
  WHERE id = target_po_id;

END;
$$;

-- 7. RLS Policies
ALTER TABLE public.suppliers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_order_items ENABLE ROW LEVEL SECURITY;

-- Suppliers Policies
DROP POLICY IF EXISTS "suppliers_select_policy" ON public.suppliers;
CREATE POLICY "suppliers_select_policy" ON public.suppliers
FOR SELECT TO authenticated
USING (public.is_business_owner(business_id) OR public.is_business_member(business_id, auth.uid()));

DROP POLICY IF EXISTS "suppliers_insert_policy" ON public.suppliers;
CREATE POLICY "suppliers_insert_policy" ON public.suppliers
FOR INSERT TO authenticated
WITH CHECK (public.is_business_owner(business_id) OR public.is_business_member(business_id, auth.uid()));

DROP POLICY IF EXISTS "suppliers_update_policy" ON public.suppliers;
CREATE POLICY "suppliers_update_policy" ON public.suppliers
FOR UPDATE TO authenticated
USING (public.is_business_owner(business_id) OR public.is_business_member(business_id, auth.uid()));

DROP POLICY IF EXISTS "suppliers_delete_policy" ON public.suppliers;
CREATE POLICY "suppliers_delete_policy" ON public.suppliers
FOR DELETE TO authenticated
USING (public.is_business_owner(business_id));

-- PO Policies
DROP POLICY IF EXISTS "po_select_policy" ON public.purchase_orders;
CREATE POLICY "po_select_policy" ON public.purchase_orders
FOR SELECT TO authenticated
USING (
  public.is_business_owner(business_id) 
  OR public.is_business_member(business_id, auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.outlet_members om 
    WHERE om.outlet_id = purchase_orders.outlet_id AND om.user_id = auth.uid()
  )
);

DROP POLICY IF EXISTS "po_insert_policy" ON public.purchase_orders;
CREATE POLICY "po_insert_policy" ON public.purchase_orders
FOR INSERT TO authenticated
WITH CHECK (
  public.is_business_owner(business_id) 
  OR public.is_business_member(business_id, auth.uid())
);

DROP POLICY IF EXISTS "po_update_policy" ON public.purchase_orders;
CREATE POLICY "po_update_policy" ON public.purchase_orders
FOR UPDATE TO authenticated
USING (
  public.is_business_owner(business_id) 
  OR public.is_business_member(business_id, auth.uid())
);

-- PO Items Policies
DROP POLICY IF EXISTS "po_items_select_policy" ON public.purchase_order_items;
CREATE POLICY "po_items_select_policy" ON public.purchase_order_items
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.purchase_orders po 
    WHERE po.id = purchase_order_items.po_id
    AND (
      public.is_business_owner(po.business_id) 
      OR public.is_business_member(po.business_id, auth.uid())
      OR EXISTS (
        SELECT 1 FROM public.outlet_members om 
        WHERE om.outlet_id = po.outlet_id AND om.user_id = auth.uid()
      )
    )
  )
);

DROP POLICY IF EXISTS "po_items_insert_policy" ON public.purchase_order_items;
CREATE POLICY "po_items_insert_policy" ON public.purchase_order_items
FOR INSERT TO authenticated
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.purchase_orders po 
    WHERE po.id = purchase_order_items.po_id
    AND (
      public.is_business_owner(po.business_id) 
      OR public.is_business_member(po.business_id, auth.uid())
    )
  )
);

DROP POLICY IF EXISTS "po_items_update_policy" ON public.purchase_order_items;
CREATE POLICY "po_items_update_policy" ON public.purchase_order_items
FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.purchase_orders po 
    WHERE po.id = purchase_order_items.po_id
    AND (
      public.is_business_owner(po.business_id) 
      OR public.is_business_member(po.business_id, auth.uid())
    )
  )
);

GRANT ALL ON public.suppliers TO authenticated;
GRANT ALL ON public.purchase_orders TO authenticated;
GRANT ALL ON public.purchase_order_items TO authenticated;
GRANT EXECUTE ON FUNCTION public.receive_purchase_order(UUID, JSONB) TO authenticated;
-- <<< END FILE: 20260429210000_create_inventory_system.sql <<<

-- ==========================================
-- >>> START FILE: 20260430103000_merge_qr_self_orders_by_table.sql >>>
-- ==========================================
-- =============================================================
-- Merge QR self-orders by outlet + QR table key into one invoice
-- =============================================================

ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS self_order_table_key TEXT;

COMMENT ON COLUMN public.orders.self_order_table_key IS
  'Stable QR/self-order table key. Allows non-numeric QR labels and shared cart lookup.';

UPDATE public.orders
SET self_order_table_key = table_number::text
WHERE order_source = 'qr_self_order'
  AND self_order_table_key IS NULL
  AND table_number IS NOT NULL;

CREATE INDEX IF NOT EXISTS orders_active_qr_self_order_table_idx
ON public.orders (outlet_id, self_order_table_key, updated_at DESC)
WHERE order_source = 'qr_self_order'
  AND status = 'confirmed'
  AND paid_at IS NULL
  AND self_order_table_key IS NOT NULL;

DROP FUNCTION IF EXISTS public.create_self_order(
  UUID,
  INTEGER,
  TEXT,
  TEXT,
  TEXT,
  JSONB
);

CREATE OR REPLACE FUNCTION public.create_self_order(
  target_outlet_id UUID,
  target_table_number INTEGER,
  target_customer_name TEXT DEFAULT NULL,
  target_customer_phone TEXT DEFAULT NULL,
  target_customer_email TEXT DEFAULT NULL,
  items_payload JSONB DEFAULT '[]'::jsonb,
  target_table_key TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_business_id UUID;
  resolved_table_key TEXT;
  requested_count INTEGER;
  calculated_subtotal NUMERIC(14,2);
  target_order_id UUID;
  new_invoice_number TEXT;
  attempt_count INTEGER := 0;
BEGIN
  IF items_payload IS NULL
     OR jsonb_typeof(items_payload) <> 'array'
     OR jsonb_array_length(items_payload) = 0 THEN
    RAISE EXCEPTION 'Keranjang pesanan kosong.';
  END IF;

  SELECT business_id
  INTO resolved_business_id
  FROM public.outlets
  WHERE id = target_outlet_id
    AND is_active = true;

  IF resolved_business_id IS NULL THEN
    RAISE EXCEPTION 'Outlet tidak ditemukan atau sedang nonaktif.';
  END IF;

  resolved_table_key := NULLIF(
    btrim(COALESCE(target_table_key, target_table_number::text, '')),
    ''
  );

  IF resolved_table_key IS NULL THEN
    RAISE EXCEPTION 'Nomor meja QR tidak valid.';
  END IF;

  SELECT COUNT(*)
  INTO requested_count
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID,
    variant_id UUID,
    quantity INTEGER,
    notes TEXT
  );

  IF requested_count = 0 THEN
    RAISE EXCEPTION 'Keranjang pesanan kosong.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(items_payload) AS requested(
      menu_item_id UUID,
      variant_id UUID,
      quantity INTEGER,
      notes TEXT
    )
    WHERE requested.menu_item_id IS NULL
      OR COALESCE(requested.quantity, 0) <= 0
  ) THEN
    RAISE EXCEPTION 'Data item pesanan tidak valid.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_to_recordset(items_payload) AS requested(
      menu_item_id UUID,
      variant_id UUID,
      quantity INTEGER,
      notes TEXT
    )
    LEFT JOIN public.menu_items mi
      ON mi.id = requested.menu_item_id
     AND mi.business_id = resolved_business_id
     AND mi.stock_available = true
    LEFT JOIN public.menu_item_variants mv
      ON requested.variant_id IS NOT NULL
     AND mv.id = requested.variant_id
     AND mv.menu_item_id = mi.id
     AND mv.stock_available = true
    WHERE mi.id IS NULL
       OR (requested.variant_id IS NOT NULL AND mv.id IS NULL)
  ) THEN
    RAISE EXCEPTION
      'Ada item atau varian yang sudah tidak tersedia. Silakan refresh menu lalu coba lagi.';
  END IF;

  SELECT COALESCE(SUM(COALESCE(mv.price, mi.price) * requested.quantity), 0)
  INTO calculated_subtotal
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID,
    variant_id UUID,
    quantity INTEGER,
    notes TEXT
  )
  JOIN public.menu_items mi
    ON mi.id = requested.menu_item_id
   AND mi.business_id = resolved_business_id
   AND mi.stock_available = true
  LEFT JOIN public.menu_item_variants mv
    ON requested.variant_id IS NOT NULL
   AND mv.id = requested.variant_id
   AND mv.menu_item_id = mi.id
   AND mv.stock_available = true;

  -- Keep parallel submissions from the same QR/table from creating
  -- duplicate active invoices.
  PERFORM pg_advisory_xact_lock(
    hashtext(target_outlet_id::text || ':' || resolved_table_key)
  );

  SELECT o.id
  INTO target_order_id
  FROM public.orders o
  WHERE o.outlet_id = target_outlet_id
    AND o.order_source = 'qr_self_order'
    AND o.status = 'confirmed'
    AND o.paid_at IS NULL
    AND (
      o.self_order_table_key = resolved_table_key
      OR (
        o.self_order_table_key IS NULL
        AND target_table_number IS NOT NULL
        AND o.table_number = target_table_number
      )
    )
  ORDER BY o.updated_at DESC, o.created_at DESC
  LIMIT 1
  FOR UPDATE;

  IF target_order_id IS NULL THEN
    target_order_id := gen_random_uuid();

    LOOP
      attempt_count := attempt_count + 1;
      new_invoice_number := public.generate_invoice_number(target_outlet_id);

      BEGIN
        INSERT INTO public.orders (
          id,
          outlet_id,
          business_id,
          invoice_number,
          customer_name,
          customer_phone,
          customer_email,
          table_number,
          self_order_table_key,
          status,
          order_source,
          subtotal,
          discount_total,
          tax_amount,
          grand_total,
          paid_amount,
          change_amount,
          cashier_id,
          cashier_name,
          waiter_id,
          waiter_name,
          paid_at
        )
        VALUES (
          target_order_id,
          target_outlet_id,
          resolved_business_id,
          new_invoice_number,
          NULLIF(btrim(target_customer_name), ''),
          NULLIF(btrim(target_customer_phone), ''),
          NULLIF(lower(btrim(target_customer_email)), ''),
          target_table_number,
          resolved_table_key,
          'confirmed',
          'qr_self_order',
          0,
          0,
          0,
          0,
          0,
          0,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL
        );
        EXIT;
      EXCEPTION
        WHEN unique_violation THEN
          IF attempt_count >= 5 THEN
            RAISE EXCEPTION
              'Gagal membuat nomor invoice unik untuk pesanan ini.';
          END IF;
      END;
    END LOOP;
  ELSE
    UPDATE public.orders
    SET
      customer_name = COALESCE(
        customer_name,
        NULLIF(btrim(target_customer_name), '')
      ),
      customer_phone = COALESCE(
        customer_phone,
        NULLIF(btrim(target_customer_phone), '')
      ),
      customer_email = COALESCE(
        customer_email,
        NULLIF(lower(btrim(target_customer_email)), '')
      ),
      self_order_table_key = resolved_table_key,
      updated_at = timezone('utc', now())
    WHERE id = target_order_id;
  END IF;

  INSERT INTO public.order_items (
    id,
    order_id,
    menu_item_id,
    variant_id,
    name,
    variant_name,
    quantity,
    unit_price,
    subtotal,
    notes
  )
  SELECT
    gen_random_uuid(),
    target_order_id,
    requested.menu_item_id,
    requested.variant_id,
    mi.name,
    mv.name,
    requested.quantity,
    COALESCE(mv.price, mi.price),
    COALESCE(mv.price, mi.price) * requested.quantity,
    NULLIF(btrim(requested.notes), '')
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID,
    variant_id UUID,
    quantity INTEGER,
    notes TEXT
  )
  JOIN public.menu_items mi
    ON mi.id = requested.menu_item_id
   AND mi.business_id = resolved_business_id
   AND mi.stock_available = true
  LEFT JOIN public.menu_item_variants mv
    ON requested.variant_id IS NOT NULL
   AND mv.id = requested.variant_id
   AND mv.menu_item_id = mi.id
   AND mv.stock_available = true;

  WITH item_totals AS (
    SELECT COALESCE(SUM(oi.subtotal), 0)::NUMERIC(14,2) AS subtotal
    FROM public.order_items oi
    WHERE oi.order_id = target_order_id
  )
  UPDATE public.orders o
  SET
    subtotal = item_totals.subtotal,
    grand_total = GREATEST(
      item_totals.subtotal - o.discount_total + o.tax_amount,
      0::NUMERIC
    ),
    updated_at = timezone('utc', now())
  FROM item_totals
  WHERE o.id = target_order_id;

  RETURN target_order_id;
END;
$$;

GRANT EXECUTE
ON FUNCTION public.create_self_order(UUID, INTEGER, TEXT, TEXT, TEXT, JSONB, TEXT)
TO anon, authenticated;

DROP FUNCTION IF EXISTS public.get_self_order_history(UUID, JSONB);

CREATE OR REPLACE FUNCTION public.get_self_order_history(
  target_outlet_id UUID,
  known_order_ids JSONB DEFAULT '[]'::jsonb,
  target_table_key TEXT DEFAULT NULL,
  target_table_number INTEGER DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_table_key TEXT;
  safe_known_order_ids JSONB;
  result JSONB;
BEGIN
  resolved_table_key := NULLIF(
    btrim(COALESCE(target_table_key, target_table_number::text, '')),
    ''
  );

  IF known_order_ids IS NULL OR jsonb_typeof(known_order_ids) <> 'array' THEN
    safe_known_order_ids := '[]'::jsonb;
  ELSE
    safe_known_order_ids := known_order_ids;
  END IF;

  SELECT COALESCE(
    jsonb_agg(history_rows.order_payload ORDER BY history_rows.updated_at DESC),
    '[]'::jsonb
  )
  INTO result
  FROM (
    SELECT
      o.created_at,
      o.updated_at,
      jsonb_build_object(
        'id', o.id,
        'outlet_id', o.outlet_id,
        'business_id', o.business_id,
        'invoice_number', o.invoice_number,
        'customer_name', o.customer_name,
        'customer_phone', o.customer_phone,
        'customer_email', o.customer_email,
        'table_number', o.table_number,
        'self_order_table_key', o.self_order_table_key,
        'status', o.status,
        'order_source', o.order_source,
        'notes', o.notes,
        'subtotal', o.subtotal,
        'discount_total', o.discount_total,
        'tax_amount', o.tax_amount,
        'grand_total', o.grand_total,
        'paid_amount', o.paid_amount,
        'change_amount', o.change_amount,
        'cashier_id', o.cashier_id,
        'cashier_name', o.cashier_name,
        'waiter_id', o.waiter_id,
        'waiter_name', o.waiter_name,
        'created_at', o.created_at,
        'updated_at', o.updated_at,
        'paid_at', o.paid_at,
        'order_items', (
          SELECT COALESCE(
            jsonb_agg(
              jsonb_build_object(
                'id', oi.id,
                'menu_item_id', oi.menu_item_id,
                'variant_id', oi.variant_id,
                'name', oi.name,
                'variant_name', oi.variant_name,
                'quantity', oi.quantity,
                'unit_price', oi.unit_price,
                'subtotal', oi.subtotal,
                'notes', oi.notes,
                'discount_id', oi.discount_id,
                'discount_name', oi.discount_name,
                'discount_type', oi.discount_type,
                'discount_percentage', oi.discount_percentage,
                'discount_amount', oi.discount_amount,
                'discount_applied', oi.discount_applied
              )
              ORDER BY oi.created_at ASC
            ),
            '[]'::jsonb
          )
          FROM public.order_items oi
          WHERE oi.order_id = o.id
        ),
        'order_discounts', '[]'::jsonb,
        'order_payments', '[]'::jsonb
      ) AS order_payload
    FROM public.orders o
    WHERE o.outlet_id = target_outlet_id
      AND o.order_source = 'qr_self_order'
      AND (
        o.id IN (
          SELECT value::uuid
          FROM jsonb_array_elements_text(safe_known_order_ids)
          WHERE value ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
        )
        OR (
          resolved_table_key IS NOT NULL
          AND o.status = 'confirmed'
          AND o.paid_at IS NULL
          AND (
            o.self_order_table_key = resolved_table_key
            OR (
              o.self_order_table_key IS NULL
              AND target_table_number IS NOT NULL
              AND o.table_number = target_table_number
            )
          )
        )
      )
  ) AS history_rows;

  RETURN result;
END;
$$;

GRANT EXECUTE
ON FUNCTION public.get_self_order_history(UUID, JSONB, TEXT, INTEGER)
TO anon, authenticated;
-- <<< END FILE: 20260430103000_merge_qr_self_orders_by_table.sql <<<

-- ==========================================
-- >>> START FILE: 20260430112000_add_void_reason_to_orders.sql >>>
-- ==========================================
-- Add void_reason to orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS void_reason TEXT;

COMMENT ON COLUMN public.orders.void_reason IS 'Alasan pembatalan pesanan (void).';
-- <<< END FILE: 20260430112000_add_void_reason_to_orders.sql <<<

-- ==========================================
-- >>> START FILE: 20260430113000_enhance_void_system.sql >>>
-- ==========================================
-- 1. Add voided_by to orders
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS voided_by UUID REFERENCES auth.users(id) ON DELETE SET NULL;
COMMENT ON COLUMN public.orders.voided_by IS 'User ID yang melakukan pembatalan (void).';

-- 2. Create Order Status Logs for Audit Trail
CREATE TABLE IF NOT EXISTS public.order_status_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    from_status public.order_status,
    to_status public.order_status NOT NULL,
    reason TEXT,
    performed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc', now())
);

CREATE INDEX IF NOT EXISTS order_status_logs_order_id_idx ON public.order_status_logs(order_id);

-- 3. Trigger Function to Log Status Changes
CREATE OR REPLACE FUNCTION public.log_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF (OLD.status IS DISTINCT FROM NEW.status) THEN
        INSERT INTO public.order_status_logs (
            order_id,
            from_status,
            to_status,
            reason,
            performed_by
        ) VALUES (
            NEW.id,
            OLD.status,
            NEW.status,
            NEW.void_reason,
            NEW.voided_by
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_log_order_status_change ON public.orders;
CREATE TRIGGER tr_log_order_status_change
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.log_order_status_change();

-- 4. Trigger Function to Restore Stock on Void
CREATE OR REPLACE FUNCTION public.restore_stock_on_void()
RETURNS TRIGGER AS $$
DECLARE
    item_rec RECORD;
    current_stock INTEGER;
    new_stock INTEGER;
BEGIN
    -- Trigger when status changes to 'void' or 'refunded'
    IF (OLD.status NOT IN ('void', 'refunded') AND NEW.status IN ('void', 'refunded')) THEN
        FOR item_rec IN 
            SELECT menu_item_id, quantity 
            FROM public.order_items 
            WHERE order_id = NEW.id AND menu_item_id IS NOT NULL
        LOOP
            -- Get current stock
            SELECT stock_quantity INTO current_stock
            FROM public.menu_items
            WHERE id = item_rec.menu_item_id
            FOR UPDATE;

            IF current_stock IS NOT NULL THEN
                new_stock := current_stock + item_rec.quantity;

                -- Update stock
                UPDATE public.menu_items
                SET stock_quantity = new_stock
                WHERE id = item_rec.menu_item_id;

                -- Record movement
                INSERT INTO public.inventory_movements (
                    business_id,
                    outlet_id,
                    menu_item_id,
                    movement_type,
                    quantity_before,
                    quantity_delta,
                    quantity_after,
                    note,
                    reference_type,
                    reference_id,
                    performed_by_user_id
                ) VALUES (
                    NEW.business_id,
                    NEW.outlet_id,
                    item_rec.menu_item_id,
                    CASE WHEN NEW.status = 'void' THEN 'void_restore' ELSE 'refund' END::public.inventory_movement_type,
                    current_stock,
                    item_rec.quantity,
                    new_stock,
                    CASE WHEN NEW.status = 'void' THEN 'Pembatalan Pesanan: ' ELSE 'Refund Pesanan: ' END || NEW.invoice_number,
                    'order',
                    NEW.id,
                    NEW.voided_by
                );
            END IF;
        END LOOP;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS tr_restore_stock_on_void ON public.orders;
CREATE TRIGGER tr_restore_stock_on_void
    AFTER UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION public.restore_stock_on_void();

-- 5. Add RLS for order_status_logs
ALTER TABLE public.order_status_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "order_status_logs_select" ON public.order_status_logs;
CREATE POLICY "order_status_logs_select" ON public.order_status_logs
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_status_logs.order_id
  )
);
-- <<< END FILE: 20260430113000_enhance_void_system.sql <<<

-- ==========================================
-- >>> START FILE: 20260504100000_shared_cart_system.sql >>>
-- ==========================================
-- =============================================================
-- SHARED CART SYSTEM: Manage draft orders for QR/Self-Ordering
-- =============================================================

-- 1. Function to Sync Draft Cart (Add/Update Items)
CREATE OR REPLACE FUNCTION public.sync_self_order_draft(
  target_outlet_id UUID,
  target_table_number INTEGER,
  items_payload JSONB -- Array of {menu_item_id, variant_id, quantity, notes}
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  resolved_business_id UUID;
  target_order_id UUID;
  new_invoice_number TEXT;
BEGIN
  -- Get business ID
  SELECT business_id INTO resolved_business_id FROM public.outlets WHERE id = target_outlet_id;
  
  -- Find existing DRAFT order for this table
  SELECT id INTO target_order_id 
  FROM public.orders 
  WHERE outlet_id = target_outlet_id 
    AND table_number = target_table_number 
    AND status = 'draft' 
    AND order_source = 'qr_self_order'
  LIMIT 1;

  -- If no draft exists, create a new one
  IF target_order_id IS NULL THEN
    target_order_id := gen_random_uuid();
    new_invoice_number := public.generate_invoice_number(target_outlet_id);
    
    INSERT INTO public.orders (
      id, outlet_id, business_id, invoice_number, table_number, status, order_source
    ) VALUES (
      target_order_id, target_outlet_id, resolved_business_id, new_invoice_number, target_table_number, 'draft', 'qr_self_order'
    );
  END IF;

  -- Clear existing items in draft
  DELETE FROM public.order_items WHERE order_id = target_order_id;

  -- Insert new items from payload
  INSERT INTO public.order_items (
    order_id, menu_item_id, variant_id, name, variant_name, quantity, unit_price, subtotal, notes
  )
  SELECT 
    target_order_id,
    requested.menu_item_id,
    requested.variant_id,
    mi.name,
    mv.name,
    requested.quantity,
    COALESCE(mv.price, mi.price),
    COALESCE(mv.price, mi.price) * requested.quantity,
    requested.notes
  FROM jsonb_to_recordset(items_payload) AS requested(
    menu_item_id UUID, variant_id UUID, quantity INTEGER, notes TEXT
  )
  JOIN public.menu_items mi ON mi.id = requested.menu_item_id
  LEFT JOIN public.menu_item_variants mv ON mv.id = requested.variant_id;

  -- Update order totals
  UPDATE public.orders 
  SET 
    subtotal = (SELECT SUM(subtotal) FROM public.order_items WHERE order_id = target_order_id),
    grand_total = (SELECT SUM(subtotal) FROM public.order_items WHERE order_id = target_order_id),
    updated_at = now()
  WHERE id = target_order_id;

  RETURN target_order_id;
END;
$$;

-- 2. Function to Confirm Order (Change Draft to Confirmed)
CREATE OR REPLACE FUNCTION public.confirm_self_order_draft(
  target_order_id UUID,
  target_customer_name TEXT,
  target_customer_phone TEXT DEFAULT NULL,
  target_order_notes TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  UPDATE public.orders 
  SET 
    status = 'confirmed',
    customer_name = target_customer_name,
    customer_phone = target_customer_phone,
    notes = target_order_notes,
    updated_at = now()
  WHERE id = target_order_id AND status = 'draft';
END;
$$;

-- 3. Grant Access
GRANT EXECUTE ON FUNCTION public.sync_self_order_draft(UUID, INTEGER, JSONB) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION public.confirm_self_order_draft(UUID, TEXT, TEXT, TEXT) TO anon, authenticated;
-- <<< END FILE: 20260504100000_shared_cart_system.sql <<<

-- ==========================================
-- >>> START FILE: 20260511110000_add_tiered_pricing.sql >>>
-- ==========================================
-- Migration to add tiered pricing support to menu items
CREATE TABLE IF NOT EXISTS menu_item_tiered_prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    menu_item_id UUID NOT NULL REFERENCES menu_items(id) ON DELETE CASCADE,
    min_quantity INTEGER NOT NULL CHECK (min_quantity > 0),
    price NUMERIC NOT NULL DEFAULT 0,
    business_id UUID REFERENCES public.businesses(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(menu_item_id, min_quantity)
);

-- Create indexes
CREATE INDEX IF NOT EXISTS menu_item_tiered_prices_menu_item_id_idx ON menu_item_tiered_prices(menu_item_id);
CREATE INDEX IF NOT EXISTS menu_item_tiered_prices_business_id_idx ON menu_item_tiered_prices(business_id);

-- Add comment
COMMENT ON TABLE menu_item_tiered_prices IS 'Table to store tiered pricing for products (e.g., bulk discounts based on quantity).';

-- Trigger for updated_at
CREATE TRIGGER update_menu_item_tiered_prices_updated_at
    BEFORE UPDATE ON menu_item_tiered_prices
    FOR EACH ROW
    EXECUTE PROCEDURE handle_updated_at();

-- RLS Policies
ALTER TABLE menu_item_tiered_prices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "menu_item_tiered_prices_manage_policy" ON menu_item_tiered_prices
    FOR ALL
    TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_tiered_prices.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
    )
    WITH CHECK (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_tiered_prices.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
            AND bm.role IN ('owner', 'admin')
        )
    );

CREATE POLICY "menu_item_tiered_prices_select_policy" ON menu_item_tiered_prices
    FOR SELECT
    TO authenticated
    USING (
        public.is_business_owner(business_id) OR
        EXISTS (
            SELECT 1 FROM public.business_members bm
            WHERE bm.business_id = menu_item_tiered_prices.business_id
            AND bm.user_id = auth.uid()
            AND bm.status = 'active'
        ) OR
        EXISTS (
            SELECT 1 FROM public.outlet_members om
            JOIN public.outlets o ON o.id = om.outlet_id
            WHERE o.business_id = menu_item_tiered_prices.business_id
              AND om.user_id = auth.uid()
              AND om.status = 'active'
        )
    );
-- <<< END FILE: 20260511110000_add_tiered_pricing.sql <<<

-- ==========================================
-- >>> START FILE: 20260511140000_add_subscription_plans.sql >>>
-- ==========================================
-- Migration: Add Subscription Plans and Feature Control
-- Date: 2026-05-11

-- 1. Create Subscription Plans table
create table if not exists public.subscription_plans (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    code text not null unique,
    max_transactions_month int not null default 100,
    max_products int not null default 50,
    max_outlets int not null default 1,
    features jsonb not null default '{
        "tiered_pricing": false,
        "qr_ordering": false,
        "kds": false,
        "table_management": false,
        "advanced_reports": false, 
        "inventory_management": false,
        "barcode_scanner": false,
        "realtime_notifications": false
    }'::jsonb,
    price_monthly numeric not null default 0,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

-- 2. Add plan reference to businesses
alter table public.businesses 
add column if not exists plan_id uuid references public.subscription_plans(id),
add column if not exists subscription_status text not null default 'active',
add column if not exists subscription_end_at timestamptz;

-- 3. Seed initial plans
insert into public.subscription_plans (name, code, max_transactions_month, max_products, max_outlets, price_monthly, features)
values 
('Free Plan', 'free', 150, 50, 1, 0, '{
    "tiered_pricing": false, 
    "qr_ordering": false, 
    "kds": false, 
    "table_management": false,
    "advanced_reports": false,
    "inventory_management": false,
    "barcode_scanner": true,
    "realtime_notifications": false
}'),
('Pro Plan', 'pro', 999999, 999999, 5, 150000, '{
    "tiered_pricing": true, 
    "qr_ordering": true, 
    "kds": true, 
    "table_management": true,
    "advanced_reports": true,
    "inventory_management": true,
    "barcode_scanner": true,
    "realtime_notifications": true
}'),
('Enterprise', 'enterprise', 999999, 999999, 99, 500000, '{
    "tiered_pricing": true, 
    "qr_ordering": true, 
    "kds": true, 
    "table_management": true,
    "advanced_reports": true,
    "inventory_management": true,
    "barcode_scanner": true,
    "realtime_notifications": true
}')
on conflict (code) do update 
set 
    max_transactions_month = excluded.max_transactions_month,
    max_products = excluded.max_products,
    max_outlets = excluded.max_outlets,
    features = excluded.features,
    price_monthly = excluded.price_monthly;

-- 4. Function to automatically set Free Plan for new businesses
create or replace function public.handle_new_business_plan()
returns trigger
language plpgsql
as $$
declare
    free_plan_id uuid;
begin
    select id into free_plan_id from public.subscription_plans where code = 'free';
    new.plan_id := free_plan_id;
    return new;
end;
$$;

drop trigger if exists on_business_created_set_plan on public.businesses;

create trigger on_business_created_set_plan
before insert on public.businesses
for each row
execute function public.handle_new_business_plan();

-- 5. Enable RLS for subscription_plans
alter table public.subscription_plans enable row level security;

drop policy if exists "Allow all to read plans" on public.subscription_plans;

create policy "Allow all to read plans"
on public.subscription_plans
for select
to authenticated
using (true);
-- <<< END FILE: 20260511140000_add_subscription_plans.sql <<<

-- ==========================================
-- >>> START FILE: 20260511150000_cleanup_plans.sql >>>
-- ==========================================
-- 1. Bersihkan paket Enterprise
DELETE FROM public.subscription_plans WHERE code = 'enterprise';

-- 2. Update fitur untuk paket Free
UPDATE public.subscription_plans 
SET 
    name = 'Free Plan',
    max_transactions_month = 500, -- Naikkan sedikit biar menarik
    max_products = 50,
    max_outlets = 1,
    price_monthly = 0,
    features = '{
        "dashboard_sales": true,
        "order_notifications": true,
        "website_catalog": true,
        "staff_management": true,
        "transaction_history": true,
        "refund_void": true,
        "discount_management": true,
        "retail_catalog": true,
        "tiered_pricing": false, 
        "qr_ordering": false, 
        "kds": false, 
        "table_management": false,
        "inventory_management": false,
        "realtime_notifications": false
    }'::jsonb
WHERE code = 'free';

-- 3. Update fitur untuk paket Pro (Semua fitur aktif)
UPDATE public.subscription_plans 
SET 
    name = 'Pro Plan',
    max_transactions_month = 999999,
    max_products = 999999,
    max_outlets = 999999, -- Unlimited
    price_monthly = 150000,
    features = '{
        "dashboard_sales": true,
        "order_notifications": true,
        "website_catalog": true,
        "staff_management": true,
        "transaction_history": true,
        "refund_void": true,
        "discount_management": true,
        "retail_catalog": true,
        "tiered_pricing": true, 
        "qr_ordering": true, 
        "kds": true, 
        "table_management": true,
        "inventory_management": true,
        "realtime_notifications": true
    }'::jsonb
WHERE code = 'pro';

-- 4. Pastikan semua bisnis yang pakai plan Enterprise dipindah ke Pro atau Free (Safety check)
UPDATE public.businesses 
SET plan_id = (SELECT id FROM public.subscription_plans WHERE code = 'pro')
WHERE plan_id NOT IN (SELECT id FROM public.subscription_plans);
-- <<< END FILE: 20260511150000_cleanup_plans.sql <<<

-- ==========================================
-- >>> START FILE: 20260511160000_add_feature_gate_toggle.sql >>>
-- ==========================================
-- Migration: Add feature gate toggle to businesses
-- Date: 2026-05-11

ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS is_feature_gate_enabled BOOLEAN NOT NULL DEFAULT true;

COMMENT ON COLUMN public.businesses.is_feature_gate_enabled IS 'Toggle to enable or disable plan-based feature gating. If false, all features are unlocked.';
-- <<< END FILE: 20260511160000_add_feature_gate_toggle.sql <<<

-- ==========================================
-- >>> START FILE: 20260511170000_add_business_type_and_features.sql >>>
-- ==========================================
-- Add business_type and enabled_features to businesses table
-- business_type: The template type chosen during onboarding (cafe, retail, etc)
-- enabled_features: List of active feature keys for this business (dynamic mapping)

ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS business_type text;

ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS enabled_features text[] DEFAULT '{}'::text[];

COMMENT ON COLUMN public.businesses.business_type IS 'The primary business category template (cafe, retail, laundry, showroom, kuliner).';
COMMENT ON COLUMN public.businesses.enabled_features IS 'List of dynamically enabled menu features for this specific business.';
-- <<< END FILE: 20260511170000_add_business_type_and_features.sql <<<

-- ==========================================
-- >>> START FILE: 20260512110000_add_business_templates.sql >>>
-- ==========================================
-- Migration: Add Business Type Templates for Dynamic Feature Mapping
-- Date: 2026-05-12

CREATE TABLE IF NOT EXISTS public.business_type_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE, -- e.g., 'Retail', 'F&B', 'Service'
    code TEXT NOT NULL UNIQUE, -- e.g., 'retail', 'fnb', 'service'
    description TEXT,
    icon_name TEXT, -- Material icon name or local asset path
    default_enabled_features JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Seed initial templates
INSERT INTO public.business_type_templates (name, code, description, icon_name, default_enabled_features)
VALUES 
('Food & Beverage', 'fnb', 'Template for cafes, restaurants, and bars', 'restaurant_rounded', '["transaction", "order_mgmt", "menu_mgmt", "table_mgmt", "kitchen_kds", "reports"]'),
('Retail', 'retail', 'Template for shops and boutiques', 'shopping_bag_rounded', '["transaction", "menu_mgmt", "inventory", "reports"]'),
('Layanan / Service', 'service', 'Template for salons, barbershops, and consultants', 'handyman_rounded', '["transaction", "order_mgmt", "reports"]'),
('General / All Features', 'general', 'Template with all features enabled', 'apps_rounded', '["transaction", "order_mgmt", "menu_mgmt", "table_mgmt", "kitchen_kds", "inventory", "qr_order", "reports"]')
ON CONFLICT (code) DO UPDATE 
SET default_enabled_features = EXCLUDED.default_enabled_features,
    icon_name = EXCLUDED.icon_name,
    description = EXCLUDED.description;

-- Ensure businesses table has the columns (User added them in model, let's make sure they are in DB)
ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS business_type TEXT,
ADD COLUMN IF NOT EXISTS enabled_features JSONB NOT NULL DEFAULT '[]'::jsonb;

-- RLS for templates
ALTER TABLE public.business_type_templates ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all to read templates" ON public.business_type_templates FOR SELECT TO authenticated USING (true);

-- Policy for managing templates (Restricted to specific admin email for now)
CREATE POLICY "Allow admin to manage templates" ON public.business_type_templates 
FOR ALL TO authenticated 
USING (auth.jwt() ->> 'email' = 'diyanto2911@gmail.com')
WITH CHECK (auth.jwt() ->> 'email' = 'diyanto2911@gmail.com');
-- <<< END FILE: 20260512110000_add_business_templates.sql <<<

-- ==========================================
-- >>> START FILE: 20260512120000_add_dynamic_limits.sql >>>
-- ==========================================
-- Migration: Add Dynamic Limits and Ad Control
-- Date: 2026-05-12

-- Add limit columns to business_type_templates
ALTER TABLE public.business_type_templates 
ADD COLUMN IF NOT EXISTS max_transactions INTEGER DEFAULT 100,
ADD COLUMN IF NOT EXISTS max_products INTEGER DEFAULT 50,
ADD COLUMN IF NOT EXISTS max_outlets INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS show_ads BOOLEAN DEFAULT true;

-- Add limit columns to businesses (as overrides)
ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS max_transactions INTEGER,
ADD COLUMN IF NOT EXISTS max_products INTEGER,
ADD COLUMN IF NOT EXISTS max_outlets INTEGER,
ADD COLUMN IF NOT EXISTS show_ads BOOLEAN;

-- Update existing templates with some default limits
UPDATE public.business_type_templates 
SET max_transactions = 999999, max_products = 999999, max_outlets = 5, show_ads = false 
WHERE code = 'general';

UPDATE public.business_type_templates 
SET max_transactions = 500, max_products = 100, max_outlets = 1, show_ads = true 
WHERE code IN ('fnb', 'retail');
-- <<< END FILE: 20260512120000_add_dynamic_limits.sql <<<

-- ==========================================
-- >>> START FILE: 20260512130000_add_features_config_to_templates.sql >>>
-- ==========================================
-- Migration: Add features_config to support Free/Pro gating per template
-- Date: 2026-05-12

-- Add features_config to business_type_templates
ALTER TABLE public.business_type_templates 
ADD COLUMN IF NOT EXISTS features_config JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Add features_config to businesses (for per-business overrides)
ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS features_config JSONB NOT NULL DEFAULT '{}'::jsonb;

-- Initialize features_config based on existing default_enabled_features
-- We assume existing enabled features are 'free' by default for now
UPDATE public.business_type_templates 
SET features_config = (
    SELECT jsonb_object_agg(feat, 'free')
    FROM jsonb_array_elements_text(default_enabled_features) AS feat
)
WHERE default_enabled_features != '[]'::jsonb;

-- Update specific templates for testing Pro features
UPDATE public.business_type_templates 
SET features_config = features_config || '{"inventory": "pro", "qr_order": "pro", "reports": "pro"}'::jsonb
WHERE code IN ('fnb', 'retail', 'general');
 
-- <<< END FILE: 20260512130000_add_features_config_to_templates.sql <<<

-- ==========================================
-- >>> START FILE: 20260512140000_add_tiered_limits_to_templates.sql >>>
-- ==========================================
-- Migration: Add limits_config to support separate limits for Free and Pro tiers
-- Date: 2026-05-12

-- Add limits_config to business_type_templates
ALTER TABLE public.business_type_templates 
ADD COLUMN IF NOT EXISTS limits_config JSONB NOT NULL DEFAULT '{"free": {}, "pro": {}}'::jsonb;

-- Add limits_config to businesses (for per-business overrides)
ALTER TABLE public.businesses 
ADD COLUMN IF NOT EXISTS limits_config JSONB NOT NULL DEFAULT '{"free": {}, "pro": {}}'::jsonb;

-- Initialize limits_config based on existing limit columns
UPDATE public.business_type_templates 
SET limits_config = jsonb_build_object(
    'free', jsonb_build_object(
        'max_transactions', max_transactions,
        'max_products', max_products,
        'max_outlets', max_outlets
    ),
    'pro', jsonb_build_object(
        'max_transactions', 999999, -- Default high for Pro
        'max_products', 999999,
        'max_outlets', 5
    )
);

-- Sync businesses as well
UPDATE public.businesses 
SET limits_config = jsonb_build_object(
    'free', jsonb_build_object(
        'max_transactions', COALESCE(max_transactions, 100),
        'max_products', COALESCE(max_products, 50),
        'max_outlets', COALESCE(max_outlets, 1)
    ),
    'pro', jsonb_build_object(
        'max_transactions', 999999,
        'max_products', 999999,
        'max_outlets', 5
    )
)
WHERE business_type IS NOT NULL;
-- <<< END FILE: 20260512140000_add_tiered_limits_to_templates.sql <<<

-- ==========================================
-- >>> START FILE: 20260512150000_grant_super_admin_access.sql >>>
-- ==========================================
-- Migration: Grant Super Admin Access to Businesses and Profiles
-- Date: 2026-05-12

-- 1. Policy for Super Admin to SELECT all businesses
DROP POLICY IF EXISTS "Allow super admin to select all businesses" ON public.businesses;
CREATE POLICY "Allow super admin to select all businesses" ON public.businesses
FOR SELECT TO authenticated
USING (
    auth.jwt() ->> 'email' = 'diyanto2911@gmail.com'
    OR owner_user_id = auth.uid()
);

-- 2. Policy for Super Admin to UPDATE all businesses
DROP POLICY IF EXISTS "Allow super admin to update all businesses" ON public.businesses;
CREATE POLICY "Allow super admin to update all businesses" ON public.businesses
FOR UPDATE TO authenticated
USING (
    auth.jwt() ->> 'email' = 'diyanto2911@gmail.com'
    OR owner_user_id = auth.uid()
)
WITH CHECK (
    auth.jwt() ->> 'email' = 'diyanto2911@gmail.com'
    OR owner_user_id = auth.uid()
);

-- 3. Policy for Super Admin to SELECT all profiles
DROP POLICY IF EXISTS "Allow super admin to select all profiles" ON public.profiles;
CREATE POLICY "Allow super admin to select all profiles" ON public.profiles
FOR SELECT TO authenticated
USING (
    auth.jwt() ->> 'email' = 'diyanto2911@gmail.com'
    OR id = auth.uid()
);
-- <<< END FILE: 20260512150000_grant_super_admin_access.sql <<<

-- ==========================================
-- >>> START FILE: 20260512160000_add_role_labels_to_templates.sql >>>
-- ==========================================
-- Add role_labels column to business_type_templates table
ALTER TABLE business_type_templates 
ADD COLUMN IF NOT EXISTS role_labels JSONB DEFAULT '{}'::jsonb;

-- Add role_labels column to businesses table
ALTER TABLE businesses 
ADD COLUMN IF NOT EXISTS role_labels JSONB DEFAULT '{}'::jsonb;
-- <<< END FILE: 20260512160000_add_role_labels_to_templates.sql <<<

-- ==========================================
-- >>> START FILE: 20260518013000_sync_business_feature_configs.sql >>>
-- ==========================================
-- Migration: Sync Business Feature Configs from Templates for empty/null fields
-- Date: 2026-05-18

UPDATE public.businesses b
SET 
  features_config = t.features_config,
  limits_config = t.limits_config,
  role_labels = t.role_labels,
  max_transactions = COALESCE(b.max_transactions, t.max_transactions),
  max_products = COALESCE(b.max_products, t.max_products),
  max_outlets = COALESCE(b.max_outlets, t.max_outlets)
FROM public.business_type_templates t
WHERE b.business_type = t.code 
  AND (b.features_config = '{}'::jsonb OR b.features_config IS NULL);
-- <<< END FILE: 20260518013000_sync_business_feature_configs.sql <<<

-- ==========================================
-- >>> START FILE: 20260518020000_add_editable_price_to_templates.sql >>>
-- ==========================================
-- Migration: Add editable_price feature flag to templates and active businesses
-- Date: 2026-05-18

-- 1. Update business_type_templates features_config
-- Let's make editable_price 'free' for showroom motor, and 'pro' for others
UPDATE public.business_type_templates
SET features_config = features_config || '{"editable_price": "free"}'::jsonb
WHERE code = 'showroom';

UPDATE public.business_type_templates
SET features_config = features_config || '{"editable_price": "pro"}'::jsonb
WHERE code != 'showroom';

-- 2. Update existing businesses features_config to include editable_price if not already present
-- We match the templates to make sure they get the correct default based on their business_type
UPDATE public.businesses b
SET features_config = b.features_config || jsonb_build_object('editable_price', COALESCE(t.features_config->>'editable_price', 'pro'))
FROM public.business_type_templates t
WHERE b.business_type = t.code
  AND (b.features_config->>'editable_price') IS NULL;
-- <<< END FILE: 20260518020000_add_editable_price_to_templates.sql <<<

-- ==========================================
-- >>> START FILE: 99990430_notification_webhook_setup.sql >>>
-- ==========================================
-- 1. Create a trigger function that calls our Edge Function
CREATE OR REPLACE FUNCTION public.on_order_inserted()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Call the Edge Function via HTTP (Standard Supabase Webhook pattern)
  -- Note: Replace '<YOUR_EDGE_FUNCTION_URL>' with your actual function URL
  -- and '<YOUR_SERVICE_ROLE_KEY>' with your service role key if needed.
  
  -- Alternatively, use Supabase Dashboard 'Webhooks' UI to point to:
  -- URL: https://<project-ref>.supabase.co/functions/v1/send-order-notification
  
  RETURN NEW;
END;
$$;

-- 2. Create the Trigger
-- NOTE: It's usually easier to use the Supabase Dashboard UI for Webhooks
-- but here is how you would do it in SQL if using pg_net or similar:
--
-- CREATE TRIGGER tr_send_order_notification
-- AFTER INSERT ON public.orders
-- FOR EACH ROW
-- EXECUTE FUNCTION public.on_order_inserted();

/*
GUIDE TO SETUP WEBHOOKS IN SUPABASE DASHBOARD:
1. Go to Database -> Webhooks.
2. Click "Enable Webhooks" if not enabled.
3. Click "Create a new webhook".
4. Name: send_order_notification
5. Table: orders
6. Events: INSERT
7. Type: HTTP Request
8. Method: POST
9. URL: https://<your-project-ref>.supabase.co/functions/v1/send-order-notification
10. Headers: 
    - Content-Type: application/json
    - Authorization: Bearer <YOUR_SERVICE_ROLE_KEY>
*/
-- <<< END FILE: 99990430_notification_webhook_setup.sql <<<

-- ==========================================
-- >>> START FILE: 20260520000000_subscription_plans_pricing_tiers.sql >>>
-- ==========================================
-- 1. Ensure table public.subscription_plans exists
create table if not exists public.subscription_plans (
    id uuid primary key default gen_random_uuid(),
    name text not null,
    code text not null unique,
    max_transactions_month int not null default 150,
    max_products int not null default 50,
    max_outlets int not null default 1,
    features jsonb not null default '{
        "tiered_pricing": false,
        "qr_ordering": false,
        "kds": false,
        "table_management": false,
        "advanced_reports": false, 
        "inventory_management": false,
        "barcode_scanner": true,
        "realtime_notifications": false
    }'::jsonb,
    price_monthly numeric not null default 0,
    pricing_tiers jsonb not null default '{
        "1_month": 49000,
        "3_months": 129000,
        "6_months": 239000,
        "12_months": 399000,
        "lifetime": 799000
    }'::jsonb,
    created_at timestamptz not null default timezone('utc', now()),
    updated_at timestamptz not null default timezone('utc', now())
);

-- 2. Add pricing_tiers column if table already exists
alter table public.subscription_plans
add column if not exists pricing_tiers jsonb not null default '{
    "1_month": 49000,
    "3_months": 129000,
    "6_months": 239000,
    "12_months": 399000,
    "lifetime": 799000
}'::jsonb;

-- 3. Upsert default Free and Pro plans
insert into public.subscription_plans (name, code, max_transactions_month, max_products, max_outlets, price_monthly, pricing_tiers, features)
values 
('Free Plan', 'free', 150, 50, 1, 0, '{}'::jsonb, '{
    "tiered_pricing": false, 
    "qr_ordering": false, 
    "kds": false, 
    "table_management": false,
    "advanced_reports": false,
    "inventory_management": false,
    "barcode_scanner": true,
    "realtime_notifications": false
}'::jsonb),
('Pro Plan', 'pro', 999999, 999999, 5, 49000, '{
    "1_month": 49000,
    "3_months": 129000,
    "6_months": 239000,
    "12_months": 399000,
    "lifetime": 799000
}'::jsonb, '{
    "tiered_pricing": true, 
    "qr_ordering": true, 
    "kds": true, 
    "table_management": true,
    "advanced_reports": true,
    "inventory_management": true,
    "barcode_scanner": true,
    "realtime_notifications": true
}'::jsonb)
on conflict (code) do update set
    pricing_tiers = excluded.pricing_tiers,
    price_monthly = excluded.price_monthly,
    updated_at = timezone('utc', now());

-- 4. Enable RLS and setup policies
alter table public.subscription_plans enable row level security;

-- Read policy: Everyone can view active plans
drop policy if exists "Allow all to read plans" on public.subscription_plans;
create policy "Allow all to read plans"
on public.subscription_plans
for select
using (true);

-- Admin policy: Super Admin can insert, update, delete
drop policy if exists "Allow super admin all on subscription_plans" on public.subscription_plans;
create policy "Allow super admin all on subscription_plans"
on public.subscription_plans
for all
to authenticated
using (auth.jwt() ->> 'email' = 'diyanto2911@gmail.com')
with check (auth.jwt() ->> 'email' = 'diyanto2911@gmail.com');
-- <<< END FILE: 20260520000000_subscription_plans_pricing_tiers.sql <<<
