-- =====================================================================
--  EFALP Nurseries – Plant Management App · Supabase database setup
--  Supabase → SQL Editor → New query → paste this whole file → Run.
--  Safe to run again (it doesn't delete data).
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- tables ----------
create table if not exists public.profiles (
  id          uuid primary key references auth.users(id) on delete cascade,
  email       text not null,
  name        text,
  role        text not null default 'pending' check (role in ('superadmin','manager','engineer','viewer','pending')),
  active      boolean not null default true,
  created_at  timestamptz not null default now()
);

-- allowed roles (re-applied so older databases get the Viewer role too)
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('superadmin','manager','engineer','viewer','pending'));

create table if not exists public.settings (
  key   text primary key,
  value text not null default ''
);

create table if not exists public.fields (
  col          text primary key,            -- internal key, never changes
  label        text not null,               -- shown in the app
  type         text not null default 'text',-- text | number | date | select | longtext | url
  grp          text not null default 'Other',
  options      text not null default '',    -- dropdown options separated by ;
  show_in_qr   boolean not null default false,
  show_in_list boolean not null default false,
  required     boolean not null default false,
  sort         integer not null default 0,
  active       boolean not null default true
);

create table if not exists public.plants (
  barcode     text primary key,
  location    text not null,
  data        jsonb not null default '{}'::jsonb,   -- all field values, keyed by fields.col
  sizes       jsonb not null default '{}'::jsonb,   -- {"0-50": 125, "51-100": 850, ...}
  total       integer not null default 0,
  updated_by  text,
  updated_at  timestamptz not null default now(),
  created_at  timestamptz not null default now()
);

create table if not exists public.reports (
  id            uuid primary key default gen_random_uuid(),
  barcode       text not null references public.plants(barcode) on update cascade on delete cascade,
  date          date not null default current_date,
  health        text,
  note          text,
  photos        text[] not null default '{}',
  created_by    text,
  created_by_id uuid default auth.uid(),
  created_at    timestamptz not null default now()
);
create index if not exists reports_barcode_idx on public.reports(barcode);

create table if not exists public.activity (
  id        bigserial primary key,
  ts        timestamptz not null default now(),
  user_name text,
  action    text,
  target    text,
  details   text
);

create table if not exists public.sync_state (
  tbl     text primary key,
  version bigint not null default 0
);
insert into public.sync_state(tbl)
values ('plants'),('reports'),('fields'),('settings'),('profiles'),('activity')
on conflict do nothing;

-- ---------- helper functions ----------
-- current user's role (null if not signed in, disabled or still pending)
create or replace function public.my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid() and active and role <> 'pending'
$$;

-- true for roles that may add / edit (everyone except Viewer)
create or replace function public.can_edit() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() in ('superadmin','manager','engineer'), false)
$$;

-- every new sign-up gets a profile: the very first one is Super Admin, the rest wait for approval
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, email, name, role)
  values (new.id, lower(new.email),
          coalesce(nullif(new.raw_user_meta_data->>'name', ''), split_part(new.email, '@', 1)),
          case when exists (select 1 from public.profiles where role = 'superadmin') then 'pending' else 'superadmin' end)
  on conflict (id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- never allow removing the last active Super Admin
create or replace function public.keep_one_superadmin() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if old.role = 'superadmin' and old.active
     and (tg_op = 'DELETE' or new.role <> 'superadmin' or not new.active)
     and not exists (select 1 from public.profiles where role = 'superadmin' and active and id <> old.id) then
    raise exception 'There must be at least one active Super Admin';
  end if;
  return coalesce(new, old);
end $$;
drop trigger if exists keep_one_superadmin on public.profiles;
create trigger keep_one_superadmin before update or delete on public.profiles
  for each row execute function public.keep_one_superadmin();

-- live sync: bump a version number whenever a table changes
create or replace function public.bump_version() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update public.sync_state set version = version + 1 where tbl = tg_table_name;
  return null;
end $$;
do $$
declare t text;
begin
  foreach t in array array['plants','reports','fields','settings','profiles','activity'] loop
    execute format('drop trigger if exists bump_%1$s on public.%1$s', t);
    execute format('create trigger bump_%1$s after insert or update or delete on public.%1$s
                    for each statement execute function public.bump_version()', t);
  end loop;
end $$;

-- delete the stored values of a removed field (Super Admin only)
create or replace function public.remove_field_data(p_col text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if coalesce(public.my_role(), '') <> 'superadmin' then raise exception 'Super Admin only'; end if;
  update public.plants set data = data - p_col where data ? p_col;
end $$;

-- ---------- security (row level security) ----------
alter table public.profiles   enable row level security;
alter table public.settings   enable row level security;
alter table public.fields     enable row level security;
alter table public.plants     enable row level security;
alter table public.reports    enable row level security;
alter table public.activity   enable row level security;
alter table public.sync_state enable row level security;

do $$
declare r record;
begin
  for r in select policyname, tablename from pg_policies
           where schemaname = 'public' and policyname like 'efalp_%' loop
    execute format('drop policy %I on public.%I', r.policyname, r.tablename);
  end loop;
end $$;

-- profiles: everyone sees their own row; staff see the team; only Super Admin changes roles
create policy efalp_profiles_read   on public.profiles for select to authenticated using (id = auth.uid() or public.my_role() is not null);
create policy efalp_profiles_update on public.profiles for update to authenticated using (public.my_role() = 'superadmin') with check (public.my_role() = 'superadmin');
create policy efalp_profiles_delete on public.profiles for delete to authenticated using (public.my_role() = 'superadmin');

-- settings & fields: staff read, Super Admin writes
create policy efalp_settings_read  on public.settings for select to authenticated using (public.my_role() is not null);
create policy efalp_settings_write on public.settings for all    to authenticated using (public.my_role() = 'superadmin') with check (public.my_role() = 'superadmin');
create policy efalp_fields_read    on public.fields   for select to authenticated using (public.my_role() is not null);
create policy efalp_fields_write   on public.fields   for all    to authenticated using (public.my_role() = 'superadmin') with check (public.my_role() = 'superadmin');

-- plants: all staff read/add/edit; Super Admin & Manager delete
create policy efalp_plants_read   on public.plants for select to authenticated using (public.my_role() is not null);
create policy efalp_plants_insert on public.plants for insert to authenticated with check (public.can_edit());
create policy efalp_plants_update on public.plants for update to authenticated using (public.can_edit()) with check (public.can_edit());
create policy efalp_plants_delete on public.plants for delete to authenticated using (public.my_role() in ('superadmin','manager'));

-- reports: all staff read/add; Super Admin & Manager (or the author) delete
create policy efalp_reports_read   on public.reports for select to authenticated using (public.my_role() is not null);
create policy efalp_reports_insert on public.reports for insert to authenticated with check (public.can_edit());
create policy efalp_reports_update on public.reports for update to authenticated using (public.my_role() in ('superadmin','manager'));
create policy efalp_reports_delete on public.reports for delete to authenticated
  using (public.my_role() in ('superadmin','manager') or (public.can_edit() and created_by_id = auth.uid()));

-- activity log & sync state
create policy efalp_activity_read   on public.activity   for select to authenticated using (public.my_role() is not null);
create policy efalp_activity_insert on public.activity   for insert to authenticated with check (public.can_edit());
create policy efalp_sync_read       on public.sync_state for select to authenticated using (public.my_role() is not null);

grant usage on schema public to authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
grant execute on function public.my_role(), public.can_edit(), public.remove_field_data(text) to authenticated;
revoke all on all tables in schema public from anon;

-- ---------- photo storage ----------
insert into storage.buckets (id, name, public) values ('photos', 'photos', false)
on conflict (id) do nothing;

drop policy if exists efalp_photos_read   on storage.objects;
drop policy if exists efalp_photos_insert on storage.objects;
drop policy if exists efalp_photos_delete on storage.objects;
create policy efalp_photos_read   on storage.objects for select to authenticated using (bucket_id = 'photos' and public.my_role() is not null);
create policy efalp_photos_insert on storage.objects for insert to authenticated with check (bucket_id = 'photos' and public.can_edit());
create policy efalp_photos_delete on storage.objects for delete to authenticated using (bucket_id = 'photos' and public.can_edit());

-- Done. Next: run 2_data.sql to load the 354 stock lines.
