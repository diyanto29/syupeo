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
