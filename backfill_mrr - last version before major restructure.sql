-- One row per (customer, billed month, product)
-- This is before the chain logic.
DROP TABLE tmp_data_dm.coe_jrr_customer_billed_months;
CREATE TABLE tmp_data_dm.coe_jrr_customer_billed_months AS
-- , customer_market as
-- (
  SELECT
     od.customer_id
    ,od.year_month
    ,od.year_month_begin_date
    -- , od.ad_market_id
    ,od.product_line_id
    ,od.ad_type
    ,SUM(od.mrr) AS mrr
    ,SUM(od.block_count) AS block_count
    ,SUM(od.order_line_net_price_amount_usd) AS revenue
  FROM
  (
    -- This is the part I will have to replicate for older data
    -- where subscription not available.
    -- Probably even have 3 sections.
    -- This logic is >= 201510
    -- select distinct o.customer_id
      SELECT
         ord.customer_id
        -- , om.ad_market_id
        ,ord.product_subscription_id
        ,ord.product_line_id
        -- , case when ord.product_line_id=7 then 'Sponsored Listing' else 'Display' end as ad_type
        ,CASE WHEN ord.product_line_id=7 THEN 'Sponsored Listing'
               WHEN ord.product_line_id=2 THEN 'Display'
               ELSE 'Not Ad' END AS ad_type  -- LOOK check if there is a third id for ads.  Prob. not historically.
        -- , cast(concat(cast(year(ord.order_line_begin_date) as string), lpad(cast(month(ord.order_line_begin_date) as string),2,'0')) as int) as year_month
        -- ,CAST(from_unixtime(unix_timestamp(CAST(ord.order_line_begin_date AS TIMESTAMP)), 'yyyyMM') AS INT) AS year_month
        ,dt.year_month
        ,dt.month_begin_date AS year_month_begin_date
        ,SUM(COALESCE(mrr.mrr_actual_value,0)) AS mrr
        ,SUM(ord.block_count) AS block_count
        ,SUM(ord.order_line_net_price_amount_usd) AS order_line_net_price_amount_usd
      FROM         dm.order_line_accumulation_fact ord
        INNER JOIN dm.date_dim dt ON ord.order_line_begin_date = dt.actual_date
      -- join dm.order_line_ad_market_fact om on om.order_line_number = ord.order_line_number
      LEFT JOIN dm.mrr_subscription mrr ON mrr.subscription_id = ord.product_subscription_id 
            -- AND mrr.yearmonth=cast(concat(cast(year(ord.order_line_begin_date) as string), lpad(cast(month(ord.order_line_begin_date) as string),2,'0')) as int)
            AND mrr.yearmonth = CAST(from_unixtime(unix_timestamp(CAST(ord.order_line_begin_date AS TIMESTAMP)), 'yyyyMM') AS INT)
      WHERE ord.product_line_id in (2,7)  -- LOOK lose this later.
        AND ord.order_line_begin_date>='2015-10-01'
        AND ord.order_line_payment_date!='1900-01-01'
        AND ord.order_line_payment_date!='-1'  -- LOOK this needs to change.
        GROUP BY 1,2,3,4,5,6
  UNION ALL
      SELECT
         ord.customer_id
        ,ord.product_subscription_id
        ,ord.product_line_id
        -- , case when ord.product_line_id=7 then 'Sponsored Listing' else 'Display' end as ad_type
        ,CASE WHEN ord.product_line_id = 7 THEN 'Sponsored Listing'
              WHEN ord.product_line_id = 2 THEN 'Display'
              ELSE 'Not Ad' END AS ad_type  -- LOOK check if there is a third id for ads.  Prob. not historically.
        -- , cast(concat(cast(year(ord.order_line_begin_date) as string), lpad(cast(month(ord.order_line_begin_date) as string),2,'0')) as int) as year_month
        -- ,CAST(from_unixtime(unix_timestamp(CAST(ord.order_line_begin_date AS TIMESTAMP)), 'yyyyMM') AS INT) AS year_month
        ,dt.year_month
        ,dt.month_begin_date AS year_month_begin_date
        ,SUM(100) as mrr  -- LOOK obviously wrong.
        ,SUM(ord.block_count) AS block_count
        ,SUM(ord.order_line_net_price_amount_usd) AS order_line_net_price_amount_usd
      FROM         dm.order_line_accumulation_fact ord
        INNER JOIN dm.date_dim dt ON ord.order_line_begin_date = dt.actual_date
      -- join dm.order_line_ad_market_fact om on om.order_line_number = o.order_line_number
      -- left join dm.mrr_subscription mrr on mrr.subscription_id = o.product_subscription_id 
      --       and mrr.yearmonth=cast(concat(cast(year(o.order_line_begin_date) as string), lpad(cast(month(o.order_line_begin_date) as string),2,'0')) as int)
      WHERE ord.product_line_id in (2,7)  -- LOOK lose this later.
        AND ord.order_line_begin_date BETWEEN '2013-01-01' AND '2015-09-30'
        AND ord.order_line_payment_date!='1900-01-01'
        AND ord.order_line_payment_date!='-1'
        GROUP BY 1,2,3,4,5,6
  ) od
  -- join 
  --   (  -- this is filter to promo markets
  --     select distinct ad_market_id, ad_type from promo_market
  -- ) pm on pm.ad_market_id = od.ad_market_id and pm.ad_type = od.ad_type
  GROUP BY 1,2,3,4,5
-- )

DROP TABLE tmp_data_dm.coe_jrr_customer_lifetime_start;
CREATE TABLE tmp_data_dm.coe_jrr_customer_lifetime_start AS
-- with start_month as 
-- (
  SELECT ord.customer_id
    -- , om.ad_market_id
    -- , min(cast(concat(cast(year(order_line_begin_date) as string), lpad(cast(month(order_line_begin_date) as string),2,'0')) as int)) as start_month
    -- ,MIN(CAST(from_unixtime(unix_timestamp(CAST(ord.order_line_begin_date AS TIMESTAMP)), 'yyyyMM') AS INT)) AS start_month
    ,MIN(dt.year_month) AS        start_month
    ,MIN(dt.month_begin_date) AS  start_month_begin_date
  FROM         dm.order_line_accumulation_fact ord
    INNER JOIN dm.date_dim dt ON ord.order_line_begin_date = dt.actual_date
  -- join dm.order_line_ad_market_fact om on om.order_line_number = o.order_line_number
  WHERE ord.order_line_payment_date NOT IN ('-1', '1900-01-01') 
    AND ord.product_line_id in (2,7)  -- LOOK this is ads only.  Damn.  Keep it for now so I can reconcile.
    -- We do not look back further than this to detect returned customers.
    --                                                                    LOOK change to new defn of active.
    AND ord.order_line_begin_date >= '2013-01-01'
  GROUP BY 1
-- )

-- Identify cohort for each customer
-- One row per customer per product_line_id.
-- This puts the first-billed month rows into their own table.
DROP TABLE tmp_data_dm.coe_jrr_customer_start_month;
CREATE TABLE tmp_data_dm.coe_jrr_customer_start_month AS
-- , new_customer as
-- (
  SELECT
     cm.customer_id
    ,sm.start_month
    ,sm.start_month_begin_date
    ,cm.product_line_id
    ,cm.ad_type
    ,cm.mrr
    ,cm.block_count
    ,cm.revenue
  FROM       tmp_data_dm.coe_jrr_customer_billed_months cm
  INNER JOIN tmp_data_dm.coe_jrr_customer_lifetime_start sm  -- LOOK may not work to do this any more - think I need every chain start.
    ON sm.start_month = cm.year_month 
   AND sm.customer_id = cm.customer_id 
   -- and sm.ad_market_id = cm.ad_market_id
  -- -- lose join to promo market
  -- join promo_market pm on pm.promo_month = cm.year_month and pm.ad_market_id = cm.ad_market_id and pm.ad_type = cm.ad_type
-- )

-- Get the beginning values (counts and mrr) for each cohort
DROP TABLE tmp_data_dm.coe_jrr_cohort_active_customer;
CREATE TABLE tmp_data_dm.coe_jrr_cohort_active_customer AS
-- , cohort_active_customer as
-- (
  SELECT
     start_month
    ,start_month_begin_date
    -- , ad_market_id  -- can take this out and then I don''t need it later either.
    -- , ad_type
    , SUM(mrr) AS mrr
    , SUM(block_count) AS block_count
    , COUNT(DISTINCT customer_id) AS customers
    , SUM(revenue) AS revenue
  FROM tmp_data_dm.coe_jrr_customer_start_month
  GROUP BY 1,2
-- )

-- Strange characteristic of this table is that a customer's first
-- unbroken chain of months will always have chain_id = 1.
DROP TABLE tmp_data_dm.coe_jrr_cust_chains;
CREATE TABLE tmp_data_dm.coe_jrr_cust_chains AS
SELECT
   chn.customer_id
  ,chn.start_month
  ,chn.start_month_begin_date
  -- , chn.ad_market_id  -- comment out
  -- , chn.ad_type
  ,chn.tenure_month
  ,chn.year_month
  ,chn.year_month_begin_date
  ,chn.mrr
  ,chn.block_count
  ,chn.revenue
  ,DENSE_RANK() OVER(PARTITION BY chn.customer_id
                         ORDER BY chn.tenure_month) AS rnk
  ,DENSE_RANK() OVER(PARTITION BY chn.customer_id
                         ORDER BY chn.tenure_month) - chn.tenure_month AS chain_id
FROM
  (
  SELECT
     nc.customer_id
    ,nc.start_month
    ,nc.start_month_begin_date
    -- , nc.ad_market_id  -- comment out
    -- , nc.ad_type
    ,(FLOOR(future.year_month/100)-FLOOR(nc.start_month/100)) * 12 +
           (future.year_month%100-       nc.start_month%100) AS tenure_month
    ,future.year_month
    ,future.year_month_begin_date
    ,future.mrr
    ,future.block_count
    ,future.revenue
  FROM tmp_data_dm.coe_jrr_customer_start_month nc
  LEFT JOIN tmp_data_dm.coe_jrr_customer_billed_months future 
         ON nc.customer_id = future.customer_id 
        AND nc.start_month <= future.year_month 
        -- and nc.ad_market_id = future.ad_market_id 
        -- AND nc.ad_type = future.ad_type 
        AND future.year_month < 201610
  ) chn

-- Join from cohort start table to every month that the customer got billed in.
-- This is the main query.
-- I will have to change this a bunch because I want customer_id.
-- OK for now I am commenting out ad type because I need to see if I
-- can make the numbers match.  Later when this is at the customer
-- level, I will put a bunch of stuff back in.
DROP TABLE tmp_data_dm.coe_jrr_cohort_months;
CREATE TABLE tmp_data_dm.coe_jrr_cohort_months AS
-- , temp as
-- (
-- SELECT
--    chn.start_month
--   ,chn.tenure_month
--   ,chn.year_month
--   -- , chn.ad_market_id  -- comment out
--   -- , chn.ad_type
--   ,chn.new_mrr
--   ,chn.new_block_count
--   ,chn.new_customers
--   ,chn.retained_customers
--   ,chn.retained_mrr
--   ,chn.retained_block_count
--   ,chn.new_revenue
--   ,chn.retained_revenue
--   -- , chn.retention_customer
--   FROM
--   (
  SELECT
     x.start_month
    ,CONCAT('M',LPAD(CAST(x.tenure_month AS string),2,'0')) AS tenure_month  -- M1, M2, ...
    ,x.year_month
    -- , x.ad_market_id  -- comment out
    -- , x.ad_type
    ,x.new_mrr
    ,x.new_block_count
    ,x.new_customers
    ,x.retained_customers
    ,x.retained_mrr
    ,x.retained_block_count
    ,x.new_revenue
    ,x.retained_revenue
    -- , x.retention_customer
  FROM
    (
      SELECT
         chn.start_month
        ,chn.start_month_begin_date
        -- , nc.ad_market_id  -- comment out
        -- , nc.ad_type
        ,chn.tenure_month
        ,chn.year_month
        ,chn.year_month_begin_date
        -- maybe don''t have to do these because I have them in cac - then i could just union?  think I am ok.
        ,MAX(cac.mrr) AS             new_mrr  -- only reason for max is they are always same value and we want to just grab 1.
        ,MAX(cac.block_count) AS     new_block_count
        ,MAX(cac.customers) AS  new_customers
        ,MAX(cac.revenue) AS         new_revenue
        ,COUNT(DISTINCT chn.customer_id) AS retained_customers
        ,SUM(chn.mrr) AS          retained_mrr
        ,SUM(chn.block_count) AS  retained_block_count
        ,SUM(chn.revenue) AS      retained_revenue
      FROM tmp_data_dm.coe_jrr_cust_chains chn
      LEFT JOIN tmp_data_dm.coe_jrr_cohort_active_customer cac 
             ON chn.start_month = cac.start_month 
      WHERE chn.chain_id = 1
            -- and cac.ad_market_id= nc.ad_market_id 
            -- AND cac.ad_type = nc.ad_type
      GROUP BY 1,2,3,4,5
    ) x
    WHERE x.tenure_month IS NOT NULL 
  -- ) chn
-- WHERE chn.chain_id = 1
-- )

-- This reshapes things,
-- and fills in months if the prior query has lost all the customers
-- as of a certain month, but we still want 0 rows in the results so 
-- it looks right (and rolls up right).
-- Probably don''t even need this if I am producing output for every customer.
-- This just shows new and retained.
-- She calculates churned in tableau.
DROP TABLE tmp_data_dm.coe_jrr_final;
CREATE TABLE tmp_data_dm.coe_jrr_final AS
SELECT zz.* 
  -- , amd.ad_market_state_name as ad_state
  -- , amd.ad_market_region_name as ad_region
  -- , amd.ad_market_county_name as ad_county
  -- , amd.ad_market_specialty_name as specialty
FROM
(
  -- select z.start_month
  --   , z.period
  --   , z.year_month
  --   , z.ad_market_id
  --   , first_value(z.new_customers) over (partition by z.start_month, z.ad_market_id order by z.period) as new_customers
  --   , z.retained_customers
  --   , first_value(z.new_mrr) over (partition by z.start_month, z.ad_market_id order by z.period) as new_mrr
  --   , z.retained_mrr
  --   , first_value(z.new_block_count) over (partition by z.start_month, z.ad_market_id order by z.period) as new_block_count
  --   , z.retained_block_count
  --   , first_value(z.new_revenue) over (partition by z.start_month, z.ad_market_id order by z.period) as new_revenue
  --   , z.retained_revenue
  SELECT z.start_month
    , z.tenure_month
    , z.year_month
    , FIRST_VALUE(z.new_customers) OVER (PARTITION BY z.start_month ORDER BY z.tenure_month) AS new_customers
    , z.retained_customers
    , FIRST_VALUE(z.new_mrr)            OVER (PARTITION BY z.start_month ORDER BY z.tenure_month) AS new_mrr
    , z.retained_mrr
    , FIRST_VALUE(z.new_block_count)    OVER (PARTITION BY z.start_month ORDER BY z.tenure_month) AS new_block_count
    , z.retained_block_count
    , FIRST_VALUE(z.new_revenue)        OVER (PARTITION BY z.start_month ORDER BY z.tenure_month) AS new_revenue
    , z.retained_revenue
  FROM
  (
    SELECT y.start_month
      , y.tenure_month
      , y.year_month
      -- , y.ad_market_id
      , SUM(y.new_customers) AS new_customers
      , SUM(y.retained_customers) AS retained_customers
      , SUM(y.new_mrr) AS new_mrr
      , SUM(y.new_block_count) AS new_block_count
      , SUM(y.retained_mrr) AS retained_mrr
      , SUM(y.retained_block_count) AS retained_block_count
      , SUM(y.new_revenue) AS new_revenue
      , SUM(y.retained_revenue) AS retained_revenue
    FROM
    (
      -- This part just gets you zero-billed months rows 
      SELECT DISTINCT start_month
        , tenure_month 
        , year_month
        -- , ad_market_id
        , 0 AS new_customers
        , 0 AS retained_customers
        , 0 AS new_mrr
        , 0 AS new_block_count
        , 0 AS retained_mrr
        , 0 AS retained_block_count
        , 0 AS new_revenue
        , 0 AS retained_revenue
      FROM 
      (
        SELECT DISTINCT ym.start_month
          ,  CONCAT('M',LPAD(CAST(ym.tenure_month AS STRING),2,'0')) AS tenure_month
          , ym.year_month
          -- , st.ad_market_id
        FROM
        (
          SELECT DISTINCT x1.year_month AS start_month
            , x2.year_month
            , (cast(substring(cast(x2.year_month as string), 1,4) as int)-cast(substring(cast(x1.year_month as string), 1,4) as int))*12
                  + (cast(substring(cast(x2.year_month as string), 5,2) as int)-cast(substring(cast(x1.year_month as string), 5,2) as int)) as tenure_month
          FROM dm.date_dim x1
          JOIN dm.date_dim x2 ON x1.year_month<=x2.year_month  
          WHERE x1.year_month BETWEEN 201303 AND 201610
            AND x2.year_month BETWEEN 201303 AND 201610
        ) ym
        -- ,
        -- (
        --   select distinct ad_market_id
        --   from promo_market
        -- ) st 
      ) x

      UNION ALL

      SELECT start_month
        , tenure_month
        , year_month
        -- , ad_market_id
        , new_customers
        , retained_customers 
        , new_mrr
        , new_block_count
        , retained_mrr
        , retained_block_count
        , new_revenue
        , retained_revenue
      FROM tmp_data_dm.coe_jrr_cohort_months
    ) y
    GROUP BY 1,2,3
  ) z
) zz
-- join dm.ad_market_dimension amd on amd.ad_market_id = zz.ad_market_id
WHERE zz.new_customers > 0
  AND zz.start_month < 201610


SELECT * FROM tmp_data_dm.coe_jrr_final;
