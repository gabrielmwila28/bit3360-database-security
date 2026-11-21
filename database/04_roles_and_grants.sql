-- =====================================================================
-- 04_roles_and_grants.sql
-- BIT3360 Advanced Databases: Secure Student Records Management System
-- Block 4: Standalone SQL roles (GRANT / REVOKE) on the `demo` schema
--          and parameterised vs. injectable search functions (TC-11..TC-14).
-- =====================================================================

begin;

-- 1. Create standalone demo roles if they do not exist (NOLOGIN roles
--    tested via `SET ROLE demo_...` in SQL sessions).
do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'demo_student') then
    create role demo_student nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'demo_lecturer') then
    create role demo_lecturer nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'demo_admin') then
    create role demo_admin nologin;
  end if;
end
$$;

-- 2. Create isolated `demo` schema with RLS disabled so standalone SQL
--    role privileges (`GRANT` / `REVOKE`) are directly observable.
create schema if not exists demo;
revoke all on schema demo from public, anon, authenticated;
revoke all on all tables in schema demo from public, anon, authenticated;
revoke all on all functions in schema demo from public, anon, authenticated;

alter default privileges in schema demo revoke all on tables    from public, anon, authenticated, demo_student, demo_lecturer, demo_admin;
alter default privileges in schema demo revoke all on sequences from public, anon, authenticated, demo_student, demo_lecturer, demo_admin;
alter default privileges in schema demo revoke all on functions from public, anon, authenticated, demo_student, demo_lecturer, demo_admin;

create table if not exists demo.students (
  id             bigint generated always as identity primary key,
  student_number text not null unique,
  full_name      text not null,
  year_of_study  smallint not null check (year_of_study between 1 and 6)
);

create table if not exists demo.courses (
  id          bigint generated always as identity primary key,
  course_code text not null unique,
  title       text not null
);

create table if not exists demo.enrollments (
  id         bigint generated always as identity primary key,
  student_id bigint not null references demo.students (id) on delete cascade,
  course_id  bigint not null references demo.courses (id) on delete cascade,
  marks      numeric(5, 2) check (marks between 0 and 100),
  grade      text check (grade in ('A', 'B', 'C', 'D', 'F')),
  unique (student_id, course_id)
);

-- Explicitly ensure RLS is disabled on demo tables (Section 6.2).
alter table demo.students    disable row level security;
alter table demo.courses     disable row level security;
alter table demo.enrollments disable row level security;

-- 3. Grant schema USAGE and per-role table / column privileges (Section 6.2).
grant usage on schema demo to demo_student, demo_lecturer, demo_admin;

-- Reset demo role grants first for idempotency
revoke all on all tables in schema demo from demo_student, demo_lecturer, demo_admin;

-- demo_student: read course catalogue + limited columns on students only
grant select on demo.courses to demo_student;
grant select (id, student_number, full_name) on demo.students to demo_student;

-- demo_lecturer: read demo tables + update marks column only on enrollments
grant select on demo.students, demo.courses, demo.enrollments to demo_lecturer;
grant update (marks) on demo.enrollments to demo_lecturer;

-- demo_admin: full DML on demo tables
grant select, insert, update, delete on demo.students, demo.courses, demo.enrollments to demo_admin;

-- 4. Injection demonstration functions (TC-14, FR-08).
--    WARNING: demo.search_students_unsafe() is intentionally vulnerable
--    for classroom demonstration on synthetic data ONLY.
drop function if exists demo.search_students_unsafe(text);
create or replace function demo.search_students_unsafe(p_query text)
returns setof demo.students
language plpgsql
security definer
set search_path = demo, pg_temp
as $$
declare
  v_sql text;
begin
  v_sql := format(
    'SELECT * FROM demo.students WHERE full_name ILIKE ''%%%s%%'' OR student_number ILIKE ''%%%s%%''',
    p_query,
    p_query
  );
  return query execute v_sql;
end;
$$;

drop function if exists demo.search_students_safe(text);
create or replace function demo.search_students_safe(p_query text)
returns setof demo.students
language plpgsql
security definer
set search_path = demo, pg_temp
as $$
declare
  v_pattern text := '%' || coalesce(p_query, '') || '%';
begin
  return query
    execute 'SELECT * FROM demo.students WHERE full_name ILIKE $1 OR student_number ILIKE $1'
    using v_pattern;
end;
$$;

revoke all on function demo.search_students_unsafe(text) from public, anon, authenticated;
revoke all on function demo.search_students_safe(text)   from public, anon, authenticated;
grant execute on function demo.search_students_unsafe(text) to demo_admin, demo_lecturer, demo_student;
grant execute on function demo.search_students_safe(text)   to demo_admin, demo_lecturer, demo_student;

commit;