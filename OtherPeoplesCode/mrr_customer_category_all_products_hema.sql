with cust_cat as
(
select
customer_id,
mrr_current_advertisement,
mrr_current_avvopro,
mrr_current_ignite,
mrr_current_website,
mrr_current_adplacement,
mrr_current_total,
mrr_prior_advertisement,
mrr_prior_avvopro,
mrr_prior_ignite,
mrr_prior_website,
mrr_prior_adplacement,
mrr_prior_total,
revenue_current_advertisement,
revenue_current_avvopro,
revenue_current_ignite,
revenue_current_website,
revenue_current_misc,
revenue_current_adplacement,
revenue_current_total,
revenue_prior_advertisement,
revenue_prior_avvopro,
revenue_prior_ignite,
revenue_prior_website,
revenue_prior_misc,
revenue_prior_adplacement,
revenue_prior_total,
ad_current_count,
ad_prior_count,
customer_billed_prior_month,
customer_billed_current_month,
customer_exists_prior_month,
case when (customer_billed_current_month='Y' and 
           customer_billed_prior_month='N' and 
           customer_exists_prior_month='N') then         mrr_current_total
           else 0 end as                                   mrr_acquired,
case when (customer_billed_current_month='Y' and 
           customer_billed_prior_month='Y') and 
           (mrr_current_total > mrr_prior_total) then    (mrr_current_total-mrr_prior_total)
           else 0 end as                                   mrr_penetrated,
case when customer_billed_prior_month='Y' and 
          ((mrr_current_total > 0 and  
            mrr_prior_total > 0) and 
           (mrr_current_total <= mrr_prior_total)) then  mrr_current_total 
     when ((mrr_current_total > 0 and  
            mrr_prior_total > 0) and 
           (mrr_current_total > mrr_prior_total)) then   mrr_prior_total 
           else 0 end as                                   mrr_retained,
case when (customer_billed_current_month='Y' and 
           customer_billed_prior_month='Y')  and
          (mrr_current_total > 0 and 
          (mrr_current_total < mrr_prior_total)) then    (mrr_current_total-mrr_prior_total) 
           else 0 end as                                   mrr_downsized,
case when (customer_billed_current_month='Y' 
           and expired_date is not null and 
           mrr_current_total=0) then                     (mrr_current_total-mrr_prior_total) 
           else 0 end as                                   mrr_churned,
case when (customer_billed_current_month='Y' 
           and customer_billed_prior_month='N' and 
           customer_exists_prior_month='Y') then         mrr_current_total 
           else 0 end as                                   mrr_returned,
expired_date,
expired_reason,
block_conversion_flag,
refund_current_month_flag,
customer_last_billed_date,
promo_flag,
yearmonth
from mrr_customer_all_products
where yearmonth=cast(concat(year(add_months(current_date, -1)), lpad(month(add_months(current_date, -1)),2,0)) as int)
)
INSERT OVERWRITE TABLE mrr_customer_category_all_products partition (yearmonth)
select
customer_id,
case when (customer_billed_current_month='Y' and 
           customer_billed_prior_month='N' and 
           customer_exists_prior_month='N' and 
           mrr_current_total > 0) then                           'ACQUIRED'
     when (customer_billed_current_month='Y' and 
           expired_date is null and 
           mrr_current_total=0 and 
           ad_current_count > 0) then                            'NO ACTIVITY'
     when (customer_billed_current_month='Y' and 
           expired_date is not null and 
           mrr_current_total=0) then                             'CHURNED'
     when ((customer_billed_current_month='Y' and 
            customer_billed_prior_month='Y') and 
           (mrr_current_total < mrr_prior_total) and 
           (mrr_prior_total > 0 and 
            mrr_current_total > 0)) then                         'DOWNSIZED'
     when ((customer_billed_current_month='Y' and 
            customer_billed_prior_month='Y') and 
           (mrr_current_total > mrr_prior_total)) then           'PENETRATED' 
     when ((customer_billed_current_month='Y' and 
            customer_billed_prior_month='Y') and 
           ((mrr_current_total > 0 and  
             mrr_prior_total > 0) and 
            (mrr_current_total = mrr_prior_total))) then         'RETAINED'
     when (customer_billed_current_month='Y' and 
           customer_billed_prior_month='N' and 
           customer_exists_prior_month='Y') then                 'RETURNED' 
     else 'NOT BILLED' end as customer_category,
mrr_current_advertisement,
mrr_current_avvopro,
mrr_current_ignite,
mrr_current_website,
mrr_current_adplacement,
mrr_current_total,
mrr_prior_advertisement,
mrr_prior_avvopro,
mrr_prior_ignite,
mrr_prior_website,
mrr_prior_adplacement,
mrr_prior_total,
revenue_current_advertisement,
revenue_current_avvopro,
revenue_current_ignite,
revenue_current_website,
revenue_current_misc,
revenue_current_adplacement,
revenue_current_total,
revenue_prior_advertisement,
revenue_prior_avvopro,
revenue_prior_ignite,
revenue_prior_website,
revenue_prior_misc,
revenue_prior_adplacement,
revenue_prior_total,
mrr_acquired,
mrr_penetrated,
mrr_downsized,
mrr_churned,
mrr_retained,
mrr_returned,
expired_date,
expired_reason,
block_conversion_flag,
refund_current_month_flag,
customer_last_billed_date,
customer_billed_current_month as customer_billed_current_month_flag,
promo_flag,
yearmonth
from
cust_cat;
