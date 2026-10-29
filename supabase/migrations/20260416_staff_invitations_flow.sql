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
