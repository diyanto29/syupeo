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
