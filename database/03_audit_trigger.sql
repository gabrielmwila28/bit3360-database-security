-- =====================================================================
-- 03_audit_trigger.sql
-- BIT3360 Advanced Databases: Secure Student Records Management System
-- Block 3: Automated trigger-based audit logging (FR-06, FR-07, OD-06).
--
-- Run after 01_schema.sql and 02_rls_and_grants.sql in Supabase SQL Editor.
-- =====================================================================

begin;

create or replace function private.log_record_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_record_id text;
  v_old_json  jsonb;
  v_new_json  jsonb;
  v_role_name text;
begin
  -- current_user inside a SECURITY DEFINER function is the function owner;
  -- current_setting('role', true) reflects the active SET ROLE / API role.
  v_role_name := coalesce(nullif(current_setting('role', true), ''), current_user);

  if tg_op = 'INSERT' then
    v_new_json  := to_jsonb(new);
    v_old_json  := null;
    v_record_id := v_new_json ->> 'id';
  elsif tg_op = 'UPDATE' then
    v_old_json  := to_jsonb(old);
    v_new_json  := to_jsonb(new);
    v_record_id := coalesce(v_new_json ->> 'id', v_old_json ->> 'id');
  elsif tg_op = 'DELETE' then
    v_old_json  := to_jsonb(old);
    v_new_json  := null;
    v_record_id := v_old_json ->> 'id';
  end if;

  insert into public.audit_logs (
    table_name,
    operation,
    record_id,
    changed_by_auth_uid,
    changed_by_db_role,
    old_data,
    new_data
  )
  values (
    tg_table_schema || '.' || tg_table_name,
    tg_op,
    v_record_id,
    auth.uid(),
    v_role_name,
    v_old_json,
    v_new_json
  );

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

revoke all on function private.log_record_change() from public, anon, authenticated;

-- Attach AFTER row triggers to the four audited tables (OD-06).
-- Note: cascaded deletes on public.enrollments (when a student is deleted)
-- also fire this trigger automatically.
drop trigger if exists trg_audit_profiles on public.profiles;
create trigger trg_audit_profiles
  after insert or update or delete on public.profiles
  for each row execute function private.log_record_change();

drop trigger if exists trg_audit_students on public.students;
create trigger trg_audit_students
  after insert or update or delete on public.students
  for each row execute function private.log_record_change();

drop trigger if exists trg_audit_courses on public.courses;
create trigger trg_audit_courses
  after insert or update or delete on public.courses
  for each row execute function private.log_record_change();

drop trigger if exists trg_audit_enrollments on public.enrollments;
create trigger trg_audit_enrollments
  after insert or update or delete on public.enrollments
  for each row execute function private.log_record_change();

commit;