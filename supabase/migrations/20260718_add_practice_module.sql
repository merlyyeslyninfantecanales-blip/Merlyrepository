alter table public.practices
add column if not exists practice_module text not null default 'I';

alter table public.practices
drop constraint if exists practices_practice_module_check;

update public.practices
set practice_module = 'I'
where practice_module is null or practice_module not in ('I', 'II', 'III');

alter table public.practices
alter column practice_module set default 'I';

alter table public.practices
alter column practice_module set not null;

alter table public.practices
add constraint practices_practice_module_check
check (practice_module in ('I', 'II', 'III'));
