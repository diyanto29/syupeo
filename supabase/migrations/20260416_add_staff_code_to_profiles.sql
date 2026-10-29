alter table public.profiles
add column if not exists staff_code text;

create unique index if not exists profiles_staff_code_unique_idx
  on public.profiles (lower(staff_code))
  where staff_code is not null;
