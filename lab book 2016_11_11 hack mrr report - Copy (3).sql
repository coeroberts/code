Can I put the logic into a view?

Logic changes:
- Customer count should not include churned.
- We only count MRR if the subscriptions extends beyond EoM.
- NOT BILLED may contain a few customers who had revenue but no MRR implications.
- There are a few edge cases around NO ACIVITY.  
- Some revenue was falling through other cracks.

Notes:
- The customer count chart should still show churn if possible.
  (If I even keep the chart.)

QUESTIONS:
- Do we want MoM (and if so, in what form)?
- Combine CustMRR Monthly and MRR by Month?
- What''s used, unused, and wanted in Monthly Detail?
- How do they use expired_date?  If it is just to tell if churn, then
  just trust the category.

From Emily:
- Avg. upsell size 
- Avg. acquisition size
- Avg. return size
- Avg. downsize size
- Avg. cancel size
- Number of Failed CC customers? Not sure if we can get there… would be a subset of No Activity
- Is there a way to isolate those with Avvo Pro for free in our customer count?
  Free Non-Advertisers category or maybe i make a flag on Not Billed.

- Which of the following tabs do you use?
  Summary: yes, but I don’t typically reference the graphs. I like the 
  MRR Category table best. 
  MRR: not as much. There is a lot of information in here and it can be 
  hard to read. I might recommend splitting it up into two tables – one 
  with totals and one with MoM view. 
  Monthly Detail: yes, but use to it crosstab and download.  Yep Sayle wants all fields.
  Trend Detail: don’t reference at all.  yep, not Sayle either.
  MRR Table: don’t use frequently, but I should! [this underlies MRR Category]
  CustomerMRR-Monthly: use this tab the most. Would like to see some 
  additional data points added (above). 

1.  By Failed CC customers, you mean those with a credit card failure
    who were not later successfully billed in that month, right? 
    Yes, m’am. 
2.  Could you please send an example where you calculate the averages
    (such as average acquisition size) manually?  I would like to 
    sanity-check my numbers against what you have. 
    Here’s how I wouldlook at it – gut-check me. Isolate all the 
    customers who were upsold. Take an average of the incremental 
    upsell.

- Aw shoot the NOT BILLED plug needs to get all prior customers, not
  just the ones that signed up since where I am looking.
  Probably need to launch from a different table.  ugh.
- And while I am at it, would be extra handy to identify frickin free pro.
- Can I do anything about active months count?
  I could re-number chains and only count active months after that.
  Because by that time I have categories, and can only count ones that qualify.
-- - Wait can not really do quarter or year because some aggregations are
--   sum and some are EoM.
- New fields:
  -- Expired Date   (but only if expire happened in month) nope.
  -- Expired Reason (but only if expire happened in month) only to determine cc failure.
  Promo Flag
- Flag misc payment in month.
- And add a failed CC flag.

OK so phases:
- Create test dataset on new backfill data. done.
- Fix the little things above.
- Build the report on new backfill data. in progress
- Create a view on current MRR table to duplicate new logic.
  Wait.  Not convinced this can be a simple view, because there is no is_active or has_ads.

  --  mrr.year_month AS year_month_num
  -- ,mth.year*10 + mth.qtr_nbr_in_year AS quarter_num
  -- ,CONCAT('FY', CAST(mth.year % 2000 AS STRING), ' Q', CAST(mth.qtr_nbr_in_year AS STRING)) AS quarter
  -- ,mth.year AS year

DROP TABLE IF EXISTS tmp_data_dm.coe_mrr_report_phase_2_base ;
CREATE TABLE tmp_data_dm.coe_mrr_report_phase_2_base AS
SELECT
   CONCAT(CAST(FLOOR(mth.year_month/100) AS STRING), '-',LPAD(CAST(mth.year_month%100 AS STRING),2,'0')) AS year_month
  ,mrr.customer_id
  ,mrr.year_month_begin_date
  ,mrr.mrr_customer_category
  ,mrr.mrr_customer_exception
  ,mrr.mrr_method
  ,mrr.had_payment
  ,mrr.has_ads_eom AS                               has_ads
  ,mrr.has_had_payment_lifetime
  ,mrr.had_cc_failure
  ,mrr.promo_flag
  ,MAX(CASE WHEN mrr.revenue_current_misc > 0 THEN 'Y' ELSE 'N' END) AS had_misc_payment
  ,SUM(mrr.revenue_current_total) AS                revenue_current_total
  ,SUM(mrr.mrr_current_total) AS                    mrr_current_total
  ,SUM(mrr.revenue_prior_total) AS                  revenue_prior_total
  ,SUM(mrr.mrr_prior_total) AS                      mrr_prior_total
  ,SUM(mrr.mrr_acquired) AS                         mrr_acquired
  ,SUM(mrr.mrr_penetrated) AS                       mrr_penetrated
  ,SUM(mrr.mrr_downsized) AS                        mrr_downsized
  ,SUM(mrr.mrr_churned) AS                          mrr_churned
  ,SUM(mrr.mrr_retained) AS                         mrr_retained
  ,SUM(mrr.mrr_returned) AS                         mrr_returned
  ,SUM(mrr.mrr_retained_subset_flat_customers) AS   mrr_retained_subset_flat_customers
  ,SUM(mrr.mrr_retained_subset_delta_customers) AS  mrr_retained_subset_delta_customers
  ,SUM(mrr.revenue_current_advertisement)  AS       revenue_current_advertisement
  ,SUM(mrr.revenue_current_avvopro)  AS             revenue_current_avvopro
  ,SUM(mrr.revenue_current_ignite)  AS              revenue_current_ignite
  ,SUM(mrr.revenue_current_website)  AS             revenue_current_website
  ,SUM(mrr.revenue_current_adplacement)  AS         revenue_current_adplacement
  ,SUM(mrr.revenue_current_misc)  AS                revenue_current_misc
  ,SUM(mrr.revenue_current_other_sub)  AS           revenue_current_other_sub
  ,SUM(mrr.revenue_current_other)  AS               revenue_current_other
  ,SUM(mrr.mrr_current_advertisement)  AS           mrr_current_advertisement
  ,SUM(mrr.mrr_current_avvopro)  AS                 mrr_current_avvopro
  ,SUM(mrr.mrr_current_ignite)  AS                  mrr_current_ignite
  ,SUM(mrr.mrr_current_website)  AS                 mrr_current_website
  ,SUM(mrr.mrr_current_adplacement)  AS             mrr_current_adplacement
  ,SUM(mrr.mrr_current_other_sub)  AS               mrr_current_other_sub
  ,MAX(1) AS                                        customers
  -- ,COUNT(*) AS                                      customers
FROM         tmp_data_dm.coe_jrr_backfill_customer_mrr mrr
  INNER JOIN dm.month_dim mth
          ON mrr.year_month = mth.year_month
GROUP BY 1,2,3,4,5,6,7,8,9,10,11 ;

DROP TABLE IF EXISTS tmp_data_dm.coe_mrr_report_phase_2 ;
CREATE TABLE tmp_data_dm.coe_mrr_report_phase_2 AS
SELECT
   mrr.year_month
  ,mrr.year_month_begin_date
  ,mrr.mrr_customer_category
  ,mrr.mrr_customer_exception
  ,mrr.mrr_method
  ,mrr.had_payment
  ,mrr.has_ads
  ,mrr.has_had_payment_lifetime
  ,mrr.had_cc_failure
  ,mrr.promo_flag
  ,mrr.had_misc_payment
  ,SUM(mrr.revenue_current_total) AS                revenue_current_total
  ,SUM(mrr.mrr_current_total) AS                    mrr_current_total
  ,SUM(mrr.revenue_prior_total) AS                  revenue_prior_total
  ,SUM(mrr.mrr_prior_total) AS                      mrr_prior_total
  ,SUM(mrr.mrr_acquired) AS                         mrr_acquired
  ,SUM(mrr.mrr_penetrated) AS                       mrr_penetrated
  ,SUM(mrr.mrr_downsized) AS                        mrr_downsized
  ,SUM(mrr.mrr_churned) AS                          mrr_churned
  ,SUM(mrr.mrr_retained) AS                         mrr_retained
  ,SUM(mrr.mrr_returned) AS                         mrr_returned
  ,SUM(mrr.mrr_retained_subset_flat_customers) AS   mrr_retained_subset_flat_customers
  ,SUM(mrr.mrr_retained_subset_delta_customers) AS  mrr_retained_subset_delta_customers
  ,SUM(mrr.revenue_current_advertisement)  AS       revenue_current_advertisement
  ,SUM(mrr.revenue_current_avvopro)  AS             revenue_current_avvopro
  ,SUM(mrr.revenue_current_ignite)  AS              revenue_current_ignite
  ,SUM(mrr.revenue_current_website)  AS             revenue_current_website
  ,SUM(mrr.revenue_current_adplacement)  AS         revenue_current_adplacement
  ,SUM(mrr.revenue_current_misc)  AS                revenue_current_misc
  ,SUM(mrr.revenue_current_other_sub)  AS           revenue_current_other_sub
  ,SUM(mrr.revenue_current_other)  AS               revenue_current_other
  ,SUM(mrr.mrr_current_advertisement)  AS           mrr_current_advertisement
  ,SUM(mrr.mrr_current_avvopro)  AS                 mrr_current_avvopro
  ,SUM(mrr.mrr_current_ignite)  AS                  mrr_current_ignite
  ,SUM(mrr.mrr_current_website)  AS                 mrr_current_website
  ,SUM(mrr.mrr_current_adplacement)  AS             mrr_current_adplacement
  ,SUM(mrr.mrr_current_other_sub)  AS               mrr_current_other_sub
  ,SUM(mrr.customers) AS                            customers
FROM         tmp_data_dm.coe_mrr_report_phase_2_base mrr
WHERE mrr.year_month_begin_date <= ADD_MONTHS(TRUNC(now(), 'MONTH'), -1)
GROUP BY 1,2,3,4,5,6,7,8,9,10,11 ;

DROP TABLE IF EXISTS tmp_data_dm.coe_mrr_report_phase_2_detail ;
CREATE TABLE tmp_data_dm.coe_mrr_report_phase_2_detail AS
SELECT *
FROM         tmp_data_dm.coe_mrr_report_phase_2_base mrr
WHERE mrr.year_month_begin_date BETWEEN ADD_MONTHS(TRUNC(now(), 'MONTH'), -6) 
                                    AND ADD_MONTHS(TRUNC(now(), 'MONTH'), -1) ;

----
SELECT
   dt.year_month
  ,sub.expired_reason
  ,COUNT(*)
FROM
  (
  SELECT *, STRLEFT(expire_datetime, 10) AS expire_date
  FROM dm.subscription_dimension
  ) sub
  INNER JOIN dm.date_dim dt
  ON sub.expire_date = dt.actual_date
WHERE sub.expire_date >= '2013-01-01'
GROUP BY 1,2
OK so only available as part of sub.
I just want to make a has_failed_cc flag.

Hrm.  For detail data, I need to find a way to get that level without
having to define all of the metrics again.
Actually, interestingly, very few of the stuff I calculate in Tableau
is relevant at individual customer level.
So yeah, I am going to add a second detail source.

- Make 'No' for some things into blank.


