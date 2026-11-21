# BIT3360 Security Verification & Test Log (`TC-01` – `TC-14`)

**Assigned Testers:** Gabriel Mwila & Ndame  
**Test Harness:** `database/06_verification_tests.sql` (run each block individually in Supabase SQL Editor)

| ID | Layer | Actor / Role | Action Tested | Expected Outcome | Observed Result | Status | Tester / Date |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-01** | API / Grants | `anon` (unauthenticated) | `SELECT * FROM public.students` | Blocked (`SQLSTATE 42501`: permission denied) | | Pending | |
| **TC-02** | API / RLS | `student.a@bit3360.test` | `SELECT * FROM public.students` | Returns 1 row (`STU-2026-001` only) | | Pending | |
| **TC-03** | API / RLS | `student.a@bit3360.test` | `SELECT * FROM public.enrollments` | Returns 2 rows (Student A's courses only) | | Pending | |
| **TC-04** | API / RLS | `student.a@bit3360.test` | `UPDATE public.enrollments SET marks = 99` | 0 rows updated (blocked by RLS) | | Pending | |
| **TC-05** | API / RLS | `lecturer1@bit3360.test` | `SELECT * FROM public.enrollments` | Returns 2 rows (`BIT3360` only; hides `BIT3201`) | | Pending | |
| **TC-06** | API / Trigger | `lecturer1@bit3360.test` | `UPDATE public.enrollments SET marks = 78` (Student B) | Succeeds; grade auto-derived as `'A'` | | Pending | |
| **TC-07** | API / Trigger | `lecturer1@bit3360.test` | `UPDATE public.enrollments SET student_id = ...` | Blocked (`SQLSTATE 42501`: non-admin FK change) | | Pending | |
| **TC-08** | API / RLS | `admin@bit3360.test` | `SELECT` on `students` & `enrollments` | Returns all 3 students and 4 enrolments | | Pending | |
| **TC-09** | API / Grants | `authenticated` / `admin` | `DELETE FROM public.audit_logs` | Blocked (`SQLSTATE 42501`: permission denied) | `ERROR: 42501: permission denied for table audit_logs` | **PASS** | Ndame / 2026-11-21 |
| **TC-10** | Audit Trigger | `admin@bit3360.test` | `SELECT * FROM public.audit_logs` after `INSERT`/`UPDATE` | Captures `table_name`, `operation`, `record_id`, `OLD`/`NEW` JSONB, `changed_by_auth_uid`, `changed_by_db_role` | Verified `INSERT` (`marks=44`, `grade='D'`) and `UPDATE` (`marks: 54 -> 55`) logged with full JSONB snapshots | **PASS** | Ndame / 2026-11-21 |
| **TC-11** | SQL Grants | `demo_student` | Read `id, student_number, full_name` vs. `year_of_study` / `demo.enrollments` | Permitted columns succeed (3 rows); `year_of_study` & `enrollments` fail (`42501`) | Permitted columns returned `STU-2026-001`..`003`; `SELECT * FROM demo.enrollments` failed with `ERROR: 42501: permission denied for table enrollments` | **PASS** | Ndame / 2026-11-21 |
| **TC-12** | SQL Grants | `demo_lecturer` | `UPDATE (marks)` on `demo.enrollments` vs. `DELETE` on `demo.students` / `demo.enrollments` | Column-level `UPDATE (marks)` succeeds; `DELETE` fails (`42501`) | `UPDATE demo.enrollments SET marks = 85.00` succeeded (1 row); `DELETE` failed with `ERROR: 42501: permission denied` | **PASS** | Ndame / 2026-11-21 |
| **TC-13** | SQL Grants | `demo_admin` | DML (`INSERT`/`DELETE`) vs. DDL (`CREATE TABLE`) on `demo` | DML succeeds; `CREATE TABLE` fails (`42501`) | `INSERT INTO demo.courses ('TEST999', 'Temp Audit Check')` succeeded and rolled back cleanly; DDL blocked (`42501`) | **PASS** | Ndame / 2026-11-21 |
| **TC-14** | SQL Injection | `demo_student` | `search_students_unsafe` vs. `search_students_safe` with `' OR '1'='1` | Unsafe dumps all 3 student rows; Safe returns 0 rows | `search_students_unsafe` leaked all seeded student rows; `search_students_safe` returned `0 rows` | **PASS** | Ndame / 2026-11-21 |
