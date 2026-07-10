-- ============================================================
--  Lyzoo Group — Inventory & COGS
--  views.sql  ·  Supabase → SQL Editor → paste & Run (step 2 of 3)
--  Run AFTER schema.sql. All COGS math lives here so every
--  screen and report reads one identical, trustworthy number.
-- ============================================================

-- Total weight of each batch (Σ qty × sku weight)
create or replace view batch_weight as
select pl.batch_id,
       sum(pl.quantity * s.weight_g) as total_weight_g
from purchase_lines pl
join skus s on s.id = pl.sku_id
group by pl.batch_id;

-- Landed cost (GBP) for every purchase line
--   landed = (unit_price × rate) + (shipping+tax) allocated BY WEIGHT
create or replace view line_landed_cost as
select pl.id            as line_id,
       pl.batch_id,
       pl.sku_id,
       pl.quantity,
       (pl.unit_price * b.conversion_rate)                            as unit_gbp,
       ((b.shipping_gbp + b.tax_gbp)
          * (s.weight_g / nullif(bw.total_weight_g, 0)))              as add_per_unit,
       (pl.unit_price * b.conversion_rate)
          + ((b.shipping_gbp + b.tax_gbp)
             * (s.weight_g / nullif(bw.total_weight_g, 0)))           as landed_unit_gbp
from purchase_lines pl
join purchase_batches b on b.id = pl.batch_id
join skus s             on s.id = pl.sku_id
join batch_weight bw    on bw.batch_id = pl.batch_id;

-- Weighted-average cost per SKU (pools all batches): Σ(landed×qty) ÷ Σqty
create or replace view sku_avg_cost as
select sku_id,
       sum(quantity)                             as received,
       sum(landed_unit_gbp * quantity)           as total_cost_gbp,
       sum(landed_unit_gbp * quantity)
         / nullif(sum(quantity), 0)              as avg_cost_gbp
from line_landed_cost
group by sku_id;

-- Units sold per SKU (sum of additive sales rows)
create or replace view sku_sold as
select sku_id, coalesce(sum(quantity), 0) as sold
from sales group by sku_id;

-- The inventory / COGS view the app reads:
--   supabase.from('inventory_cogs').select('*')
create or replace view inventory_cogs as
select s.id                              as sku_id,
       s.sku_code,
       s.label,
       p.name                            as product,
       coalesce(ac.received, 0)          as received,
       coalesce(ss.sold, 0)              as sold,
       coalesce(ac.received,0) - coalesce(ss.sold,0)          as remaining,
       coalesce(ac.avg_cost_gbp, 0)                           as avg_cost_gbp,
       (coalesce(ac.received,0)-coalesce(ss.sold,0))
          * coalesce(ac.avg_cost_gbp,0)                       as on_hand_value_gbp,
       coalesce(ss.sold,0) * coalesce(ac.avg_cost_gbp,0)      as cogs_gbp
from skus s
join products p            on p.id = s.product_id
left join sku_avg_cost ac  on ac.sku_id = s.id
left join sku_sold ss      on ss.sku_id = s.id;

-- Dashboard analytics: sell-through, monthly velocity, months of cover.
-- per_month assumes sales accumulate over a 3-month window — change 3.0
-- to match your reporting period.
create or replace view sku_metrics as
select ic.*,
       case when ic.received > 0
            then ic.sold::numeric / ic.received else 0 end        as sell_through,
       (ic.sold::numeric / 3.0)                                   as per_month,
       case when ic.sold > 0
            then ic.remaining / (ic.sold::numeric / 3.0)
            else null end                                         as months_cover
from inventory_cogs ic;

-- Handy dashboard queries (run as needed from the app):
--   Fast movers:   select * from sku_metrics order by sold desc limit 6;
--   Slow / dead:   select *, (sold = 0) as is_dead from sku_metrics
--                    where remaining > 0 order by sell_through asc;
--   Low stock:     select * from sku_metrics
--                    where remaining > 0 and remaining < 120 order by remaining asc;
