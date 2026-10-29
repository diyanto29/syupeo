insert into storage.buckets (id, name, public)
values ('staff-avatars', 'staff-avatars', true)
on conflict (id) do nothing;

drop policy if exists "staff_avatars_public_read" on storage.objects;
create policy "staff_avatars_public_read"
on storage.objects
for select
to public
using (bucket_id = 'staff-avatars');

drop policy if exists "staff_avatars_authenticated_upload" on storage.objects;
create policy "staff_avatars_authenticated_upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'staff-avatars');

drop policy if exists "staff_avatars_authenticated_update" on storage.objects;
create policy "staff_avatars_authenticated_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'staff-avatars')
with check (bucket_id = 'staff-avatars');
