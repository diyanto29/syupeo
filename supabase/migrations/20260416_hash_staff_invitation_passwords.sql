create extension if not exists pgcrypto with schema extensions;

alter table public.staff_invitations
add column if not exists initial_password_hash text;

do $$
begin
  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'staff_invitations'
      and column_name = 'initial_password'
  ) then
    execute $sql$
      update public.staff_invitations
      set initial_password_hash = coalesce(
        initial_password_hash,
        case
          when nullif(trim(initial_password), '') is null then null
          else extensions.crypt(
            trim(initial_password),
            extensions.gen_salt('bf')
          )
        end
      )
      where initial_password is not null
    $sql$;

    execute 'alter table public.staff_invitations drop column initial_password';
  end if;
end
$$;
