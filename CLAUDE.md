# CLAUDE.md — Agent instructions: deploy Lyzoo Inventory & COGS

You are helping deploy a working **inventory / purchasing / COGS** web app for
**Lyzoo Group**. This folder is the whole app. Your job: get it running on
**GitHub Pages** + **Supabase**, with the database created and the app connected.

Read this whole file first. Do the numbered steps in order. **Never fabricate
secrets** (Supabase keys, tokens) — if you don't have one, stop and ask the user.

---

## What this app is (so you don't rebuild it unnecessarily)

- A **single static HTML app** (`index.html` + `support.js`) — no build step, no
  framework, no npm install. It runs by being served as static files.
- It has a **built-in Supabase integration** with two modes:
  - **Demo mode** (default): sample data + an in-app login. Active while
    `supabase-config.js` has empty `url`/`anonKey`.
  - **Live mode**: real reads/writes + Supabase Auth. Activates automatically
    once both keys are filled in.
- All COGS math (weight-allocated landed cost, weighted-average cost, sell-through,
  months-of-cover) lives in **SQL views**, not the browser. The app reads
  `inventory_cogs` and `sku_metrics`.

**Do NOT rewrite this into React/Vue/Next unless the user explicitly asks.**
Shipping it as-is is the intended, supported path. If the user does want a
framework rebuild, treat `index.html` as the design + behavior spec and preserve
the exact Supabase table/view contract in `db/`.

---

## Files

```
index.html          the app (served as the site root)
support.js          runtime the app needs — keep beside index.html
supabase-config.js  the ONLY file you edit to go live (paste keys here)
guide.html          human-readable developer guide (schema, COGS, auth, deploy)
doc-page.js         runtime for guide.html
db/schema.sql       tables + FK cascades
db/views.sql        COGS + analytics views  (run AFTER schema.sql)
db/policies.sql     Row Level Security       (run AFTER schema.sql)
```

---

## Step 1 — Ask the user for what only they can provide

Request, and wait for:
1. **GitHub**: confirm `gh` is authenticated (`gh auth status`) and the repo name
   to use (default `lyzoo`). Public repo is fine.
2. **Supabase**: they must create a project at supabase.com first. Then obtain
   EITHER:
   - a **Supabase access token** + **project ref** (lets you run the CLI), OR
   - the **Project URL** + **anon public key** (lets you at least connect the app).
3. The **login email + password** they want for the business account
   (e.g. `info@lyzoo.co.uk`).

If any is missing, do the parts you can and clearly list what you're blocked on.

---

## Step 2 — Push to GitHub + enable Pages

```bash
git init
git add .
git commit -m "Lyzoo Inventory & COGS — initial"
git branch -M main
gh repo create <owner>/<repo> --public --source=. --remote=origin --push
# Enable Pages from the main branch root:
gh api -X POST repos/<owner>/<repo>/pages -f source.branch=main -f source.path=/
```
The site will be at `https://<owner>.github.io/<repo>/`. Confirm it loads (it will
run in demo mode until Step 4).

## Step 3 — Create the database (Supabase CLI)

Install/verify the CLI (`supabase --version`). Then:
```bash
supabase login                       # uses the access token
supabase link --project-ref <ref>
# run the three SQL files IN THIS ORDER:
supabase db execute -f db/schema.sql
supabase db execute -f db/views.sql
supabase db execute -f db/policies.sql
```
(If `db execute` is unavailable in the installed CLI version, use `psql` with the
project connection string, or tell the user to paste each file into the Supabase
SQL Editor in order.) Verify with a query: `select * from inventory_cogs;` should
return 0 rows on a fresh DB — that's correct.

## Step 4 — Connect the app

Edit **supabase-config.js** only:
```js
window.LYZOO_CONFIG = {
  url: 'https://<ref>.supabase.co',
  anonKey: '<anon public key>'
};
```
Commit + push. The anon key is safe to commit **because RLS is enabled**
(policies.sql). NEVER put the `service_role` key here or anywhere in the frontend.

## Step 5 — Auth: create the login, lock down sign-ups, allow the site

- Create the user (email + password from Step 1). Via API with the access token,
  or tell the user to do Authentication → Users → Add user.
- Disable public sign-ups (Authentication → Providers → Email → Enable sign-ups OFF).
- Add the Pages URL to Authentication → URL Configuration → Site URL + Redirect URLs.

## Step 6 — Verify accuracy before declaring done

- Sign in on the deployed site with the real credentials (live mode).
- Add one product with a couple of SKUs (with weights).
- Log one purchase batch (qty + unit price + shipping + tax + rate).
- Open the SQL editor and confirm `select * from inventory_cogs;` landed/avg cost
  matches the app, and matches a hand calc:
  `landed_unit = unit_price*rate + (shipping+tax) * (sku_weight / total_batch_weight)`.
- Record a sale and confirm COGS = sold × weighted-average cost updates.

---

## Guardrails
- Don't invent keys, tokens, or passwords. Ask.
- Don't commit the `service_role` key or any secret other than the anon key.
- Don't change the table/column/view names in `db/` — the app depends on them
  (`inventory_cogs`, `sku_metrics`, `sku_code`, `weight_g`, `conversion_rate`,
  `shipping_gbp`, `tax_gbp`, additive `sales` rows, etc.).
- Keep `index.html` and `support.js` together at the served root.
- The COGS contract: shipping **and** tax are pooled per batch and allocated **by
  weight**; USD converts to GBP at the batch's `conversion_rate`; inventory pools
  batches with a **weighted average**. Preserve this exactly.
