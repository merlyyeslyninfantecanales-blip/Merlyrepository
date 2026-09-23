-- PracticApp sample profiles
-- Before running this file:
-- 1. Create each user in Supabase Authentication > Users.
-- 2. Copy each Auth User UID.
-- 3. Replace the placeholders below:
--    AUTH_UID_ESTUDIANTE
--    AUTH_UID_ENCARGADO

insert into public.companies (
  name,
  ruc,
  phone,
  address,
  contact_name,
  email,
  latitude,
  longitude,
  total_vacancies
)
values (
  'Tech Solutions SAC',
  '20567890123',
  '987654321',
  'Av. Principal 123, Zorritos',
  'Luis Ramirez',
  'contacto@techsolutions.pe',
  -3.6817,
  -80.6760,
  4
)
on conflict (ruc) do update set
  name = excluded.name,
  phone = excluded.phone,
  address = excluded.address,
  contact_name = excluded.contact_name,
  email = excluded.email,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  total_vacancies = excluded.total_vacancies;

insert into public.students (
  full_name,
  code,
  email,
  phone,
  program,
  semester
)
values (
  'Juan Perez Lopez',
  '2021001',
  'juan.perez@student.edu.pe',
  '987654321',
  'Arquitectura de plataformas y servicios de tecnologias de la informacion',
  'VI'
)
on conflict (code) do update set
  full_name = excluded.full_name,
  email = excluded.email,
  phone = excluded.phone,
  program = excluded.program,
  semester = excluded.semester;

insert into public.profiles (
  auth_user_id,
  role,
  full_name,
  email,
  avatar,
  student_id
)
select
  '65d3ff1e-a5a1-4012-a23b-bd0a9e9a9970'::uuid,
  'estudiante',
  'Juan Perez Lopez',
  'juanperezlopez@gmail.com',
  'JP',
  students.id
from public.students
where students.code = '2021001'
on conflict (email) do update set
  auth_user_id = excluded.auth_user_id,
  role = excluded.role,
  full_name = excluded.full_name,
  avatar = excluded.avatar,
  student_id = excluded.student_id;

insert into public.profiles (
  auth_user_id,
  role,
  full_name,
  email,
  avatar,
  company_id
)
select
  '6ddc51a0-f572-47b7-9744-7dcc310a11cf'::uuid,
  'encargado',
  'Luis Ramirez',
  'luisramirez@gmail.com',
  'LR',
  companies.id
from public.companies
where companies.ruc = '20567890123'
on conflict (email) do update set
  auth_user_id = excluded.auth_user_id,
  role = excluded.role,
  full_name = excluded.full_name,
  avatar = excluded.avatar,
  company_id = excluded.company_id;
