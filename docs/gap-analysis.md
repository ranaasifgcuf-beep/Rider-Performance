# Application gap analysis

Reviewed: all 21 packages (73 procedures/functions), all 115 APEX pages, full
data model, and cross-checked against what a complete HRMS + Payroll + Fleet
system needs. Findings below, most important first.

## 1. Payroll — no calculation engine (the biggest gap)

The app's own name is "HRMS & Payroll," but there's no payroll run/payslip
engine anywhere in the schema or packages. What exists instead:

- `HR_EMP_LEGAL_PROFILE.WPS_CONTRACT_SALARY` / `WPS_SALARY_AMOUNT` — a single
  static salary figure per employee, not a salary structure (basic +
  allowances + deductions breakdown)
- `HR_EMP_CHARGES` — has `PAYROLL_DEDUCTION_CODE` and `PAYROLL_PROCESSED_YN`
  columns, which strongly suggests the schema was **designed to feed an
  external or future payroll process**, but nothing currently reads or
  processes those flags
- `HR_EMP_LOAN` — loan deductions, same story: tracked, but not tied to a
  payroll run
- No payslip table, no payroll-run/batch table, no salary-structure table
  (basic/HRA/allowances), no tax or statutory-deduction calculation, no WPS
  SIF file generation (the actual bank file UAE WPS requires — you have the
  status fields for it, `WPS_STATUS` with `SETUP_PENDING`/`ACTIVE`/etc., but
  no code that produces the file)

**How to cover it:** this is a real module to design, not a small patch.
Minimum shape:
- `HR_PAYROLL_RUNS` (period, status, run date)
- `HR_PAYROLL_LINES` (per employee per run: basic, allowances, deductions
  pulled from `HR_EMP_CHARGES`/`HR_EMP_LOAN`, net pay)
- A `hr_payroll_pkg` that: opens a run for a period → pulls active
  employees + their salary + unprocessed charges/loan installments →
  calculates net → marks `PAYROLL_PROCESSED_YN='Y'` on consumed charges →
  produces a WPS SIF-format output
- Decide early: will tax/EOBI/social-insurance rules be config-driven
  (a rates/rules table) or hardcoded? Config-driven is worth the extra
  setup effort — rate changes shouldn't need a redeploy.

## 2. Leave & Attendance — completely absent

No tables, no packages, nothing. This matters because a real payroll engine
usually needs attendance/leave data to calculate unpaid leave deductions,
overtime, etc. If payroll is being built next, decide whether leave/
attendance needs to exist first, or whether payroll will initially assume
full attendance (simpler, but limits accuracy).

## 3. Audit trail is built but never used

`SEC_AUDIT_LOG` table and `sec_pkg.audit()` procedure both exist — but a
repo-wide search found **zero calls** to `sec_pkg.audit()` from any business
package (`fleet_pkg`, `hr_emp_pkg`, `hr_charges_pkg`, etc.). The
infrastructure is there; nothing populates it. Right now, if a bike gets
reassigned or an employee's salary changes, there's no audit trail of who
did it or when — beyond the generic `UPDATED_BY`/`UPDATED_DT` columns on
each table, which don't capture *what* changed, only *that* something did.

**How to cover it:** add `sec_pkg.audit(...)` calls at the key mutation
points in each package — bike status/custody changes, employee status
changes, charge/loan approvals, legal status changes. Prioritize by
compliance sensitivity: legal status and WPS/salary changes first.

## 4. Authorization is enforced only at the UI layer

`sec_pkg.has_perm()`, `is_org_allowed()`, `is_project_allowed()` are called
extensively from APEX **Authorization Schemes** (declarative, page/button-
level) — confirmed in `shared_components/authorizations.yaml`. But grepping
every package body, **none of them call these checks internally**. That
means `fleet_pkg.assign_bike()`, `hr_charges_pkg.create_charge()`, etc. will
execute for *anyone* who can call them — the permission gate exists only in
the APEX pages that route to them.

This is fine as long as APEX is the only way anything reaches these
packages. It becomes a real gap the moment there's any other entry point —
an ORDS REST API exposed on top of these packages, a future integration, or
even another APEX app in the same workspace calling them directly. Worth
knowing now rather than discovering it after such an integration ships.

**How to cover it:** not urgent today, but before exposing any of this
outside APEX (REST API, another app), add permission checks inside the
packages themselves — defense in depth, not just UI gating.

## 5. What's genuinely solid

Worth naming, since it's easy to only list problems:
- **Fleet/BIE and SIM Assignment** are thorough — request → approval →
  assignment → return/close lifecycle, with custody tracking, accidents,
  impounds, and document expiry all modeled. This matches (and exceeds) what
  the original brief asked for.
- **Approval workflow** (`hr_approval_wf_pkg`) is genuinely generic —
  reusable across loans, PRO deals, bike/SIM requests, not hardcoded per
  module.
- **Legal/compliance tracking** (Emirates ID, visa, labour card, work
  permit, insurance) with an expiry dashboard is a real strength for a UAE
  operation — this is often bolted on late in similar systems, and it's
  already there.
- No dynamic SQL (`EXECUTE IMMEDIATE`) anywhere in the packages reviewed —
  no SQL-injection surface from that angle.
- Password hashing uses `DBMS_CRYPTO` with per-user salt, not a weak/home-
  rolled scheme.

## Suggested priority order

1. Decide payroll's scope and design the run/line/salary-structure tables —
   this is the one gap that matches the app's own name and is the largest
   remaining piece of work.
2. Wire up `sec_pkg.audit()` in the highest-compliance-risk packages (legal
   status, WPS/salary, approvals) — small effort, meaningful traceability
   gain.
3. Leave/attendance — only if payroll needs it for accurate calculation;
   otherwise can follow later.
4. Package-level authorization hardening — before any non-APEX consumer of
   these packages exists, not before.
