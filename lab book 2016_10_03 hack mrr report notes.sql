select
 yearmonth
,SUM(mrr_acquired+mrr_returned) as 'New_MRR'
,SUM(mrr_penetrated) as 'ModUP'
,SUM(mrr_downsized) as 'moddown'
,SUM(mrr_churned) as 'fullchurn'
,SUM(MRR_prior_total) as 'beginningMRR'
,SUM(MRR_prior_total+mrr_acquired+mrr_returned+mrr_penetrated+mrr_downsized+mrr_churned) as 'CalcedEndingMRR'
,SUM(MRR_current_total) as 'ActualendingMRR'
from mrr_customer_category_all_products where yearmonth in (201606,201607,201608,201609) 
group by yearmonth


customer_id
mrr_customer_category
mrr_current_advertisement
mrr_current_avvopro
mrr_current_ignite
mrr_current_website
mrr_current_adplacement
mrr_current_total
mrr_prior_advertisement
mrr_prior_avvopro
mrr_prior_ignite
mrr_prior_website
mrr_prior_adplacement
mrr_prior_total

mrr_acquired
mrr_penetrated
mrr_downsized
mrr_churned
mrr_retained
mrr_returned
expired_date
expired_reason
block_conversion_flag
refund_current_month_flag
customer_prev_billed_date
customer_billed_current_month_flag
promo_flag
yearmonth

DROP TABLE tmp_data_dm.coe_temp_mrr;
CREATE TABLE tmp_data_dm.coe_temp_mrr AS
select
 yearmonth
,mrr_customer_category
,SUM(mrr_acquired+mrr_returned) as 'New_MRR'
,SUM(mrr_acquired) as 'mrr_acquired'
,SUM(mrr_returned) as 'mrr_returned'
,SUM(mrr_penetrated) as 'mrr_penetrated'
,SUM(mrr_downsized) as 'mrr_downsized'
,SUM(mrr_churned) as 'mrr_churned'
,SUM(MRR_prior_total) as 'MRR_prior_total'
,SUM(MRR_prior_total + mrr_acquired + mrr_returned + mrr_penetrated + mrr_downsized + mrr_churned) as 'Calced_Ending_MRR'
,SUM(MRR_current_total) as 'MRR_current_total'
,COUNT(*) AS customers
from mrr_customer_category_all_products where yearmonth in (201606,201607,201608,201609) 
group by 1,2

OK so it''s the NO ACTIVITY customers.  They show up with prior MRR,
and the current month has no MRR for them.  The MRR_current_total
value is off (too low) by this amount.
Should we be counting that amount as downsized?

LOOK ToDo:
OK conclusion for Jake for now: when doing the math, this number needs
to be considered a downsize.  
So could hack it with a couple possibilities:
- Exclude NO ACTIVITY customers from the calculation altogether.
- Include them, but take their prior month amount and subtract it out 
  of the calculation.

MRR_current_total is the correct amount.
