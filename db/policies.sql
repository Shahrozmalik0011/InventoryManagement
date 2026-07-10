-- ============================================================
--  Lyzoo Group — Inventory & COGS
--  policies.sql  ·  Supabase → SQL Editor → paste & Run (step 3 of 3)
--  Row Level Security: without this, the public anon key could
--  read/write your data. With it, only a logged-in session can.
-- ============================================================

alter table products         enable row level security;
alter table skus             enable row level security;
alter table purchase_batches enable row level security;
alter table purchase_lines   enable row level security;
alter table sales            enable row level security;

-- Any authenticated user of this business may read + write.
-- Repeat the two policies for every table.

-- products
create policy "auth read"  on products for select
  using (auth.role() = 'authenticated');
create policy "auth write" on products for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- skus
create policy "auth read"  on skus for select
  using (auth.role() = 'authenticated');
create policy "auth write" on skus for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- purchase_batches
create policy "auth read"  on purchase_batches for select
  using (auth.role() = 'authenticated');
create policy "auth write" on purchase_batches for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- purchase_lines
create policy "auth read"  on purchase_lines for select
  using (auth.role() = 'authenticated');
create policy "auth write" on purchase_lines for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- sales
create policy "auth read"  on sales for select
  using (auth.role() = 'authenticated');
create policy "auth write" on sales for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- Later, for staff roles: add a `role` column to a `profiles` table and
-- change the write policy to:  using (auth.jwt() ->> 'role' = 'admin')
