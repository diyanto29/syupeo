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
