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
