# Organization Workbench: Groups → Orgs → Documents drill-down

Built directly in the repo (not a wizard-build guide anymore):

- **Page 954 — Organization Form**: full CRUD on `HR_ORGS`, every column,
  organized into three panels (Basic Info, Trade License & Government IDs,
  Address & Contact), with cascading country → city LOVs, an Org Code
  uniqueness check, and a Trade License expiry-date-order validation.
  Modal dialog, matches the automatic-DML pattern (safer than hand-written
  INSERT/UPDATE — same mechanism your existing modal forms like the Bike
  Document Form use).
- **Page 955 — Org Document Form**: full CRUD on `HR_ORG_DOCS`, modal
  dialog, same automatic-DML pattern, with a document-type LOV, a date-order
  validation, and an overlap-check validation (mirrors the Bike Document
  Form's own overlap check).
- **Page 953 — Organization Workbench** (repurposed): three cascading
  Interactive Report regions — Groups → Organizations (filtered by selected
  group) → Documents (filtered by selected org) — using the same same-page
  link pattern (`apex_page.get_url`) used throughout the rest of the app.
  "Add Organization" / "Add Document" buttons open the two modal forms
  above, pre-filled with the selected group/org. A dynamic action refreshes
  the page when either modal closes (same pattern as the Insurance
  Dashboard's document-dialog refresh).

Group management itself isn't duplicated here — the Groups region links out
to the existing page 951 ("Manage Groups") for actual group CRUD, since that
page already works.

## How to get this into your live app

These are hand-written YAML files in the split/readable export format, not
built through Page Designer's wizard — so they need to go in via **SQLcl's
`apex import`**, not App Builder's manual page import (which expects the old
single-file format).

```
sql /nolog
SQLcl> set cloudconfig /path/to/wallet.zip
SQLcl> connect <schema_user>/<password>@<db>_high

SQLcl> apex import --applicationid 100 /path/to/apex/application
```

Point it at the `apex/application` folder from this repo (the one
containing `application/f100.yaml`, `application/pages/`, etc.) — SQLcl
reads the whole split structure and re-imports it as Application 100.

**Before running this**: pull the latest from the repo so you have
`p00953.yaml`, `p00954.yaml`, `p00955.yaml` locally, and back up your
current app first (Export Application from App Builder) in case anything
about the import needs rolling back — this is new territory (a hand-authored
page import) even though every field/pattern in it was modeled on your
existing, working pages.

## After importing

1. Open page 953. It should show three sections top to bottom: Groups,
   Organizations (empty until a group is selected), Documents (empty until
   an org is selected).
2. Click a group → Organizations should populate, filtered to that group.
3. Click an org → Documents should populate, filtered to that org.
4. "Add Organization" and "Add Document" buttons should open modal forms.
5. Try creating one of each — confirm validations fire correctly (e.g. try
   an Org Code that already exists, or an expiry date before the issue
   date), and that the workbench refreshes after the modal closes.

If import fails or a page behaves unexpectedly, send me the exact error —
since this is hand-authored rather than wizard-generated, that's the most
likely place something could still be off, and a specific error is much
easier to fix than a general "it didn't work."
