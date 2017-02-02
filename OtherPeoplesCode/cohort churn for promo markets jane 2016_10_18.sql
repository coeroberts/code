with promo_market as 
(
  select pmh.ad_market_id
    , pmh.ad_detail_type as ad_type
    , pmh.promo_begin_date
    , cast(concat(cast(year(pmh.promo_begin_date) as string), lpad(cast(month(pmh.promo_begin_date) as string),2,'0')) as int) as promo_month
  from tmp_data_dm.promo_market_history_view pmh
)

, start_month as 
(
  SELECT customer_id
    , om.ad_market_id
    , min(cast(concat(cast(year(order_line_begin_date) as string), lpad(cast(month(order_line_begin_date) as string),2,'0')) as int)) as start_month
  FROM dm.order_line_accumulation_fact o
  join dm.order_line_ad_market_fact om on om.order_line_number = o.order_line_number
  WHERE o.order_line_payment_date not IN ('-1', '1900-01-01') 
    and o.product_line_id in (2,7)
    and o.order_line_begin_date>='2013-01-01'
  GROUP BY 1,2
)

, customer_market as
(
  select od.customer_id
    , od.ad_market_id
    , od.ad_type
    , od.year_month
    , sum(od.mrr) as mrr
    , sum(od.block_count) as block_count
    , sum(od.order_line_net_price_amount_usd) as revenue
  from
  (
    select distinct o.customer_id
      , om.ad_market_id
      , o.product_subscription_id
      , case when o.product_line_id=7 then 'Sponsored Listing' else 'Display' end as ad_type
      , cast(concat(cast(year(o.order_line_begin_date) as string), lpad(cast(month(o.order_line_begin_date) as string),2,'0')) as int) as year_month
      , coalesce(mrr.mrr_actual_value,0) as mrr
      , o.block_count
      , o.order_line_net_price_amount_usd
    from dm.order_line_accumulation_fact o
    join dm.order_line_ad_market_fact om on om.order_line_number = o.order_line_number
    left join dm.mrr_subscription mrr on mrr.subscription_id = o.product_subscription_id 
          and mrr.yearmonth=cast(concat(cast(year(o.order_line_begin_date) as string), lpad(cast(month(o.order_line_begin_date) as string),2,'0')) as int)
    where o.product_line_id in (2,7) and o.order_line_begin_date>='2015-10-01'
      and o.order_line_payment_date!='1900-01-01'
      and o.order_line_payment_date!='-1'
  ) od
  join 
    (
      select distinct ad_market_id, ad_type from promo_market
  ) pm on pm.ad_market_id = od.ad_market_id and pm.ad_type = od.ad_type
  group by 1,2,3,4
)

, new_customer as
(
  select cm.*
  from customer_market cm
  join start_month sm on sm.start_month = cm.year_month and sm.customer_id = cm.customer_id and sm.ad_market_id = cm.ad_market_id
  join promo_market pm on pm.promo_month = cm.year_month and pm.ad_market_id = cm.ad_market_id and pm.ad_type = cm.ad_type
)

, cohort_active_customer as
(
  select year_month
    , ad_market_id
    , ad_type
    , sum(mrr) as mrr
    , sum(block_count) as block_count
    , count(distinct customer_id) as customer_count
    , sum(revenue) as revenue
  from new_customer
  group by 1,2,3
)

, temp as
(
  select x.start_month
    , concat('M',lpad(cast(x.period as string),2,'0')) as period
    , x.year_month
    , x.ad_market_id
    , x.ad_type
    , x.new_mrr
    , x.new_block_count
    , x.new_customer_count
    , x.retained_customers
    , x.retained_mrr
    , x.retained_block_count
    , x.new_revenue
    , x.retained_revenue
    -- , x.retention_customer
  from
  (
    select nc.year_month as start_month
      , nc.ad_market_id
      , nc.ad_type
      , (cast(substring(cast(future.year_month as string), 1,4) as int)-cast(substring(cast(nc.year_month as string), 1,4) as int))*12
        + (cast(substring(cast(future.year_month as string), 5,2) as int)-cast(substring(cast(nc.year_month as string), 5,2) as int)) as period
      , future.year_month
      , max(cac.mrr) as new_mrr
      , max(cac.block_count) as new_block_count
      , max(cac.customer_count) as new_customer_count
      , max(cac.revenue) as new_revenue
      , count(distinct future.customer_id) as retained_customers
      , sum(future.mrr) as retained_mrr
      , sum(future.block_count) as retained_block_count
      , sum(future.revenue) as retained_revenue
      -- , count(distinct future.customer_id)/max(cac.customer_count) as retention_customer
    from new_customer nc
    left join customer_market future on nc.customer_id = future.customer_id and nc.year_month<=future.year_month 
      and nc.ad_market_id = future.ad_market_id and nc.ad_type = future.ad_type 
      and future.year_month<cast(concat(cast(year(now()) as string), lpad(cast(month(now()) as string),2,'0')) as int)
    left join cohort_active_customer cac on nc.year_month = cac.year_month and cac.ad_market_id= nc.ad_market_id and cac.ad_type = nc.ad_type
    group by 1,2,3,4,5
  ) x
  where x.period is not null 
)

select zz.* 
  , amd.ad_market_state_name as ad_state
  , amd.ad_market_region_name as ad_region
  , amd.ad_market_county_name as ad_county
  , amd.ad_market_specialty_name as specialty
from
(
  select z.start_month
    , z.period
    , z.year_month
    , z.ad_market_id
    , first_value(z.new_customer_count) over (partition by z.start_month, z.ad_market_id order by z.period) as new_customer_count
    , z.retained_customers
    , first_value(z.new_mrr) over (partition by z.start_month, z.ad_market_id order by z.period) as new_mrr
    , z.retained_mrr
    , first_value(z.new_block_count) over (partition by z.start_month, z.ad_market_id order by z.period) as new_block_count
    , z.retained_block_count
    , first_value(z.new_revenue) over (partition by z.start_month, z.ad_market_id order by z.period) as new_revenue
    , z.retained_revenue
  from
  (
    select y.start_month
      , y.period
      , y.year_month
      , y.ad_market_id
      , sum(y.new_customer_count) as new_customer_count
      , sum(y.retained_customers) as retained_customers
      , sum(y.new_mrr) as new_mrr
      , sum(y.new_block_count) as new_block_count
      , sum(y.retained_mrr) as retained_mrr
      , sum(y.retained_block_count) as retained_block_count
      , sum(y.new_revenue) as new_revenue
      , sum(y.retained_revenue) as retained_revenue
    from
    (
      select distinct start_month
        , period 
        , year_month
        , ad_market_id
        , 0 as new_customer_count
        , 0 as retained_customers
        , 0 as new_mrr
        , 0 as new_block_count
        , 0 as retained_mrr
        , 0 as retained_block_count
        , 0 as new_revenue
        , 0 as retained_revenue
      from 
      (
        select distinct ym.start_month
          ,  concat('M',lpad(cast(ym.period as string),2,'0')) as period
          , ym.year_month
          , st.ad_market_id
        from
        (
          select distinct x1.year_month as start_month
            , x2.year_month
            , (cast(substring(cast(x2.year_month as string), 1,4) as int)-cast(substring(cast(x1.year_month as string), 1,4) as int))*12
                  + (cast(substring(cast(x2.year_month as string), 5,2) as int)-cast(substring(cast(x1.year_month as string), 5,2) as int)) as period
          from dm.date_dim x1
          join dm.date_dim x2 on x1.year_month<=x2.year_month  
          where x1.year_month >= 201510 
            and x2.year_month<cast(concat(cast(year(now()) as string), lpad(cast(month(now()) as string),2,'0')) as int)
        ) ym,
        (
          select distinct ad_market_id
          from promo_market
        ) st 
      ) x

      union all

      select start_month
        , period
        , year_month
        , ad_market_id
        , new_customer_count
        , retained_customers 
        , new_mrr
        , new_block_count
        , retained_mrr
        , retained_block_count
        , new_revenue
        , retained_revenue
      from temp
    ) y
    group by 1,2,3,4
  ) z
) zz
join 
dm.ad_market_dimension amd on amd.ad_market_id = zz.ad_market_id
where zz.new_customer_count>0
  and zz.start_month<=cast(concat(substring(cast(((cast(substring(concat(cast(year(now()) as string), lpad(cast(month(now()) as string),2,'0'))
, 1,4) as int)*12+cast(substring(concat(cast(year(now()) as string), lpad(cast(month(now()) as string),2,'0'))
, 5,2) as int))-1-2)/12 as string),1,4), 
 lpad(cast(((cast(substring(concat(cast(year(now()) as string), lpad(cast(month(now()) as string),2,'0'))
, 1,4) as int)*12+cast(substring(concat(cast(year(now()) as string), lpad(cast(month(now()) as string),2,'0'))
, 5,2) as int))-1-2)%12+1 as string),2,'0')) as int)
