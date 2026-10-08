create table if not exists public.profiles (
    id uuid primary key references auth.users(id) on delete cascade,
    display_name text,
    preferred_locale text,
    onboarding_completed boolean not null default false,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create or replace function public.set_profiles_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
    new.updated_at = now();
    return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
    before update on public.profiles
    for each row execute procedure public.set_profiles_updated_at();

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
    insert into public.profiles (id, display_name, preferred_locale, onboarding_completed)
    values (
        new.id,
        nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
        nullif(trim(new.raw_user_meta_data ->> 'preferred_locale'), ''),
        false
    )
    on conflict (id) do nothing;
    return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
    after insert on auth.users
    for each row execute procedure public.handle_new_user();

alter table public.profiles enable row level security;

drop policy if exists profiles_select_own on public.profiles;
create policy profiles_select_own
    on public.profiles
    for select to authenticated
    using (auth.uid() = id);

drop policy if exists profiles_insert_own on public.profiles;
create policy profiles_insert_own
    on public.profiles
    for insert to authenticated
    with check (auth.uid() = id);

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
    on public.profiles
    for update to authenticated
    using (auth.uid() = id)
    with check (auth.uid() = id);

drop policy if exists profiles_delete_own on public.profiles;
create policy profiles_delete_own
    on public.profiles
    for delete to authenticated
    using (auth.uid() = id);

revoke all on public.profiles from anon;
revoke all on public.profiles from authenticated;
grant select, insert, update, delete on public.profiles to authenticated;

create or replace function public.delete_current_user()
returns void
language plpgsql
security definer set search_path = ''
as $$
begin
    if auth.uid() is null then
        raise exception 'not_authenticated';
    end if;

    delete from auth.users where id = auth.uid();
end;
$$;

revoke all on function public.delete_current_user() from public;
revoke all on function public.delete_current_user() from anon;
grant execute on function public.delete_current_user() to authenticated;
