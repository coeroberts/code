with mrr_cust_data as (
select mrr_curr.customer_id,
mrr_curr.yearmonth,
coalesce(mrr_prev.revenue,0) as revenue_prior_month,
coalesce(mrr_curr.revenue,0) as revenue_current_month,
coalesce(mrr_prev.mrr,0) as mrr_prior_month,
coalesce(mrr_curr.mrr,0) as mrr_current_month,
case when mrr_curr.customer_created_date=mrr_curr.yearmonth then 'Y' else 'N' end as new_customer,
mrr_curr.customer_billed_prior_month as customer_billed_prior_month,
mrr_curr.ad_count as ad_count_current,
mrr_prev.ad_count as ad_count_prior,
mrr_curr.cancelled_date as cancelled_date,
mrr_curr.expired_date as expired_date,
mrr_curr.expired_reason as expired_reason
from (select customer_id,yearmonth, sum(mrr) as mrr, sum(revenue) as revenue,count(ad_count) as ad_count, max(customer_created_date)  as customer_created_date, max(cancelled_date) as  cancelled_date,
max(customer_billed_prior_month) as customer_billed_prior_month, max(expired_date) as expired_date,concat_ws('|',collect_set( expired_reason)) as expired_reason
from mrr_subscription 
where yearmonth=cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int)
group by customer_id,yearmonth) mrr_curr
left join (select customer_id, sum(mrr) as mrr, sum(revenue) as revenue,count(ad_count) as ad_count from mrr_subscription 
where yearmonth=cast(concat(year(add_months(current_date, -2)), lpad(month(add_months(current_date, -2)),2,0)) as int)
group by customer_id) mrr_prev
on mrr_curr.customer_id=mrr_prev.customer_id
),
mrr_classication as (
select
customer_id,
revenue_prior_month,
revenue_current_month,
mrr_prior_month,
mrr_current_month,
ad_count_current,
ad_count_prior,
cancelled_date,
expired_date,
expired_reason,
yearmonth,
customer_billed_prior_month,
case when customer_billed_prior_month='N' and (mrr_prior_month=0 and mrr_current_month > 0) then mrr_current_month else 0 end as mrr_acquired,
case when customer_billed_prior_month='Y' and mrr_current_month > mrr_prior_month then (mrr_current_month-mrr_prior_month) else 0 end as mrr_penetrated,
case when customer_billed_prior_month='Y' and ((mrr_current_month > 0 or  mrr_prior_month > 0) and (mrr_current_month <= mrr_prior_month)) then mrr_current_month else mrr_prior_month end as mrr_retained,
case when customer_billed_prior_month='Y' and (mrr_current_month <> 0 and (mrr_current_month < mrr_prior_month)) then (mrr_current_month-mrr_prior_month) else 0 end as mrr_downsized,
case when customer_billed_prior_month='Y' and mrr_current_month =0 and mrr_prior_month > 0 then (mrr_current_month-mrr_prior_month) else 0 end as mrr_churned
from mrr_cust_data
)
INSERT OVERWRITE TABLE mrr_customer_classification partition (yearmonth)
select
customer_id,
revenue_prior_month,
revenue_current_month,
mrr_prior_month,
mrr_current_month,
mrr_acquired,
mrr_penetrated,
mrr_retained,
(mrr_acquired+mrr_penetrated+mrr_retained) as mrr_total,
mrr_downsized,
mrr_churned,
case when (mrr_acquired <> 0 or (customer_billed_prior_month='N' and mrr_current_month>0)) then 'ACQUIRED'
    when (mrr_prior_month=0 and mrr_current_month=0) and (ad_count_current > 0 OR ad_count_prior > 0) then 'NO ACTIVITY'
    when mrr_churned <> 0 then 'CHURNED'
    when mrr_downsized <> 0 then 'DOWNSIZED'
    when mrr_penetrated <> 0 then 'PENETRATED' 
    when (mrr_retained <> 0 or ((mrr_current_month > 0 or  mrr_prior_month > 0) and (mrr_current_month = mrr_prior_month))) then 'RETAINED' end as customer_category,
cancelled_date,
expired_date,
expired_reason,
yearmonth
from mrr_classication;

