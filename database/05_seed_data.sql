-- =====================================================================
-- 05_seed_data.sql
-- BIT3360 Advanced Databases: Secure Student Records Management System
-- Block 3: Synthetic seed data (Acceptance Criterion 2 & Section 13).
--
-- Prerequisites:
--   1. Run 01_schema.sql, 02_rls_and_grants.sql, 03_audit_trigger.sql,
--      and 04_roles_and_grants.sql.
--   2. Ensure the 6 synthetic Auth users exist in Supabase Dashboard
--      (Authentication > Users) so `on_auth_user_created` populates
--      `public.profiles`:
--        - admin@bit3360.test      (1 admin)
--        - lecturer1@bit3360.test  (lecturer 1)
--        - lecturer2@bit3360.test  (lecturer 2)
--        - student.a@bit3360.test  (student A)
--        - student.b@bit3360.test  (student B)
--        - student.c@bit3360.test  (student C)
-- =====================================================================

begin;

do $$
declare
  v_admin_id            uuid;
  v_lec1_id             uuid;
  v_lec2_id             uuid;
  v_stu_a_id            uuid;
  v_stu_b_id            uuid;
  v_stu_c_id            uuid;

  v_student_a_id        bigint;
  v_student_b_id        bigint;
  v_student_c_id        bigint;

  v_course_1_id         bigint;
  v_course_2_id         bigint;

  v_has_year_of_study   boolean;
  v_has_national_id     boolean;
begin
  select id into v_admin_id from public.profiles where lower(email) = 'admin@bit3360.test';
  select id into v_lec1_id  from public.profiles where lower(email) = 'lecturer1@bit3360.test';
  select id into v_lec2_id  from public.profiles where lower(email) = 'lecturer2@bit3360.test';
  select id into v_stu_a_id from public.profiles where lower(email) = 'student.a@bit3360.test';
  select id into v_stu_b_id from public.profiles where lower(email) = 'student.b@bit3360.test';
  select id into v_stu_c_id from public.profiles where lower(email) = 'student.c@bit3360.test';

  if v_admin_id is null or v_lec1_id is null or v_lec2_id is null
     or v_stu_a_id is null or v_stu_b_id is null or v_stu_c_id is null then
    raise exception 'Missing one or more seeded Auth user profiles. Create the 6 demo accounts in Auth first.';
  end if;

  -- Step 1: Promote admin and lecturers (signup trigger defaults to 'student').
  update public.profiles
     set full_name = 'System Administrator', app_role = 'admin'
   where id = v_admin_id;

  update public.profiles
     set full_name = 'Dr. Banda (Course 1)', app_role = 'lecturer'
   where id = v_lec1_id;

  update public.profiles
     set full_name = 'Dr. Phiri (Course 2)', app_role = 'lecturer'
   where id = v_lec2_id;

  update public.profiles
     set full_name = 'Student A Mwamba'
   where id = v_stu_a_id;

  update public.profiles
     set full_name = 'Student B Tembo'
   where id = v_stu_b_id;

  update public.profiles
     set full_name = 'Student C Lungu'
   where id = v_stu_c_id;

  -- Step 2: Seed 3 students in public.students.
  insert into public.students (profile_id, student_number, full_name, year_of_study)
  values
    (v_stu_a_id, 'STU-2026-001', 'Student A Mwamba', 3),
    (v_stu_b_id, 'STU-2026-002', 'Student B Tembo',  3),
    (v_stu_c_id, 'STU-2026-003', 'Student C Lungu',  2)
  on conflict (profile_id) do update
    set student_number = excluded.student_number,
        full_name = excluded.full_name,
        year_of_study = excluded.year_of_study;

  select id into v_student_a_id from public.students where profile_id = v_stu_a_id;
  select id into v_student_b_id from public.students where profile_id = v_stu_b_id;
  select id into v_student_c_id from public.students where profile_id = v_stu_c_id;

  -- Step 3: Seed 2 courses (one per lecturer).
  insert into public.courses (course_code, title, lecturer_id)
  values
    ('BIT3360', 'Advanced Databases & Security', v_lec1_id),
    ('BIT3201', 'Software Engineering Management', v_lec2_id)
  on conflict (course_code) do update
    set title = excluded.title,
        lecturer_id = excluded.lecturer_id;

  select id into v_course_1_id from public.courses where course_code = 'BIT3360';
  select id into v_course_2_id from public.courses where course_code = 'BIT3201';

  -- Step 4: Seed 4 enrolments (A-C1, A-C2, B-C1, C-C2).
  -- Grade will be derived automatically by the grade trigger in 02_rls_and_grants.sql.
  insert into public.enrollments (student_id, course_id, marks, updated_by)
  values
    (v_student_a_id, v_course_1_id, 82.00, v_admin_id),
    (v_student_a_id, v_course_2_id, 68.00, v_admin_id),
    (v_student_b_id, v_course_1_id, 55.00, v_admin_id),
    (v_student_c_id, v_course_2_id, 44.00, v_admin_id)
  on conflict (student_id, course_id) do update
    set marks = excluded.marks,
        updated_by = excluded.updated_by;

  -- Step 5: Seed matching synthetic rows in `demo` schema for TC-11..TC-14.
  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'students'
      and column_name = 'year_of_study'
  ) into v_has_year_of_study;

  select exists (
    select 1
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'students'
      and column_name = 'national_id'
  ) into v_has_national_id;

  if v_has_year_of_study and v_has_national_id then
    insert into demo.students (student_number, full_name, year_of_study, national_id)
    values
      ('STU-2026-001', 'Student A Mwamba', 3, 'SYN-NAT-001'),
      ('STU-2026-002', 'Student B Tembo',  3, 'SYN-NAT-002'),
      ('STU-2026-003', 'Student C Lungu',  2, 'SYN-NAT-003')
    on conflict (student_number) do nothing;
  elsif v_has_year_of_study then
    insert into demo.students (student_number, full_name, year_of_study)
    values
      ('STU-2026-001', 'Student A Mwamba', 3),
      ('STU-2026-002', 'Student B Tembo',  3),
      ('STU-2026-003', 'Student C Lungu',  2)
    on conflict (student_number) do nothing;
  elsif v_has_national_id then
    insert into demo.students (student_number, full_name, national_id)
    values
      ('STU-2026-001', 'Student A Mwamba', 'SYN-NAT-001'),
      ('STU-2026-002', 'Student B Tembo',  'SYN-NAT-002'),
      ('STU-2026-003', 'Student C Lungu',  'SYN-NAT-003')
    on conflict (student_number) do nothing;
  else
    insert into demo.students (student_number, full_name)
    values
      ('STU-2026-001', 'Student A Mwamba'),
      ('STU-2026-002', 'Student B Tembo'),
      ('STU-2026-003', 'Student C Lungu')
    on conflict (student_number) do nothing;
  end if;

  insert into demo.courses (course_code, title)
  values
    ('BIT3360', 'Advanced Databases & Security'),
    ('BIT3201', 'Software Engineering Management')
  on conflict (course_code) do nothing;

  if exists (
    select 1
    from information_schema.columns
    where table_schema = 'demo'
      and table_name = 'enrollments'
      and column_name = 'grade'
  ) then
    insert into demo.enrollments (student_id, course_id, marks, grade)
    select s.id, c.id, v.marks, v.grade
    from (
      values
        ('STU-2026-001', 'BIT3360', 82.00::numeric, 'A'),
        ('STU-2026-001', 'BIT3201', 68.00::numeric, 'B'),
        ('STU-2026-002', 'BIT3360', 55.00::numeric, 'C'),
        ('STU-2026-003', 'BIT3201', 44.00::numeric, 'D')
    ) as v(student_number, course_code, marks, grade)
    join demo.students s on s.student_number = v.student_number
    join demo.courses  c on c.course_code = v.course_code
    on conflict (student_id, course_id) do nothing;
  else
    insert into demo.enrollments (student_id, course_id, marks)
    select s.id, c.id, v.marks
    from (
      values
        ('STU-2026-001', 'BIT3360', 82.00::numeric),
        ('STU-2026-001', 'BIT3201', 68.00::numeric),
        ('STU-2026-002', 'BIT3360', 55.00::numeric),
        ('STU-2026-003', 'BIT3201', 44.00::numeric)
    ) as v(student_number, course_code, marks)
    join demo.students s on s.student_number = v.student_number
    join demo.courses  c on c.course_code = v.course_code
    on conflict (student_id, course_id) do nothing;
  end if;
end
$$;

commit;