-- IT Management System: Supabase schema. Run once in Supabase > SQL Editor.

create table profiles (
  id   uuid primary key references auth.users on delete cascade,
  name text not null,
  role text not null default 'Employee'
       check (role in ('Administrator','IT Technician','Employee'))
);

create table records (
  entity     text not null,
  id         text not null,
  data       jsonb not null,
  updated_at timestamptz not null default now(),
  primary key (entity, id)
);

create table counters (entity text primary key, n int not null default 0);

alter table profiles enable row level security;
alter table records  enable row level security;
alter table counters enable row level security;

create or replace function my_role() returns text
  language sql stable security definer set search_path = public
  as $$ select role from profiles where id = auth.uid() $$;

create or replace function my_name() returns text
  language sql stable security definer set search_path = public
  as $$ select name from profiles where id = auth.uid() $$;

-- Next record number per entity (IT-0001, TKT-2026-0001 ...)
create or replace function next_id(p_entity text) returns int
  language plpgsql security definer set search_path = public as $$
declare v int;
begin
  if auth.uid() is null then raise exception 'login required'; end if;
  insert into counters(entity, n) values (p_entity, 1)
  on conflict (entity) do update set n = counters.n + 1
  returning n into v;
  return v;
end $$;

-- Profiles: users read their own; administrators manage all
create policy profiles_read  on profiles for select
  using (id = auth.uid() or my_role() = 'Administrator');
create policy profiles_admin on profiles for all
  using (my_role() = 'Administrator') with check (my_role() = 'Administrator');

-- Records
create policy rec_select on records for select using (
  my_role() in ('Administrator','IT Technician')
  or (my_role() = 'Employee' and (
        entity in ('employees','departments','locations','categories')
        or (entity = 'tickets' and data->>'requester' = my_name())))
);

create policy rec_insert on records for insert with check (
  my_role() = 'Administrator'
  or (my_role() = 'IT Technician'
      and entity not in ('users','departments','locations','categories','employees'))
  or (my_role() = 'Employee'
      and (entity = 'log' or (entity = 'tickets' and data->>'requester' = my_name())))
);

create policy rec_update on records for update
  using (my_role() = 'Administrator'
         or (my_role() = 'IT Technician'
             and entity not in ('users','departments','locations','categories','employees')))
  with check (my_role() = 'Administrator'
         or (my_role() = 'IT Technician'
             and entity not in ('users','departments','locations','categories','employees')));

create policy rec_delete on records for delete using (my_role() = 'Administrator');
