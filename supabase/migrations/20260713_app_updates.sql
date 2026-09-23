create table if not exists public.app_updates (
  id uuid primary key default gen_random_uuid(),
  version_name text not null,
  version_code integer not null,
  apk_url text,
  notes text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

alter table public.app_updates enable row level security;

drop policy if exists "authenticated users can read app updates" on public.app_updates;
create policy "authenticated users can read app updates"
on public.app_updates
for select
to authenticated
using (active = true);

drop policy if exists "authenticated users can manage app updates" on public.app_updates;
create policy "authenticated users can manage app updates"
on public.app_updates
for all
to authenticated
using (true)
with check (true);
