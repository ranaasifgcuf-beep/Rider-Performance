# Rider-Performance — HRMS & Payroll (Oracle Cloud)

Standalone Oracle APEX HRMS & Payroll system (Oracle Autonomous Database), built
in-house — no Oracle Fusion HCM integration. This app is the system of record
for employee data, assignments, fleet (bike) management, and payroll.

## Current inventory (imported 2026-08-06)

- **66 tables**, **186 indexes**, **72 foreign keys**, **33 triggers**, **16 views**,
  **3 sequences**, **20 packages** (spec + body), **2 standalone functions**
- **APEX Application 100**, 115 pages

## Modules observed in the schema

- **HR / Employee Profile** (`HR_EMPLOYEES`, `HR_EMP_DOCS`) — employee master data,
  documents
- **HR Legal / Compliance** (`HR_EMP_LEGAL_PROFILE`, `HR_EMP_LEGAL_STATUS_HIST`) —
  Emirates ID, passport, visa, labour card, work permit tracking, plus WPS
  (Wage Protection System) fields — UAE-specific compliance
- **Project / Assignment** (`HR_ASG_PKG`, `HR_PROJECTS`) — assigning employees to
  projects/orgs
- **Fleet / BIE (Bike Issuance/Equipment)** (`FLEET_BIKES`, `FLEET_BIKE_ASSIGNMENTS`,
  `FLEET_BIKE_DOCS`, `FLEET_BIKE_ACCIDENTS`, `FLEET_BIKE_CUSTODY_TXNS`,
  `FLEET_BIKE_IMPOUNDS`, `FLEET_BIKE_STATUS_TXNS`) — bike lifecycle: assignment,
  custody, documents (Mulkiya/insurance), accidents, impounds, status history
- **Finance** (`FIN_SUPPLIERS`, `HR_EMP_LOAN`, `HR_EMP_CHARGES`) — supplier records,
  employee loans/installments, charges
- **Security / RBAC** (`SEC_USERS`, `SEC_ROLES`, `SEC_PERMS`, `SEC_MODULES`,
  `SEC_MENU`, `SEC_USER_ORGS`, `SEC_USER_PROJECTS`, `SEC_AUDIT_LOG`) — users, roles,
  permissions scoped by org/project, audit logging
- **Approval workflow** (`HR_APPROVAL_WF_PKG`, `HR_APPROVAL_UI_PKG`,
  `HR_APPROVAL_RULES`, `HR_APPR_RULE_STEPS`) — configurable approval chains
- **SIM Assignment** — not yet found in this import; flag if it lives in a
  different schema/app

> No dedicated Payroll calculation package spotted yet in this import
  (`HR_CHARGES_PKG` handles charges/deductions, not full payroll runs) — worth
  confirming where payroll processing actually lives before go-live.

## Repo structure

```
apex/application/     APEX Application 100 export, split YAML format (115 pages)
db/tables/             66 tables, one file per table
db/indexes/            186 indexes, one file per index
db/constraints/         Foreign keys, one file per table (FKs deduped from source)
db/triggers/            33 triggers
db/views/               16 views
db/sequences/           3 sequences
db/packages/            20 packages — <name>.pks (spec) + <name>.pkb (body)
db/functions/           2 standalone functions
integration/            External integrations (bank/payment disbursement, SMS/notify), if any
docs/                   Architecture & data model notes
scripts/                One-off deploy/setup scripts
```

Note: the DDL source export had each object triplicated (same CREATE statement
repeated ~3x at different points in the file, likely from overlapping category
selections in APEX's Generate DDL wizard) — this was deduplicated during import,
keeping one copy per object.

## Getting your APEX app into git (important)

Do **not** commit the single-file `f<app_id>.sql` export — it's unreadable in diffs
and merge conflicts become unresolvable. Use the **split** YAML export instead
(APEX Generate DDL / App Builder export → "Split" or "readable" format) — that's
what's under `apex/application/` now.

## Getting custom DB objects into git

Export DDL per object (SQL Workshop → Utilities → Generate DDL, or
`dbms_metadata.get_ddl`) and drop one file per object into the matching `db/`
subfolder — this keeps history and reviews sane per-object instead of one giant dump.

## Workflow from here

1. Data (actual rows) hasn't been imported yet — schema/structure only so far.
2. Each addition gets reviewed for: data model soundness (employee/project/BIE/SIM
   relationships), payroll calculation correctness and auditability, RBAC
   correctness (org/project-scoped permissions), and standard APEX/PL-SQL practices
   (bind variables, authorization schemes, session state protection).
3. Confirm where SIM assignment and full payroll processing live — not visible in
   this import.
