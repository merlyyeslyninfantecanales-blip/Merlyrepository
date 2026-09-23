alter table public.students
add column if not exists semester text not null default '';
