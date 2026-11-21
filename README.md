# BIT3360 — Advanced Database Security

Role-based access control (RBAC), Row Level Security (RLS), least-privilege table grants, parameterised queries, automated audit logging, and data-integrity triggers implemented on PostgreSQL (Supabase) for an academic records management prototype.

---

## Group Members

| # | Full Name | Student Number | Role |
| :--- | :--- | :--- | :--- |
| 1 | Joshua Mazaza | 2410123 | Team lead, core schema & RLS policy architecture (`01_schema.sql`, `02_rls_and_grants.sql`), Supabase setup, PR review, and integration |
| 2 | Gabriel Mwila | 2410234 | Security verification & API/RLS test execution (`TC-01`–`TC-08` in `docs/TEST_CASES.md`) |
| 3 | Ndame Sepete | 2410559 | Audit triggers (`03_audit_trigger.sql`), standalone SQL demo roles & SQL injection demo (`04_roles_and_grants.sql`), seed updates (`05_seed_data.sql`), and testing (`TC-09`–`TC-14`) |
| 4 | Moses Phiri | 2410103 | Role-aware web client (`application/index.html`, `application/app.js`) using Supabase Auth, publishable key, and DOM-safe rendering |

---

## Repository Structure

```text
├── application/
│   ├── index.html                 # Role-aware web client (Supabase Auth + RLS demo)
│   └── app.js                     # Client logic using publishable key and DOM-safe rendering
├── database/
│   ├── 01_schema.sql              # Private schema, core tables, constraints, indexes, and helper functions
│   ├── 02_rls_and_grants.sql      # REVOKE/GRANT least-privilege rules and 15 per-operation RLS policies
│   ├── 03_audit_trigger.sql       # SECURITY DEFINER audit logging and enrollment guard/grade triggers
│   ├── 04_roles_and_grants.sql    # Standalone PostgreSQL roles (demo_student, demo_lecturer, demo_admin) & SQLi demo
│   ├── 05_seed_data.sql           # Synthetic profiles, students, courses, and enrollments
│   └── 06_verification_tests.sql  # SQL verification harness for TC-01 through TC-14
├── docs/
│   ├── PROJECT_SPEC.md            # Functional requirements, security model, and presentation plan
│   ├── DATABASE_DESIGN.md         # Entity definitions, keys, relationships, and design decisions
│   └── TEST_CASES.md              # Verified execution log for TC-01 through TC-14
├── presentation/
│   └── BIT3360_Database_Security.pptx
└── README.md
```

---

## Database Schema (`public`)

| Table | Purpose |
| :--- | :--- |
| `profiles` | Maps Supabase Auth users (`auth.users`) to application roles (`student`, `lecturer`, `admin`) |
| `students` | Student academic records linked to user profiles |
| `courses` | Course catalog and assigned lecturer mappings |
| `enrollments` | Student course registrations, marks, and derived grades |
| `audit_logs` | Append-only trail of `INSERT`, `UPDATE`, and `DELETE` actions across core tables |

---

## Security Controls Implemented

### 1. Least-Privilege Grants & API Lockdown
* Unauthenticated (`anon`) access is revoked across all `public` tables (`SQLSTATE 42501`: permission denied).
* Only explicitly required operations are granted to `authenticated` users, with all row visibility and write permissions enforced through RLS policies.

### 2. Row Level Security (RLS) Policies
All 5 tables have RLS enabled with 15 per-operation policies applied to `authenticated`:

* **`profiles`**
  * `profiles_select_own_or_admin` (`SELECT`) — Users view their own profile; admins view all.
  * `profiles_update_admin_only` (`UPDATE`) — Only admins can modify user roles/profiles.
* **`students`**
  * `students_select_by_role` (`SELECT`), `students_insert_admin_only` (`INSERT`), `students_update_admin_only` (`UPDATE`), `students_delete_admin_only` (`DELETE`).
* **`courses`**
  * `courses_select_by_role` (`SELECT`), `courses_insert_admin_only` (`INSERT`), `courses_update_admin_only` (`UPDATE`), `courses_delete_admin_only` (`DELETE`).
* **`enrollments`**
  * `enrollments_select_by_role` (`SELECT`) — Students see their own enrollments; lecturers see enrollments for their assigned courses; admins see all.
  * `enrollments_insert_admin_only` (`INSERT`) — Only admins can enroll students.
  * `enrollments_update_admin_or_course_lecturer` (`UPDATE`) — Restricted to admins and the lecturer assigned to that course.
  * `enrollments_delete_admin_only` (`DELETE`) — Only admins can delete enrollments.
* **`audit_logs`**
  * `audit_logs_select_admin_only` (`SELECT`) — Read access restricted strictly to admins; direct client writes are blocked (`42501`).

### 3. Database Triggers (`public`)
* **Enrollment Guard Trigger** (`BEFORE UPDATE` on `enrollments`) — Blocks non-admin changes to `student_id` or `course_id` (`42501`) and records `updated_by = auth.uid()`.
* **Grade Derivation Trigger** (`BEFORE INSERT OR UPDATE` on `enrollments`) — Automatically derives letter grades (`A` 75+, `B` 60–74, `C` 50–59, `D` 40–49, `F` <40) from numeric marks.
* **Audit Logging Triggers (`AFTER INSERT OR UPDATE OR DELETE`)** — `trg_audit_courses`, `trg_audit_enrollments`, `trg_audit_profiles`, and `trg_audit_students` call `private.log_record_change()` (`SECURITY DEFINER`) to capture actor, DB role, operation, and `OLD`/`NEW` JSONB snapshots in `audit_logs`.

### 4. Standalone SQL Roles & SQL Injection Demo (`demo`)
* Separate `demo` schema (`demo.students`, `demo.courses`, `demo.enrollments`) demonstrating classic `GRANT`/`REVOKE` privileges across `demo_student`, `demo_lecturer`, and `demo_admin` without RLS.
* Contrasts `demo.search_students_unsafe()` (dynamic string concatenation) against `demo.search_students_safe()` (`EXECUTE ... USING` parameterised query).

---

## Setup & Deployment Order

1. Create a Supabase project and add the 6 synthetic test users under **Authentication → Users**.
2. Open the **SQL Editor** and execute the scripts in dependency order:
   1. `database/01_schema.sql`
   2. `database/02_rls_and_grants.sql`
   3. `database/03_audit_trigger.sql`
   4. `database/05_seed_data.sql`
   5. `database/04_roles_and_grants.sql`
3. Open `application/index.html` in a browser (or serve `application/` locally) to test role-based access using the project URL and publishable key.

---

## Seeded Test Accounts

| Role | Test Email |
| :--- | :--- |
| **Admin** | `admin@bit3360.test` |
| **Lecturer** | `lecturer1@bit3360.test`, `lecturer2@bit3360.test` |
| **Student** | `student.a@bit3360.test`, `student.b@bit3360.test`, `student.c@bit3360.test` |

---

## Known Limitations

* Row-level audit triggers log committed `INSERT`, `UPDATE`, and `DELETE` changes only; `SELECT` reads and rejected `42501` attempts are not written to `audit_logs`.
* Database owners (`postgres`) and secret `service_role` keys bypass RLS by design; security controls protect all client/API paths (`anon` and `authenticated`).
* Test accounts are provisioned beforehand in Supabase Auth so role promotion remains strictly under database-owner control.
