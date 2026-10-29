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
