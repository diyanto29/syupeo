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
