insert into storage.buckets (id, name, public)
values ('menu-item-images', 'menu-item-images', true)
on conflict (id) do nothing;

drop policy if exists "menu_item_images_public_read" on storage.objects;
create policy "menu_item_images_public_read"
on storage.objects
for select
to public
using (bucket_id = 'menu-item-images');

drop policy if exists "menu_item_images_authenticated_upload" on storage.objects;
create policy "menu_item_images_authenticated_upload"
on storage.objects
for insert
to authenticated
with check (bucket_id = 'menu-item-images');

drop policy if exists "menu_item_images_authenticated_update" on storage.objects;
create policy "menu_item_images_authenticated_update"
on storage.objects
for update
to authenticated
using (bucket_id = 'menu-item-images')
with check (bucket_id = 'menu-item-images');

drop policy if exists "menu_item_images_authenticated_delete" on storage.objects;
create policy "menu_item_images_authenticated_delete"
on storage.objects
for delete
to authenticated
using (bucket_id = 'menu-item-images');
