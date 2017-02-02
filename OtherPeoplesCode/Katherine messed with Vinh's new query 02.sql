-- Katherine messed with Vinh's new query
---- Monthly report to be run at the beginning of each month

with revenue as
(
	select rev.customer_id
		, rev.product_subscription_id
		, rev.order_number
		, rev.invoice_id
		, rev.begin_use_date
		, rev.order_line_cancelled_date
		, rev.revenue
		, rev.purchase_price
		, rev.price as nonprorated_purchase_price
	from 
	(
		select c.customer_id
			, a.product_subscription_id
			, a.order_number
			, a.invoice_id
			, a.order_line_begin_date as begin_use_date
			, a.order_line_cancelled_date
			, sub.starts_on
			, row_number() over (partition by	sub.subscription_id 
												,cast(concat(cast(year(a.order_line_begin_date) as string), lpad(cast(month(a.order_line_begin_date) as string),2,'0'))as int) 
								order by sub.starts_on, sub.updated_at desc
								) as rn
			, sub.price
			, sum(case when a.order_line_payment_date = '-1' then 0 else a.order_line_net_price_amount_usd end) as revenue
			, sum(a.order_line_purchase_price_amount_usd) as purchase_price
		from dm.order_line_accumulation_fact a
			join dm.customer_dimension c on c.customer_id = a.customer_id
			join 
			(
					select subscription_id
						, starts_on
						, updated_at
						, round(cast(UNIT_PRICE as float)*block_count/100,2) as price
					from src.nrt_subscription_price
			) sub on sub.subscription_id = a.product_subscription_id
		where to_date(sub.starts_on) > a.order_line_begin_date
			and a.product_line_id in (2,7)
			and year(order_line_begin_date) = 2016 and month(order_line_begin_date) = 8
			--and c.customer_id = 44927
		group by 1,2,3,4,5,6,7,9, sub.subscription_id, sub.updated_at
		--order by 1,2
	) rev
	where rev.rn=1
)

, sub_start as
(
  SELECT DISTINCT subscription_id, sub_start_date 
  FROM
  (
  select
      subscription_id
     ,first_value(start_datetime) over (PARTITION BY subscription_id ORDER BY start_datetime, source_system_update_datetime desc) as sub_start_date
  from dm.subscription_price_dimension
  -- where subscription_id = 10430693
  ) qry
)

, mrr as
(
	select x.subscription_id
		, round(cast(x.UNIT_PRICE as float)*x.block_count/100,2) as MRR
	from
	(
	select 
	              prc.subscription_id
                 , prc.start_datetime
                 , prc.UNIT_PRICE
                 , prc.block_count
	            , st.sub_start_date
	            , strleft(from_unixtime (unix_timestamp (cast(st.sub_start_date as timestamp) + interval 4 months), 'yyyy-MM-dd HH:mm:ss'),7)
	            , strleft(prc.start_datetime,7)

	from dm.subscription_price_dimension prc
	inner join sub_start st 
	on st.subscription_id = prc.subscription_id
	where strleft(from_unixtime (unix_timestamp (cast(st.sub_start_date as timestamp) + interval 4 months), 'yyyy-MM-dd HH:mm:ss'),7)
	      =
	      strleft(prc.start_datetime,7)
	)
)

, start as
(
	select x.subscription_id
		, x.customer_id
		, x.starts_on as start_date
	from
	(
		select sp.subscription_id
			, r.customer_id
			, sp.starts_on
			, sp.updated_at
			, row_number() over (partition by sp.subscription_id order by sp.starts_on, sp.updated_at ) as rn
		from src.nrt_subscription_price sp
		join 
		(
			select distinct customer_id
				, product_subscription_id
			from revenue
		) r on r.product_subscription_id=sp.subscription_id
	) x 
	where x.rn=1
)

select y.*
	, case when round(y.mrr/isnull(y.nonprorated_purchase_price,0),2) = 2 then '50%discount' end as promo
from
(
	select 
		cast(concat(cast(year(r.begin_use_date) as string), lpad(cast(month(r.begin_use_date) as string),2,'0'))as int) as year_month
		, r.customer_id
		, r.product_subscription_id
		, to_date(st.start_date) as start_date
		, r.begin_use_date
		, r.order_number
		, r.invoice_id
		, sum(case when r.order_line_cancelled_date > '-1' then 0 else m.mrr end) as MRR
		, sum(case when r.order_line_cancelled_date > '-1' then m.mrr else 0 end) as cancelled_MRR
		, sum(r.revenue) as revenue
		, sum(r.purchase_price) as purchase_price
		, sum(r.nonprorated_purchase_price) as nonprorated_purchase_price
	from revenue r
	left join mrr m on r.product_subscription_id=m.subscription_id
	left join start st on st.subscription_id=r.product_subscription_id
	--where year_month<=201508
	--and customer_id=11577
	group by 1,2,3,4,5,6,7
	--order by 1,2,3,4,5,6,7
) y
where case when round(y.mrr/isnull(y.nonprorated_purchase_price,0),2) = 2 then '50%discount' end = '50%discount'
order by 1,2,3,4,5,6,7