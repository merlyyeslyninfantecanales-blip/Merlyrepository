-- PracticApp - Supabase/PostgreSQL schema
-- Run this file in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.companies (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  ruc text not null unique,
  phone text,
  address text,
  contact_name text,
  email text not null,
  latitude double precision,
  longitude double precision,
  total_vacancies integer not null default 0 check (total_vacancies >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.students (
  id uuid primary key default gen_random_uuid(),
  full_name text not null,
  code text not null unique,
  email text not null,
  phone text,
  program text not null,
  semester text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid unique references auth.users(id) on delete set null,
  role text not null check (role in ('supervisor', 'encargado', 'estudiante')),
  full_name text not null,
  email text not null unique,
  avatar text,
  company_id uuid references public.companies(id) on delete set null,
  student_id uuid references public.students(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.practices (
  id uuid primary key default gen_random_uuid(),
  student_id uuid not null references public.students(id) on delete cascade,
  company_id uuid not null references public.companies(id) on delete restrict,
  practice_module text not null default 'I' check (practice_module in ('I', 'II', 'III')),
  shift text not null check (shift in ('Mañana', 'Tarde', 'Día completo')),
  start_date date not null,
  end_date date,
  required_hours integer not null check (required_hours > 0),
  accumulated_hours integer not null default 0 check (accumulated_hours >= 0),
  status text not null default 'active'
    check (status in ('active', 'completed', 'pending', 'cancelled')),
  learning_objective text not null,
  completed_objectives text[] not null default '{}',
  pending_objectives text[] not null default '{}',
  monthly_reports text[] not null default '{}',
  certificate_issued boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  practice_id uuid not null references public.practices(id) on delete cascade,
  attendance_date date not null,
  check_in_at timestamptz,
  check_out_at timestamptz,
  status text not null check (status in ('present', 'absent', 'late', 'permission')),
  hours numeric(6,2) not null default 0 check (hours >= 0),
  notes text,
  latitude double precision,
  longitude double precision,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.evaluations (
  id uuid primary key default gen_random_uuid(),
  practice_id uuid not null references public.practices(id) on delete cascade,
  title text not null,
  score integer not null check (score between 0 and 100),
  comment text not null,
  performance text not null,
  pdf_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.tracking_records (
  id uuid primary key default gen_random_uuid(),
  practice_id uuid not null references public.practices(id) on delete cascade,
  title text not null,
  progress integer not null check (progress between 0 and 100),
  completed_objectives text,
  pending_objectives text,
  monthly_report text not null,
  pdf_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.vacancies (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete cascade,
  position text not null,
  description text not null,
  requirements text,
  required_hours integer not null check (required_hours between 160 and 480),
  schedule text not null,
  shift text not null check (shift in ('Mañana', 'Tarde', 'Día completo')),
  status text not null default 'open' check (status in ('open', 'occupied', 'closed')),
  student_id uuid references public.students(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.certificates (
  id uuid primary key default gen_random_uuid(),
  practice_id uuid not null unique references public.practices(id) on delete cascade,
  student_id uuid not null references public.students(id) on delete cascade,
  issued_at timestamptz not null default now(),
  pdf_path text,
  created_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists companies_set_updated_at on public.companies;
create trigger companies_set_updated_at
before update on public.companies
for each row execute function public.set_updated_at();

drop trigger if exists students_set_updated_at on public.students;
create trigger students_set_updated_at
before update on public.students
for each row execute function public.set_updated_at();

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

drop trigger if exists practices_set_updated_at on public.practices;
create trigger practices_set_updated_at
before update on public.practices
for each row execute function public.set_updated_at();

drop trigger if exists attendance_records_set_updated_at on public.attendance_records;
create trigger attendance_records_set_updated_at
before update on public.attendance_records
for each row execute function public.set_updated_at();

drop trigger if exists evaluations_set_updated_at on public.evaluations;
create trigger evaluations_set_updated_at
before update on public.evaluations
for each row execute function public.set_updated_at();

drop trigger if exists tracking_records_set_updated_at on public.tracking_records;
create trigger tracking_records_set_updated_at
before update on public.tracking_records
for each row execute function public.set_updated_at();

drop trigger if exists vacancies_set_updated_at on public.vacancies;
create trigger vacancies_set_updated_at
before update on public.vacancies
for each row execute function public.set_updated_at();

insert into storage.buckets (id, name, public)
values ('practicapp-documents', 'practicapp-documents', false)
on conflict (id) do nothing;

alter table public.companies enable row level security;
alter table public.students enable row level security;
alter table public.profiles enable row level security;
alter table public.practices enable row level security;
alter table public.attendance_records enable row level security;
alter table public.evaluations enable row level security;
alter table public.tracking_records enable row level security;
alter table public.vacancies enable row level security;
alter table public.certificates enable row level security;

create policy "authenticated users can read companies"
on public.companies for select to authenticated using (true);
create policy "authenticated users can read students"
on public.students for select to authenticated using (true);
create policy "authenticated users can read profiles"
on public.profiles for select to authenticated using (true);
create policy "authenticated users can read practices"
on public.practices for select to authenticated using (true);
create policy "authenticated users can read attendance"
on public.attendance_records for select to authenticated using (true);
create policy "authenticated users can read evaluations"
on public.evaluations for select to authenticated using (true);
create policy "authenticated users can read tracking"
on public.tracking_records for select to authenticated using (true);
create policy "authenticated users can read vacancies"
on public.vacancies for select to authenticated using (true);
create policy "authenticated users can read certificates"
on public.certificates for select to authenticated using (true);

create policy "authenticated users can write companies"
on public.companies for all to authenticated using (true) with check (true);
create policy "authenticated users can write students"
on public.students for all to authenticated using (true) with check (true);
create policy "authenticated users can write profiles"
on public.profiles for all to authenticated using (true) with check (true);
create policy "authenticated users can write practices"
on public.practices for all to authenticated using (true) with check (true);
create policy "authenticated users can write attendance"
on public.attendance_records for all to authenticated using (true) with check (true);
create policy "authenticated users can write evaluations"
on public.evaluations for all to authenticated using (true) with check (true);
create policy "authenticated users can write tracking"
on public.tracking_records for all to authenticated using (true) with check (true);
create policy "authenticated users can write vacancies"
on public.vacancies for all to authenticated using (true) with check (true);
create policy "authenticated users can write certificates"
on public.certificates for all to authenticated using (true) with check (true);
