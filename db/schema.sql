-- ============================================================
--  Lyzoo Group — Inventory & COGS
--  schema.sql  ·  Supabase → SQL Editor → paste & Run (step 1 of 3)
-- ============================================================
create extension if not exists "pgcrypto";

-- Products (e.g. "USB Flash Drive")
create table products (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  created_at  timestamptz default now()
);

-- SKUs: the trackable unit. Weight is required (drives COGS).
create table skus (
  id          uuid primary key default gen_random_uuid(),
  product_id  uuid not null references products(id) on delete cascade,
  sku_code    text not null unique,
  label       text,                       -- optional variant label
  weight_g    numeric(10,2) not null check (weight_g > 0),
  created_at  timestamptz default now()
);

-- Purchase batches (one PO / import shipment)
create table purchase_batches (
  id               uuid primary key default gen_random_uuid(),
  po_number        text not null unique,
  product_id       uuid references products(id),
  supplier         text,
  origin           text not null default 'China',   -- 'China' | 'UK'
  currency         text not null default 'USD',      -- 'USD' | 'GBP'
  conversion_rate  numeric(12,4) not null default 1, -- source -> GBP
  shipping_gbp     numeric(12,2) not null default 0,
  tax_gbp          numeric(12,2) not null default 0,
  purchased_on     date not null default current_date,
  created_at       timestamptz default now()
);

-- Line items within a batch.
-- ON DELETE CASCADE on sku_id so deleting a SKU cleans up its lines
-- (matches the app's cleanup behaviour).
create table purchase_lines (
  id          uuid primary key default gen_random_uuid(),
  batch_id    uuid not null references purchase_batches(id) on delete cascade,
  sku_id      uuid not null references skus(id) on delete cascade,
  quantity    integer not null check (quantity > 0),
  unit_price  numeric(12,4) not null check (unit_price >= 0)  -- in batch currency
);

-- Sales: additive. Each row is "units sold in this period".
create table sales (
  id          uuid primary key default gen_random_uuid(),
  sku_id      uuid not null references skus(id) on delete cascade,
  quantity    integer not null check (quantity > 0),
  sold_on     date not null default current_date,
  created_at  timestamptz default now()
);

create index on skus(product_id);
create index on purchase_lines(batch_id);
create index on purchase_lines(sku_id);
create index on sales(sku_id);
