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
