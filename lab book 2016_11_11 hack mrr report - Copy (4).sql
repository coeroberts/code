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
  ,IFNULL(mrr.mrr_customer_exception, '') AS        mrr_customer_exception
  ,mrr.mrr_method
  ,IFNULL(mrr.has_payment_during_month, 'N') AS     has_payment_during_month
  ,IFNULL(mrr.has_ads_eom, 'N') AS                  has_ads_eom
  ,IFNULL(mrr.has_had_payment_lifetime, 'N') AS     has_had_payment_lifetime
  ,IFNULL(mrr.has_cc_failure_during_month, 'N') AS  has_cc_failure_during_month
  ,IFNULL(mrr.promo_flag, '') AS                    promo_flag
  ,MAX(CASE WHEN mrr.revenue_current_misc > 0 THEN 'Y' ELSE 'N' END) AS has_misc_payment_during_month
  ,SUM(mrr.revenue_current_total) AS                revenue_current_total
  ,SUM(mrr.mrr_current_total) AS                    mrr_current_total
  ,SUM(mrr.revenue_prior_total) AS                  revenue_prior_total
  ,SUM(mrr.mrr_prior_total) AS                      mrr_prior_total
  ,SUM(mrr.mrr_acquired) AS                         mrr_acquired
  ,SUM(mrr.mrr_returned) AS                         mrr_returned
  ,SUM(mrr.mrr_penetrated) AS                       mrr_penetrated
  ,SUM(mrr.mrr_retained) AS                         mrr_retained
  ,SUM(mrr.mrr_downsized) AS                        mrr_downsized
  ,SUM(mrr.mrr_churned) AS                          mrr_churned
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
  ,mrr.has_payment_during_month
  ,mrr.has_ads_eom
  ,mrr.has_had_payment_lifetime
  ,mrr.has_cc_failure_during_month
  ,mrr.promo_flag
  ,mrr.has_misc_payment_during_month
  ,SUM(mrr.revenue_current_total) AS                revenue_current_total
  ,SUM(mrr.mrr_current_total) AS                    mrr_current_total
  ,SUM(mrr.revenue_prior_total) AS                  revenue_prior_total
  ,SUM(mrr.mrr_prior_total) AS                      mrr_prior_total
  ,SUM(mrr.mrr_acquired) AS                         mrr_acquired
  ,SUM(mrr.mrr_returned) AS                         mrr_returned
  ,SUM(mrr.mrr_penetrated) AS                       mrr_penetrated
  ,SUM(mrr.mrr_retained) AS                         mrr_retained
  ,SUM(mrr.mrr_downsized) AS                        mrr_downsized
  ,SUM(mrr.mrr_churned) AS                          mrr_churned
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
So yeah, I am going to add a second detail source.  done.

-- - Make 'No' for some things into blank.  think i did this on has cc failure and misc payment.
-- - Promo flag looks like always null?  yep, sposed to be.
----

-- SELECT
--    new.customer_id
--   ,new.yearmonth
--   ,mth.month_begin_date AS year_month_begin_date
--   -- ,new.mrr_customer_category
--   -- has_ads_eom: mca.customer_id IS NOT NULL AND mca.customer_category NOT IN ('CHURNED', 'NOT BILLED')
--   -- has_ads_eom_prior is an approximation: 
--   yeah screw it I am going back to mrr_customer_all_products because it knows if they have ads.
--   ,CASE WHEN chn.is_active_eom = 'Y' AND
--              srt.start_month_lifetime >= new.yearmonth THEN     'ACQUIRED'

--         WHEN chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'N' AND
--              srt.start_month_lifetime < new.yearmonth THEN      'RETURNED'
             
--         WHEN chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total > new.mrr_prior_total THEN   'PENETRATED'

--         WHEN chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total > 0 AND
--              new.mrr_current_total  =  new.mrr_prior_total THEN 'RETAINED'

--         WHEN chn.is_active_eom = 'Y' AND  -- WAIT not sure this works.  Nope.
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total < new.mrr_prior_total THEN   'DOWNSIZED'

--         WHEN chn.is_active_eom = 'N' AND
--              chn.is_active_eom_prior   = 'Y' THEN               'CHURNED'

--         WHEN chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior   = 'Y' AND
--              new.mrr_current_total = 0 AND
--              new.mrr_prior_total = 0 THEN                       'NO ACTIVITY'
--         ELSE 'NOT BILLED' END AS                              mrr_customer_category
--   ,CASE WHEN chn.is_active_eom = 'Y' AND
--              srt.start_month_lifetime >= new.yearmonth THEN           CAST(new.mrr_current_total AS DECIMAL(20,2))
--               ELSE 0 END AS                                   mrr_acquired
--   ,CASE WHEN chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'N' AND
--              srt.start_month_lifetime < new.yearmonth THEN           CAST(new.mrr_current_total AS DECIMAL(20,2))
--               ELSE 0 END AS                                   mrr_returned
--   ,CASE WHEN chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total > new.mrr_prior_total THEN     CAST((new.mrr_current_total - new.mrr_prior_total) AS DECIMAL(20,2))
--               ELSE 0 END AS                                   mrr_penetrated
--   ,CASE WHEN -- RETAINED
--              chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total > 0 AND
--              new.mrr_current_total  =  new.mrr_prior_total THEN   CAST(new.mrr_current_total AS DECIMAL(20,2))
--         WHEN -- DOWNSIZED
--              chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total < new.mrr_prior_total THEN     CAST(new.mrr_current_total AS DECIMAL(20,2))
--         WHEN -- PENETRATED
--              chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total > new.mrr_prior_total THEN     CAST(new.mrr_prior_total AS DECIMAL(20,2))
--               ELSE 0 END AS                                   mrr_retained
--   ,CASE WHEN chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total < new.mrr_prior_total THEN     CAST((new.mrr_current_total - new.mrr_prior_total)  AS DECIMAL(20,2))
--               ELSE 0 END AS                                   mrr_downsized
--   ,CASE WHEN chn.is_active_eom = 'N' AND
--              chn.is_active_eom_prior   = 'Y' THEN         CAST((new.mrr_current_total - new.mrr_prior_total) AS DECIMAL(20,2))
--               ELSE 0 END AS                                   mrr_churned
--   -- This is the portion of mrr_retained for customers in the RETAINED category.
--   ,CASE WHEN chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total > 0 AND
--              new.mrr_current_total  =  new.mrr_prior_total THEN   CAST(new.mrr_current_total  AS DECIMAL(20,2))
--               ELSE 0 END AS                                   mrr_retained_subset_flat_customers
--   -- This is the portion of mrr_retained for customers in the PENETRATED and DOWNSIZED categories.
--   ,CASE WHEN -- DOWNSIZED
--              chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total < new.mrr_prior_total THEN     CAST(new.mrr_current_total AS DECIMAL(20,2))
--         WHEN -- PENETRATED
--              chn.is_active_eom = 'Y' AND
--              chn.is_active_eom_prior = 'Y' AND
--              new.mrr_current_total > new.mrr_prior_total THEN     CAST(new.mrr_prior_total AS DECIMAL(20,2))
--               ELSE 0 END AS                                   mrr_retained_subset_delta_customers
--   -- ,new.mrr_acquired
--   -- ,new.mrr_returned
--   -- ,new.mrr_penetrated
--   -- ,new.mrr_retained
--   -- ,new.mrr_downsized
--   -- ,new.mrr_churned
--   -- ,CASE WHEN new.mrr_customer_category = 'RETAINED'                   
--   --         THEN new.mrr_retained ELSE 0 END AS mrr_retained_subset_flat_customers
--   -- ,CASE WHEN new.mrr_customer_category IN ('PENETRATED', 'DOWNSIZED')
--   --         THEN new.mrr_retained ELSE 0 END AS mrr_retained_subset_delta_customers
--   ,CASE WHEN new.mrr_customer_category NOT IN ('CHURNED', 'NOT BILLED')
--           THEN 'Y' ELSE 'N' END AS is_active_eom
--   ,new.customer_billed_current_month_flag AS is_active_during_month
--   ,CASE WHEN mca.customer_id IS NOT NULL AND 
--              mca.customer_category NOT IN ('CHURNED', 'NOT BILLED')
--           THEN 'Y' ELSE 'N' END has_ads_eom
--   ,CASE WHEN mca.customer_id IS NOT NULL
--           THEN 'Y' ELSE 'N' END has_ads_during_month
--   ,new.mrr_current_advertisement
--   ,new.mrr_current_avvopro
--   ,new.mrr_current_ignite
--   ,new.mrr_current_website
--   ,new.mrr_current_adplacement
--   ,NULL AS mrr_current_other_sub
--   ,new.mrr_current_total
--   ,new.mrr_prior_advertisement
--   ,new.mrr_prior_avvopro
--   ,new.mrr_prior_ignite
--   ,new.mrr_prior_website
--   ,new.mrr_prior_adplacement
--   ,NULL AS mrr_prior_other_sub
--   ,new.mrr_prior_total
--   ,new.revenue_current_advertisement
--   ,new.revenue_current_avvopro
--   ,new.revenue_current_ignite
--   ,new.revenue_current_website
--   ,new.revenue_current_adplacement
--   ,new.revenue_current_misc
--   ,NULL AS revenue_current_other_sub
--   ,NULL AS revenue_current_other
--   ,new.revenue_current_total
--   ,new.revenue_prior_advertisement
--   ,new.revenue_prior_avvopro
--   ,new.revenue_prior_ignite
--   ,new.revenue_prior_website
--   ,new.revenue_prior_adplacement
--   ,new.revenue_prior_misc
--   ,NULL AS revenue_prior_other_sub
--   ,NULL AS revenue_prior_other
--   ,new.revenue_prior_total
--   ,NULL AS has_non_ads_eom
--   ,NULL AS has_non_ads_during_month
--   ,NULL AS has_payment_during_month
--   ,NULL AS has_cc_failure_during_month
--   ,NULL AS mrr_method
--   ,NULL AS max_bill_date_in_month
--   ,CASE WHEN srt.start_month_lifetime < new.yearmonth
--           THEN 'Y' ELSE 'N' END AS customer_exists_prior_month
--   ,NULL AS is_active_eom_prior
--   ,NULL AS is_active_during_month_prior
--   ,NULL AS has_ads_eom_prior
--   ,NULL AS has_ads_during_month_prior
--   ,NULL AS has_payment_during_month_prior
--   ,NULL AS chain_number
--   ,NULL AS tenure_month_chain
--   ,1+(FLOOR(new.yearmonth/100)-FLOOR(srt.start_month_lifetime/100)) * 12 +
--            (new.yearmonth%100-       srt.start_month_lifetime%100) AS tenure_month_lifetime
--   ,NULL AS tenure_month_prev
--   ,NULL AS active_months_to_date
--   ,NULL AS start_month_chain
--   ,NULL AS start_month_begin_date_chain
--   ,srt.start_month_lifetime
--   ,srt.start_month_begin_date_lifetime
--   ,NULL AS first_payment_month
--   ,NULL AS has_had_payment_lifetime
--   ,new.promo_flag
--   ,new.expired_date
--   ,new.expired_reason
--   ,new.block_conversion_flag
--   ,new.refund_current_month_flag
--   ,new.customer_prev_billed_date
--   ,new.customer_billed_current_month_flag
-- FROM         dm.mrr_customer_category_all_products new
--        INNER JOIN dm.month_dim mth ON new.yearmonth = mth.year_month
--   LEFT OUTER JOIN dm.mrr_customer_classification mca
--           ON new.customer_id = mca.customer_id
--          AND new.yearmonth = mca.yearmonth
--   LEFT OUTER JOIN
--     (
--     SELECT
--        nrt.id AS customer_id
--       ,CAST(from_unixtime(unix_timestamp(CAST(nrt.created_at AS TIMESTAMP)), 'yyyyMM') AS INT) AS start_month_lifetime
--       ,TO_DATE(TRUNC(nrt.created_at, 'MONTH')) AS start_month_begin_date_lifetime
--     FROM src.nrt_customer nrt
--     ) srt
--     ON new.customer_id = srt.customer_id
-- WHERE new.yearmonth >= 201510

OK now for the union view:
DROP VIEW IF EXISTS tmp_data_dm.mrr_customer_category_union_backfill;
CREATE VIEW tmp_data_dm.mrr_customer_category_union_backfill AS
SELECT
   new.customer_id
  ,new.yearmonth
  ,mth.month_begin_date AS year_month_begin_date
  ,CASE WHEN new.is_active_eom = 'Y' AND
             new.customer_exists_prior_month = 'N' THEN         'ACQUIRED'

        WHEN new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'N' AND
             new.customer_exists_prior_month = 'Y' THEN         'RETURNED'
             
        WHEN new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total > new.mrr_prior_total THEN   'PENETRATED'

        WHEN new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total > 0 AND
             new.mrr_current_total  =  new.mrr_prior_total THEN 'RETAINED'

        WHEN new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total < new.mrr_prior_total THEN   'DOWNSIZED'

        WHEN new.is_active_eom = 'N' AND
             new.is_active_eom_prior   = 'Y' THEN               'CHURNED'

        WHEN new.is_active_eom = 'Y' AND
             new.is_active_eom_prior   = 'Y' AND
             new.mrr_current_total = 0 AND
             new.mrr_prior_total = 0 THEN                       'NO ACTIVITY'
        ELSE 'NOT BILLED' END AS                              mrr_customer_category
  ,CASE WHEN new.is_active_eom = 'Y' AND
             new.customer_exists_prior_month = 'N' THEN           CAST(new.mrr_current_total AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_acquired
  ,CASE WHEN new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'N' AND
             new.customer_exists_prior_month = 'Y' THEN           CAST(new.mrr_current_total AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_returned
  ,CASE WHEN new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total > new.mrr_prior_total THEN     CAST((new.mrr_current_total - new.mrr_prior_total) AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_penetrated
  ,CASE WHEN -- RETAINED
             new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total > 0 AND
             new.mrr_current_total  =  new.mrr_prior_total THEN   CAST(new.mrr_current_total AS DECIMAL(20,2))
        WHEN -- DOWNSIZED
             new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total < new.mrr_prior_total THEN     CAST(new.mrr_current_total AS DECIMAL(20,2))
        WHEN -- PENETRATED
             new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total > new.mrr_prior_total THEN     CAST(new.mrr_prior_total AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_retained
  ,CASE WHEN new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total < new.mrr_prior_total THEN     CAST((new.mrr_current_total - new.mrr_prior_total)  AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_downsized
  ,CASE WHEN new.is_active_eom = 'N' AND
             new.is_active_eom_prior   = 'Y' THEN                 CAST(-1 * new.mrr_prior_total AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_churned

  -- This is the portion of mrr_retained for customers in the RETAINED category.
  ,CASE WHEN new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total > 0 AND
             new.mrr_current_total  =  new.mrr_prior_total THEN   CAST(new.mrr_current_total  AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_retained_subset_flat_customers
  -- This is the portion of mrr_retained for customers in the PENETRATED and DOWNSIZED categories.
  ,CASE WHEN -- DOWNSIZED
             new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total < new.mrr_prior_total THEN     CAST(new.mrr_current_total AS DECIMAL(20,2))
        WHEN -- PENETRATED
             new.is_active_eom = 'Y' AND
             new.is_active_eom_prior = 'Y' AND
             new.mrr_current_total > new.mrr_prior_total THEN     CAST(new.mrr_prior_total AS DECIMAL(20,2))
              ELSE 0 END AS                                   mrr_retained_subset_delta_customers
  ,new.is_active_eom
  ,new.is_active_during_month
  ,new.has_ads_eom
  ,new.has_ads_during_month

  ,new.mrr_current_advertisement
  ,new.mrr_current_avvopro
  ,new.mrr_current_ignite
  ,new.mrr_current_website
  ,new.mrr_current_adplacement
  ,NULL AS mrr_current_other_sub
  ,new.mrr_current_total
  ,new.mrr_prior_advertisement
  ,new.mrr_prior_avvopro
  ,new.mrr_prior_ignite
  ,new.mrr_prior_website
  ,new.mrr_prior_adplacement
  ,NULL AS mrr_prior_other_sub
  ,new.mrr_prior_total
  ,new.revenue_current_advertisement
  ,new.revenue_current_avvopro
  ,new.revenue_current_ignite
  ,new.revenue_current_website
  ,new.revenue_current_adplacement
  ,new.revenue_current_misc
  ,NULL AS revenue_current_other_sub
  ,NULL AS revenue_current_other
  ,new.revenue_current_total
  ,new.revenue_prior_advertisement
  ,new.revenue_prior_avvopro
  ,new.revenue_prior_ignite
  ,new.revenue_prior_website
  ,new.revenue_prior_adplacement
  ,new.revenue_prior_misc
  ,NULL AS revenue_prior_other_sub
  ,NULL AS revenue_prior_other
  ,new.revenue_prior_total
  ,NULL AS has_non_ads_eom
  ,NULL AS has_non_ads_during_month
  ,NULL AS has_payment_during_month
  ,NULL AS has_cc_failure_during_month
  ,NULL AS mrr_method
  ,NULL AS max_bill_date_in_month
  ,CASE WHEN srt.start_month_lifetime < new.yearmonth
          THEN 'Y' ELSE 'N' END AS customer_exists_prior_month
  ,NULL AS is_active_eom_prior
  ,NULL AS is_active_during_month_prior
  ,NULL AS has_ads_eom_prior
  ,NULL AS has_ads_during_month_prior
  ,NULL AS has_payment_during_month_prior
  ,NULL AS chain_number
  ,NULL AS tenure_month_chain
  ,1+(FLOOR(new.yearmonth/100)-FLOOR(srt.start_month_lifetime/100)) * 12 +
           (new.yearmonth%100-       srt.start_month_lifetime%100) AS tenure_month_lifetime
  ,NULL AS tenure_month_prev
  ,NULL AS active_months_to_date
  ,NULL AS start_month_chain
  ,NULL AS start_month_begin_date_chain
  ,srt.start_month_lifetime
  ,srt.start_month_begin_date_lifetime
  ,NULL AS first_payment_month
  ,NULL AS has_had_payment_lifetime
  ,new.promo_flag
  ,new.expired_date
  ,new.expired_reason
  ,new.block_conversion_flag
  ,new.refund_current_month_flag
  ,new.customer_last_billed_date AS customer_prev_billed_date
  ,new.customer_billed_current_month AS customer_billed_current_month_flag
FROM
    (
    SELECT *
      ,CASE WHEN ((cap.ad_current_count > 0 OR cap.mrr_current_total > 0) AND cap.expired_date IS NULL)
              THEN 'Y' ELSE 'N' END AS is_active_eom
      ,CASE WHEN (cap.ad_current_count > 0 OR cap.mrr_current_total > 0)  -- approximation
              THEN 'Y' ELSE 'N' END AS is_active_during_month
      ,CASE WHEN (cap.ad_prior_count > 0 OR cap.mrr_prior_total > 0)  -- approximation
              THEN 'Y' ELSE 'N' END AS is_active_eom_prior
      ,CASE WHEN (cap.ad_current_count > 0 AND cap.expired_date IS NULL)
              THEN 'Y' ELSE 'N' END AS has_ads_eom
      ,CASE WHEN (cap.ad_current_count > 0)
              THEN 'Y' ELSE 'N' END AS has_ads_during_month
    FROM dm.mrr_customer_all_products cap
    ) new
       INNER JOIN dm.month_dim mth ON new.yearmonth = mth.year_month
  LEFT OUTER JOIN
    (
    SELECT
       nrt.id AS customer_id
      ,CAST(from_unixtime(unix_timestamp(CAST(nrt.created_at AS TIMESTAMP)), 'yyyyMM') AS INT) AS start_month_lifetime
      ,TO_DATE(TRUNC(nrt.created_at, 'MONTH')) AS start_month_begin_date_lifetime
    FROM src.nrt_customer nrt
    ) srt
    ON new.customer_id = srt.customer_id
WHERE new.yearmonth >= 201510
UNION ALL
SELECT
   old.customer_id
  ,old.year_month As yearmonth
  ,old.year_month_begin_date
  ,old.mrr_customer_category
  ,old.mrr_acquired
  ,old.mrr_returned
  ,old.mrr_penetrated
  ,old.mrr_retained
  ,old.mrr_downsized
  ,old.mrr_churned
  ,old.mrr_retained_subset_flat_customers
  ,old.mrr_retained_subset_delta_customers
  ,old.is_active_eom
  ,old.is_active_during_month
  ,old.has_ads_eom
  ,old.has_ads_during_month
  ,old.mrr_current_advertisement
  ,old.mrr_current_avvopro
  ,old.mrr_current_ignite
  ,old.mrr_current_website
  ,old.mrr_current_adplacement
  ,old.mrr_current_other_sub
  ,old.mrr_current_total
  ,old.mrr_prior_advertisement
  ,old.mrr_prior_avvopro
  ,old.mrr_prior_ignite
  ,old.mrr_prior_website
  ,old.mrr_prior_adplacement
  ,old.mrr_prior_other_sub
  ,old.mrr_prior_total
  ,old.revenue_current_advertisement
  ,old.revenue_current_avvopro
  ,old.revenue_current_ignite
  ,old.revenue_current_website
  ,old.revenue_current_adplacement
  ,old.revenue_current_misc
  ,old.revenue_current_other_sub
  ,old.revenue_current_other
  ,old.revenue_current_total
  ,old.revenue_prior_advertisement
  ,old.revenue_prior_avvopro
  ,old.revenue_prior_ignite
  ,old.revenue_prior_website
  ,old.revenue_prior_adplacement
  ,old.revenue_prior_misc
  ,old.revenue_prior_other_sub
  ,old.revenue_prior_other
  ,old.revenue_prior_total
  ,old.has_non_ads_eom
  ,old.has_non_ads_during_month
  ,old.has_payment_during_month
  ,old.has_cc_failure_during_month
  ,old.mrr_method
  ,old.max_bill_date_in_month
  ,old.customer_exists_prior_month
  ,old.is_active_eom_prior
  ,old.is_active_during_month_prior
  ,old.has_ads_eom_prior
  ,old.has_ads_during_month_prior
  ,old.has_payment_during_month_prior
  ,old.chain_number
  ,old.tenure_month_chain
  ,old.tenure_month_lifetime
  ,old.tenure_month_prev
  ,old.active_months_to_date
  ,old.start_month_chain
  ,old.start_month_begin_date_chain
  ,old.start_month_lifetime
  ,old.start_month_begin_date_lifetime
  ,old.first_payment_month
  ,old.has_had_payment_lifetime
  ,old.promo_flag
  ,CAST(NULL AS STRING) AS expired_date
  ,CAST(NULL AS STRING) AS expired_reason
  ,CAST(NULL AS STRING) AS block_conversion_flag
  ,CAST(NULL AS STRING) AS refund_current_month_flag
  ,CAST(NULL AS STRING) AS customer_prev_billed_date
  ,CAST(NULL AS STRING) AS customer_billed_current_month_flag
FROM tmp_data_dm.coe_jrr_backfill_customer_mrr old
WHERE old.year_month < 201510

----
Comparison queries

  (
  SELECT 'Off is official MRR' AS off_table_type, *
  FROM dm.mrr_customer_category_all_products
  WHERE yearmonth = 201609
    AND mrr_customer_category <> 'NOT BILLED'
  ) off


DROP TABLE tmp_data_dm.coe_jrr_compare ;
CREATE TABLE tmp_data_dm.coe_jrr_compare AS
SELECT
   IFNULL(new.customer_id, off.customer_id) AS  cons_customer_id
  ,IFNULL(new.yearmonth, off.yearmonth) AS    cons_year_month
  ,CASE WHEN new.customer_id IS NULL AND 
             off.mrr_customer_category IN ('ACQUIRED', 'CHURNED', 'NO ACTIVITY') AND
             off.mrr_current_total = 0 AND off.revenue_current_total = 0  THEN 'OK: Free non-ads'
        WHEN new.mrr_customer_category = 'DOWNSIZED' AND off.mrr_customer_category = 'NO ACTIVITY' AND
             new.mrr_current_total = 0 THEN 'OK: downsized to 0'
        WHEN new.customer_id IS NULL OR off.customer_id IS NULL THEN 'Customer mismatch'
        WHEN new.mrr_customer_category <> off.mrr_customer_category THEN 'Category mismatch'
        WHEN new.mrr_current_total = off.mrr_current_total THEN 'OK' 
        WHEN ((new.mrr_current_total / off.mrr_current_total) - 1 BETWEEN -.0001 AND .0001) THEN 'OK' 
        WHEN (new.mrr_current_total <> off.mrr_current_total) AND 
             (off.mrr_current_total <> 0) AND 
             ((new.mrr_current_total / off.mrr_current_total) - 1 BETWEEN -.01 AND .01) THEN 'MRR close but no cigar' 
        ELSE 'MRR mismatch' END AS is_exception
  ,off.mrr_customer_category AS                off_mrr_customer_category
  ,new.mrr_customer_category AS                new_mrr_customer_category
  ,(new.mrr_current_total / off.mrr_current_total) - 1 AS                          mrr_var
  ,IFNULL(new.mrr_current_total, 0) - IFNULL(off.mrr_current_total, 0) AS          mrr_diff
  ,IFNULL(new.revenue_current_total, 0) - IFNULL(off.revenue_current_total, 0) AS  revenue_diff
  ,IFNULL(new.mrr_churned, 0) - IFNULL(off.mrr_churned, 0) AS                      mrr_churned_diff
  ,new.mrr_current_total AS                    new_mrr_current_total
  ,new.revenue_current_total AS                new_revenue_current_total
  ,new.mrr_churned AS                          new_mrr_churned
  ,new.mrr_prior_total AS                      new_mrr_prior_total
  ,off.mrr_current_total AS                    off_mrr_current_total
  ,off.revenue_current_total AS                off_revenue_current_total
  ,off.mrr_churned AS                          off_mrr_churned
  -- ,new.mrr_customer_exception AS               new_mrr_customer_exception
  ,new.is_active_during_month AS               new_is_active_during_month
  ,new.is_active_eom AS                        new_is_active_eom
  ,new.has_ads_during_month AS                 new_has_ads_during_month
  ,new.has_ads_eom AS                          new_has_ads_eom
  ,CASE WHEN new.mrr_current_total <> 0 THEN 'Y' ELSE 'N' END AS new_has_nonzero_mrr
  ,CASE WHEN off.mrr_current_total <> 0 THEN 'Y' ELSE 'N' END AS off_has_nonzero_mrr
  ,off.is_active_during_month AS               off_is_active_during_month
  ,off.is_active_eom AS                        off_is_active_eom
  ,off.has_ads_during_month AS                 off_has_ads_during_month
  ,off.has_ads_eom AS                          off_has_ads_eom
  ,new.tenure_month_lifetime AS                new_tenure_month_lifetime
  ,new.start_month_lifetime AS                 new_start_month_lifetime
  ,new.start_month_begin_date_lifetime AS      new_start_month_begin_date_lifetime
  ,off.tenure_month_lifetime AS                off_tenure_month_lifetime
  ,off.start_month_lifetime AS                 off_start_month_lifetime
  -- ,off.start_month_begin_date_lifetime AS      off_start_month_begin_date_lifetime
  -- ,new.customer_exists_prior_month AS          new_customer_exists_prior_month
  ,new.customer_id AS                          new_customer_id
  ,new.yearmonth AS                           new_year_month
  -- ,new.chain_number AS                         new_chain_number
  -- ,new.tenure_month_chain AS                   new_tenure_month_chain
  -- ,new.active_months_to_date AS                new_active_months_to_date
  -- ,new.start_month_chain AS                    new_start_month_chain
  -- ,new.first_payment_month AS                  new_first_payment_month
  -- ,new.had_payment AS                          new_had_payment
  -- ,new.max_bill_date_in_month AS               new_max_bill_date_in_month
  ,new.revenue_current_advertisement AS        new_revenue_current_advertisement
  ,new.revenue_current_avvopro AS              new_revenue_current_avvopro
  ,new.revenue_current_ignite AS               new_revenue_current_ignite
  ,new.revenue_current_website AS              new_revenue_current_website
  ,new.revenue_current_adplacement AS          new_revenue_current_adplacement
  ,new.revenue_current_misc AS                 new_revenue_current_misc
  -- ,new.revenue_current_other_sub AS            new_revenue_current_other_sub
  -- ,new.revenue_current_other AS                new_revenue_current_other
  ,new.mrr_current_advertisement AS            new_mrr_current_advertisement
  ,new.mrr_current_avvopro AS                  new_mrr_current_avvopro
  ,new.mrr_current_ignite AS                   new_mrr_current_ignite
  ,new.mrr_current_website AS                  new_mrr_current_website
  ,new.mrr_current_adplacement AS              new_mrr_current_adplacement
  -- ,new.mrr_current_other_sub AS                new_mrr_current_other_sub
  -- ,new.tenure_month_prev AS                    new_tenure_month_prev
  -- ,new.is_active_during_month_prior AS         new_is_active_during_month_prior
  -- ,new.is_active_eom_prior AS                  new_is_active_eom_prior
  -- ,new.had_payment_prior AS                    new_had_payment_prior
  -- ,new.has_ads_during_month_prior AS           new_has_ads_during_month_prior
  -- ,new.has_ads_eom_prior AS                    new_has_ads_eom_prior
  ,new.mrr_prior_advertisement AS              new_mrr_prior_advertisement
  ,new.mrr_prior_avvopro AS                    new_mrr_prior_avvopro
  ,new.mrr_prior_ignite AS                     new_mrr_prior_ignite
  ,new.mrr_prior_website AS                    new_mrr_prior_website
  ,new.mrr_prior_adplacement AS                new_mrr_prior_adplacement
  ,new.mrr_prior_other_sub AS                  new_mrr_prior_other_sub
  ,new.mrr_acquired AS                         new_mrr_acquired
  ,new.mrr_penetrated AS                       new_mrr_penetrated
  ,new.mrr_downsized AS                        new_mrr_downsized
  ,new.mrr_retained AS                         new_mrr_retained
  ,new.mrr_returned AS                         new_mrr_returned
  ,new.mrr_retained_subset_flat_customers AS   new_mrr_retained_subset_flat_customers
  ,new.mrr_retained_subset_delta_customers AS  new_mrr_retained_subset_delta_customers
  -- ,new.has_had_payment_lifetime AS             new_has_had_payment_lifetime
  ,off.customer_id AS                         off_customer_id
  ,off.yearmonth AS                          off_year_month
  ,off.mrr_current_advertisement AS           off_mrr_current_advertisement
  ,off.mrr_current_avvopro AS                 off_mrr_current_avvopro
  ,off.mrr_current_ignite AS                  off_mrr_current_ignite
  ,off.mrr_current_website AS                 off_mrr_current_website
  ,off.mrr_current_adplacement AS             off_mrr_current_adplacement
  ,off.mrr_prior_advertisement AS             off_mrr_prior_advertisement
  ,off.mrr_prior_avvopro AS                   off_mrr_prior_avvopro
  ,off.mrr_prior_ignite AS                    off_mrr_prior_ignite
  ,off.mrr_prior_website AS                   off_mrr_prior_website
  ,off.mrr_prior_adplacement AS               off_mrr_prior_adplacement
  ,off.mrr_prior_total AS                     off_mrr_prior_total
  ,off.revenue_current_advertisement AS       off_revenue_current_advertisement
  ,off.revenue_current_avvopro AS             off_revenue_current_avvopro
  ,off.revenue_current_ignite AS              off_revenue_current_ignite
  ,off.revenue_current_website AS             off_revenue_current_website
  ,off.revenue_current_misc AS                off_revenue_current_misc
  ,off.revenue_current_adplacement AS         off_revenue_current_adplacement
  ,off.mrr_acquired AS                        off_mrr_acquired
  ,off.mrr_penetrated AS                      off_mrr_penetrated
  ,off.mrr_downsized AS                       off_mrr_downsized
  ,off.mrr_retained AS                        off_mrr_retained
  ,off.mrr_returned AS                        off_mrr_returned
  ,off.mrr_retained_subset_flat_customers AS  off_mrr_retained_subset_flat_customers
  ,off.mrr_retained_subset_delta_customers AS off_mrr_retained_subset_delta_customers
  ,new.new_table_type
  ,off.off_table_type
  ,1 AS customers
FROM 
  (
  SELECT 'New is hack view' AS new_table_type, *
  FROM tmp_data_dm.mrr_customer_category_union_backfill
  WHERE yearmonth = 201609
    AND mrr_customer_category <> 'NOT BILLED'
  ) new
FULL OUTER JOIN 
  (
  SELECT 'Off is backfill' AS off_table_type, year_month AS yearmonth, *
  FROM tmp_data_dm.coe_jrr_backfill_customer_mrr
  WHERE year_month = 201609
    AND mrr_customer_category <> 'NOT BILLED'
  ) off
        ON new.customer_id = off.customer_id
       AND new.yearmonth = off.yearmonth
;

select * from tmp_data_dm.coe_jrr_compare
where is_exception NOT LIKE 'OK%'
OR ABS(mrr_diff) > 0.01
OR ABS(revenue_diff) > 0.01
OR ABS(mrr_churned_diff) > 0.01
ORDER BY cons_customer_id, cons_year_month
;

Oh duh I didn''t change the definitions yet!
OK what changes?
Do the MRR amounts change because of Active as of EOM?
mrr_customer_category changes.
So some of the mrr category metrics change.

I have cases where new_mrr_churned > 0.  Not any more.
official category is penetrated, new category is churned.
And also cases where they churned, and probably should have churned MRR but don''t.
OK yep it is because official mrr counts mrr that i don''t count?
Maybe I want to look at these customers in the backfill data.

1. I messed up the value of churned MRR.  Think it is fixed now.
2. Test this with backfill vs. hack.

Probably later get rid of all tenure-related fields.
Right now, they are helping me diagnose.

- OK one problem is I can''t use customer_exists_prior_month from the
  official mrr table because it is including free pro.
  Let me see how much that affects.

- Lotsa fields where backfill thinks they are active at eom, but hack
  code does not.
  So hack code thinks they churned but backfill thinks it is a downsize.
  Did the cancel date get updated retroactively in olaf?
  Backfill code is correct (or at least matches mrr_customer_category_all_products).

-- I think this is a bug in my backfill code:
--         ,GREATEST(CASE WHEN olaf.order_line_cancelled_date = '-1' THEN NULL ELSE olaf.order_line_cancelled_date END
--                  ,mrr.expired_date) AS max_expired_date
-- ... because if they have some expired subs but not all are expired,
-- this will grab the last expired ones because unexpired show up as null.
-- Wait no.  Backfill DOES think they are active at EoM.  Hack does not.
And I don''t know why backfill code gets it right.
OH!!! GREATEST returns NULL if any arg is NULL.

OK here it is.
Official MRR code tests exp is not null to determine churned (which would be true if ANY expired?),
but it does NOT look at exp date is null to determine other
categories.
Oh no actually NO ACTIVITY checks exp date is null. (which is wrong given that they are doing a max())
Ah and the reason this does not affect other categories is offical MRR does not check EoM status.
ok so cap.expired_date is the result of a MAX, so if there are some 
subs that expired and some that did not it is not null, it is a date in the month.
Oh good in backfill code, I look at exp date for each sub, so do not use
a max because for each sub I need to know if it continues past month.
Later I do a max of that (Y/N) but that is fine because I have already worked around the NULLs.

My hack is_active_eom check is:
      ,CASE WHEN ((cap.ad_current_count > 0 OR cap.mrr_current_total > 0) AND cap.expired_date IS NULL)
I am not sure that I can correctly tell is_active_eom from mrr_customer_all_products.  Nope.


Possible bugs in current code (tiny effect for current definitions; affects new code a lot):
- cap.ad_current_count is never 0 if customer was billed in the month
  because it is a count of a count, so inner count may return 0 but then
  the outer count counts non-null values and sees a 0 which is not null
  so returns 1.
- cap.expired_date is the result of a MAX, so if there are some 
  subs that expired and some that did not it is not null, it is a date in the month.
  This means that we may think all subscriptions expirred when they didn''t.
