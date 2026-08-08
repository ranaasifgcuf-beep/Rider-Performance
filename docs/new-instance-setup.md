# Setting up ALNAJAH_DEV (new Transaction Processing instance)

## 1. Provision the database

OCI Console → Create Autonomous Database:
- Workload type: **Transaction Processing** (not APEX — this is what unlocks
  wallet/mTLS and the full feature set the APEX-workload instance lacked)
- Always Free: checked (still development)

## 2. Deploy the full schema structure

Run `scripts/deploy_full.sql` in the new instance's Database Actions SQL
Worksheet, in **Script mode** (not the regular statement runner). It's one
ordered script, generated straight from `db/`, covering everything:

1. Sequences
2. Tables
3. Indexes
4. Foreign keys
5. Views
6. Package specs (`.pks`)
7. Package bodies (`.pkb`) — run after all specs, since a body can't compile
   without its spec existing first
8. Functions
9. Triggers

This is current as of the 2026-08-08 full export (73 tables, 207 indexes,
45 FK files, 20 views, 21 packages, 2 functions, 38 triggers) — includes the
SIM Assignment module (`hr_sim_req_pkg`, 5 SIM triggers, 5 SIM FK sets) that
was missing from the first pass.

**Before running:** check the schema-qualified references inside packages
and functions (e.g. `apex_auth_fn` calls `wksp_alnajah.sec_auth_pkg.authenticate`)
— if your new schema is named differently than `wksp_alnajah`, these need
updating or the calls will fail to resolve.

**Data (actual rows) is not included** — this is structure only. Use the
per-table `SELECT * FROM table` → Download-as-Insert approach if you need to
carry over existing data, run after this script.

## 3. Configure APEX on the new instance

1. Database Actions → **App Builder** (or the direct APEX URL for the new
   instance) → sign in as ADMIN (first time).
2. Create a **Workspace** if one doesn't exist yet — associate it with your
   schema (e.g. `WKSP_ALNAJAH` to match the original, or a new name — see the
   schema-name caveat above if you pick something different).
3. Inside the workspace: **App Builder → Import** → upload the app export
   (from `apex/application/`, or the original zip) → Install.
4. During import, confirm the **parsing schema** matches the schema you just
   deployed the structure into (step 2).

## 4. Verify

Run the app end to end: login (exercises `apex_auth_fn` → `sec_auth_pkg`), a
few CRUD screens per module, and the SIM assignment flow specifically since
it's the newest addition and least tested so far.
