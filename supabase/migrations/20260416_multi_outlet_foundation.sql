create table if not exists public.outlets (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses (id) on delete cascade,
  name text not null,
  code text,
  address text,
  phone text,
  timezone text not null default 'Asia/Jakarta',
  is_active boolean not null default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (business_id, code)
);

create index if not exists outlets_business_id_idx
  on public.outlets (business_id);

create table if not exists public.outlet_members (
  id uuid primary key default gen_random_uuid(),
  outlet_id uuid not null references public.outlets (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.app_role not null,
  status public.membership_status not null default 'active',
  assigned_by uuid references public.profiles (id) on delete set null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (outlet_id, user_id)
);

create index if not exists outlet_members_outlet_id_idx
  on public.outlet_members (outlet_id);

create index if not exists outlet_members_user_id_idx
  on public.outlet_members (user_id);

drop trigger if exists set_outlets_updated_at on public.outlets;
create trigger set_outlets_updated_at
before update on public.outlets
for each row
execute function public.set_updated_at();

drop trigger if exists set_outlet_members_updated_at on public.outlet_members;
create trigger set_outlet_members_updated_at
before update on public.outlet_members
for each row
execute function public.set_updated_at();

alter table public.outlets enable row level security;
alter table public.outlet_members enable row level security;

drop policy if exists "outlets_select_related" on public.outlets;
create policy "outlets_select_related"
on public.outlets
for select
to authenticated
using (
  exists (
    select 1
    from public.businesses b
    where b.id = outlets.business_id
      and b.owner_user_id = auth.uid()
  )
  or exists (
    select 1
    from public.business_members bm
    where bm.business_id = outlets.business_id
      and bm.user_id = auth.uid()
      and bm.status = 'active'
  )
  or exists (
    select 1
    from public.outlet_members om
    where om.outlet_id = outlets.id
      and om.user_id = auth.uid()
      and om.status = 'active'
  )
);

drop policy if exists "outlets_insert_owner" on public.outlets;
create policy "outlets_insert_owner"
on public.outlets
for insert
to authenticated
with check (public.is_business_owner(business_id));

drop policy if exists "outlets_update_owner" on public.outlets;
create policy "outlets_update_owner"
on public.outlets
for update
to authenticated
using (public.is_business_owner(business_id))
with check (public.is_business_owner(business_id));

drop policy if exists "outlet_members_select_related" on public.outlet_members;
create policy "outlet_members_select_related"
on public.outlet_members
for select
to authenticated
using (
  user_id = auth.uid()
  or exists (
    select 1
    from public.outlets o
    where o.id = outlet_members.outlet_id
      and public.is_business_owner(o.business_id)
  )
);

drop policy if exists "outlet_members_insert_owner" on public.outlet_members;
create policy "outlet_members_insert_owner"
on public.outlet_members
for insert
to authenticated
with check (
  exists (
    select 1
    from public.outlets o
    where o.id = outlet_id
      and public.is_business_owner(o.business_id)
  )
);

drop policy if exists "outlet_members_update_owner" on public.outlet_members;
create policy "outlet_members_update_owner"
on public.outlet_members
for update
to authenticated
using (
  exists (
    select 1
    from public.outlets o
    where o.id = outlet_members.outlet_id
      and public.is_business_owner(o.business_id)
  )
)
with check (
  exists (
    select 1
    from public.outlets o
    where o.id = outlet_id
      and public.is_business_owner(o.business_id)
  )
);

insert into public.outlets (
  business_id,
  name,
  code,
  phone,
  timezone,
  is_active
)
select
  b.id,
  b.name,
  'main',
  b.phone,
  b.timezone,
  true
from public.businesses b
where not exists (
  select 1
  from public.outlets o
  where o.business_id = b.id
);

insert into public.outlet_members (
  outlet_id,
  user_id,
  role,
  status,
  assigned_by
)
select
  o.id,
  bm.user_id,
  bm.role,
  bm.status,
  bm.invited_by
from public.outlets o
join public.business_members bm
  on bm.business_id = o.business_id
where not exists (
  select 1
  from public.outlet_members om
  where om.outlet_id = o.id
    and om.user_id = bm.user_id
);
