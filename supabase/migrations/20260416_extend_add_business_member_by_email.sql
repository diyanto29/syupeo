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
