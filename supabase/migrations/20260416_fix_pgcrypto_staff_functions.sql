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
