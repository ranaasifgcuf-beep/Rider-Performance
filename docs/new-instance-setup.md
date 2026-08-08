# Setting up ALNAJAH_DEV (new Transaction Processing instance)

## 1. Provision the database

OCI Console → Create Autonomous Database:
- Workload type: **Transaction Processing** (not APEX — this is what unlocks
  wallet/mTLS and the full feature set the APEX-workload instance lacked)
- Always Free: checked (still development)

## 2. Deploy the schema structure

Run `scripts/deploy_phase1_structure.sql` in the new instance's Database Actions
SQL Worksheet, in **Script mode** (not the regular statement runner) — it's a
single ordered script: sequences → tables → indexes → views.

This is **Phase 1 only** — structure for the tables/views/indexes/sequences
that were captured in the latest export. It does **not** yet include:
- Triggers (33 in the previous export — audit timestamp triggers etc.)
- Packages (20 — this is where the actual business logic lives:
  `fleet_pkg`, `hr_asg_pkg`, `hr_approval_wf_pkg`, `sec_auth_pkg`, etc.)
- Functions (2, including `apex_auth_fn` — the APEX authentication function)
- Foreign keys (72 — referential integrity between tables)

**The app will not function correctly on Phase 1 alone** — no login (auth
function missing), no business logic, no FK protection. Phase 2 needs a full
`Generate DDL` re-export from APEX SQL Workshop with **all** object types
checked: Tables, Views, Packages, Triggers, Sequences, Indexes, Functions,
Procedures, Types — not just the default Tables/Views/Indexes/Sequences
selection.

## 3. Configure APEX on the new instance

1. Database Actions → **App Builder** (or the direct APEX URL for the new
   instance) → sign in as ADMIN (first time).
2. Create a **Workspace** if one doesn't exist yet — associate it with your
   schema (e.g. `WKSP_ALNAJAH` to match the original, or a new name).
3. Inside the workspace: **App Builder → Import** → upload the app export
   (from `apex/application/`, or the original zip) → Install.
4. During import, confirm the **parsing schema** matches the schema you just
   deployed the structure into (step 2).
5. Run the app, expect it to fail at login/business-logic points until Phase 2
   (packages/functions) is deployed — that's expected, not a setup error.

## 4. Once Phase 2 DDL is available

Deploy in this order (dependencies matter):
1. Foreign keys (needs tables to exist first — already does)
2. Package **specs** (`.pks`) before package **bodies** (`.pkb`) — a body
   can't compile without its spec existing first
3. Functions
4. Triggers

Then re-test the app end to end: login, a few CRUD screens per module,
SIM assignment flow specifically since it's the newest addition.
