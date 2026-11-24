-- EFALP Nurseries · add the Viewer role (read-only). Safe to run more than once.
alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles add constraint profiles_role_check
  check (role in ('superadmin','manager','engineer','viewer','pending'));

create or replace function public.can_edit() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.my_role() in ('superadmin','manager','engineer'), false)
$$;
grant execute on function public.can_edit() to authenticated;

drop policy if exists efalp_plants_insert on public.plants;
drop policy if exists efalp_plants_update on public.plants;
drop policy if exists efalp_reports_insert on public.reports;
drop policy if exists efalp_reports_delete on public.reports;
drop policy if exists efalp_activity_insert on public.activity;
drop policy if exists efalp_photos_insert on storage.objects;
drop policy if exists efalp_photos_delete on storage.objects;

create policy efalp_plants_insert on public.plants for insert to authenticated with check (public.can_edit());
create policy efalp_plants_update on public.plants for update to authenticated using (public.can_edit()) with check (public.can_edit());
create policy efalp_reports_insert on public.reports for insert to authenticated with check (public.can_edit());
create policy efalp_reports_delete on public.reports for delete to authenticated
  using (public.my_role() in ('superadmin','manager') or (public.can_edit() and created_by_id = auth.uid()));
create policy efalp_activity_insert on public.activity for insert to authenticated with check (public.can_edit());
create policy efalp_photos_insert on storage.objects for insert to authenticated with check (bucket_id = 'photos' and public.can_edit());
create policy efalp_photos_delete on storage.objects for delete to authenticated using (bucket_id = 'photos' and public.can_edit());
