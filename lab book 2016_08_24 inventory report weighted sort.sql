  ,CASE WHEN cmi.value = 0 THEN 0 ELSE cmi.revenue / cmi.value END AS  monetization

ETV essentially says this – if the count column of the sort 
(in this case, Potential Value) is very low, assume that the column of 
interest (Monetization) is roughly the average for the data in 
question. In other words, if a row has Potential Value = $1 and the average 
Monetization is 75%, then set the ETV of Monetization for that row 
to 75%. Since Potential Value of $1 is not enough, statistically speaking, to 
make any real conclusions, we will essentially ignore it.
On the other end of the spectrum, if you have very high Potential Value, 
assume the Monetization is accurate as is.

PV = Potential Value for Row X
M = Monetization for Row X
MPV = Max Potential Value for the data set
AM = Average (mean) Monetization for the data set
For any given row, the ETV of Monetization – ETV(M) – can be represented by the following equation:
ETV(M) = (PV / MPV * M) + ((1 - (PV / MPV)) * AM)

In this formula, average monetization is not calculated as SUM/SUM,
it is the average of the resulting monetization numbers.
Oh actually, he does it both ways, and recommends weighted (SUM/SUM).

If the range of Potential Value is too big, could use log(PV).


-- Very likely all markets
DROP TABLE tmp_data_dm.coe_market_intell;
CREATE TABLE tmp_data_dm.coe_market_intell AS
SELECT
   year_month
  ,ad_market_id
  ,state
  ,county
  ,ad_region
  ,parent_sp AS            parent_pa
  ,specialty AS            practice_area
  ,market_type AS          inventory_type
  ,lawyer_cnt              -- Lawyers that we know for sure are in the market
  ,potential_lawyer_cnt    -- lawyer_cnt + estimated portion of lawyers in the geo whose pa we do not know
  ,lawyer_claimed_cnt
  ,county_claim_rate
  ,sl_subscription_price
  ,sl_price
  ,sl_inventory AS         sl_inventory_units
  ,sl_sold_inventory AS    sl_sold_inventory_units
  ,sl_value
  ,sl_sold_value
  ,sl_revenue

  ,da_price
  ,da_inventory AS         da_inventory_units
  ,da_sold_inventory AS    da_sold_inventory_units
  ,da_value
  ,da_sold_value
  ,da_revenue
FROM dm.market_intelligence_detail
WHERE year_month = 201607
-- SELECT * FROM tmp_data_dm.coe_market_intell


ETV(M) = (PV / MPV * M) + ((1 - (PV / MPV)) * AM)

OK since value can vary from 1 to 200K, log works much better.
As for whether simple or weighted average is better,
kinda depends on how we think about monetization.


DROP TABLE tmp_data_dm.coe_market_intell_unrolled;
CREATE TABLE tmp_data_dm.coe_market_intell_unrolled AS
SELECT
   qry.*
  ,   (     (qry.value / qry.value_max)  * qry.monetization)
    + ((1 - (qry.value / qry.value_max)) * qry.monetization_simple_avg) AS etv_mon_simple
  ,   (     (qry.value / qry.value_max)  * qry.monetization)
    + ((1 - (qry.value / qry.value_max)) * qry.monetization_weighted_avg) AS etv_mon_weighted
  ,   (     (LOG2(qry.value) / LOG2(qry.value_max))  * qry.monetization)
    + ((1 - (LOG2(qry.value) / LOG2(qry.value_max))) * qry.monetization_simple_avg) AS etv_mon_log_simple
  ,   (     (LOG2(qry.value) / LOG2(qry.value_max))  * qry.monetization)
    + ((1 - (LOG2(qry.value) / LOG2(qry.value_max))) * qry.monetization_weighted_avg) AS etv_mon_log_weighted
FROM
  (
  SELECT
     mon.*
    ,AVG(mon.monetization) OVER() AS  monetization_simple_avg
    ,MAX(mon.value) OVER() AS         value_max
    ,SUM(mon.value) OVER() AS         value_sum    -- LOOK probably do not need later
    ,SUM(mon.revenue) OVER() AS       revenue_sum  -- LOOK probably do not need later
    ,CASE WHEN SUM(mon.value) OVER() = 0 THEN SUM(mon.value) OVER()
            ELSE SUM(mon.revenue) OVER() / SUM(mon.value) OVER() END AS monetization_weighted_avg
  FROM
    (
    SELECT
       unr.*
      ,CASE WHEN unr.value = 0 THEN 0 ELSE unr.revenue / unr.value END AS  monetization
    FROM
      (
      SELECT
         cmi.year_month
        ,cmi.ad_market_id
        ,ats.ad_type
        ,mkt.ad_market_state_name AS   state
        ,mkt.ad_market_county_name AS  county
        ,mkt.ad_market_region_name AS  ad_region
        ,pa.parent_specialty_name AS   parent_pa
        ,pa.specialty_name AS          practice_area
        ,cmi.inventory_type
        ,lawyer_cnt              -- Lawyers that we know for sure are in the market
        ,potential_lawyer_cnt    -- lawyer_cnt + estimated portion of lawyers in the geo whose pa we do not know
        ,lawyer_claimed_cnt
        ,county_claim_rate
        ,CASE WHEN ats.ad_type = 'Display' THEN NULL                    ELSE sl_price                END AS sl_subscription_price
        ,CASE WHEN ats.ad_type = 'Display' THEN da_price                ELSE sl_price                END AS price
        ,CASE WHEN ats.ad_type = 'Display' THEN da_inventory_units      ELSE sl_inventory_units      END AS inventory_units
        ,CASE WHEN ats.ad_type = 'Display' THEN da_sold_inventory_units ELSE sl_sold_inventory_units END AS sold_inventory_units
        ,CASE WHEN ats.ad_type = 'Display' THEN da_value                ELSE sl_value                END AS value
        ,CASE WHEN ats.ad_type = 'Display' THEN da_sold_value           ELSE sl_sold_value           END AS sold_value
        ,CASE WHEN ats.ad_type = 'Display' THEN da_revenue              ELSE sl_revenue              END AS revenue
      FROM              tmp_data_dm.coe_market_intell cmi
        LEFT OUTER JOIN dm.ad_market_dimension mkt ON cmi.ad_market_id = mkt.ad_market_id
        LEFT OUTER JOIN dm.specialty_dimension pa  ON mkt.specialty_id = pa.specialty_id 
        LEFT OUTER JOIN dm.ad_region_dimension reg ON mkt.ad_region_id = reg.ad_region_id
      CROSS JOIN
        (
        SELECT 'Display' AS ad_type
         UNION ALL
        SELECT 'Sponsored Listing' AS ad_type
        ) ats
      WHERE cmi.ad_market_id <> 88738  -- LOOK bad market for July
      ) unr
    ) mon
  ) qry
-- WHERE qry.ad_market_id % 1000 = 148
-- SELECT * FROM tmp_data_dm.coe_market_intell_unrolled

SELECT
   ad_market_id
  ,ad_type
  ,monetization
  ,etv_mon_simple
  ,etv_mon_weighted
  ,etv_mon_log_simple
  ,etv_mon_log_weighted
  ,monetization_simple_avg
  ,monetization_weighted_avg
  ,value_max
  ,value_sum
  ,revenue_sum
  ,year_month
  ,state
  ,county
  ,ad_region
  ,parent_pa
  ,practice_area
  ,inventory_type
  ,lawyer_cnt
  ,inventory_units
  ,sold_inventory_units
  ,value
  ,sold_value
  ,revenue
FROM tmp_data_dm.coe_market_intell_unrolled
WHERE state = 'Washington'

SELECT
   ad_market_id
  ,ad_type
  ,inventory_type
  ,monetization
  ,etv_mon_simple
  ,etv_mon_weighted
  ,etv_mon_log_simple
  ,etv_mon_log_weighted
  ,value
  ,revenue
FROM tmp_data_dm.coe_market_intell_unrolled


-- SELECT market_type, da_value, sl_value, count(*) as markets
-- FROM dm.market_intelligence_detail
-- WHERE year_month = 201607
-- GROUP BY 1,2,3

-- SELECT *
-- FROM dm.market_intelligence_detail
-- WHERE year_month = 201607
-- AND ((da_value > 1000) OR (sl_value > 1000))

-- ACU: SUM(email_attributed_count), SUM(website_attributed_count), SUM(phone_attributed_count)
-- ACV Delivered: SUM(adjusted_attribution_value)
-- Impressions Delivered: SUM(prof_market_total_impression_count)
-- Very likely all block markets w/ traffic.  LOOK inpressions data here is not reliable.  Overstated.
-- There is an email from Nadine that says pull from the ad weight table.
DROP TABLE tmp_data_dm.coe_market_waa;
CREATE TABLE tmp_data_dm.coe_market_waa AS
SELECT
   dt.year_month
  ,waa.ad_market_id
  ,CASE WHEN ad.ad_detail_type LIKE 'Display%' THEN 'Display' ELSE ad.ad_detail_type END as ad_type
  ,SUM(waa.ad_click_count) AS                      ad_click_count
  ,SUM(waa.ad_click_value) AS                      ad_click_value
  ,SUM(waa.email_attributed_count) AS              email_acu  -- want this one.  LOOK!!! need to multiply this by 2.
  ,SUM(waa.email_attributed_value) AS              email_attributed_value
  ,SUM(waa.website_attributed_count) AS            website_acu  -- want this one.
  ,SUM(waa.website_attributed_value) AS            website_attributed_value
  ,SUM(waa.phone_attributed_count) AS              phone_acu  -- want this one.
  ,SUM(waa.phone_attributed_value) AS              phone_attributed_value
  ,SUM(waa.serp_headshot_count) AS                 serp_headshot_count
  ,SUM(waa.non_serp_headshot_count) AS             non_serp_headshot_count
  ,SUM(waa.weighted_headshot_impression) AS        weighted_headshot_impression
  ,SUM(waa.adjusted_attribution_value) AS          avc_delivered  -- want this one.  This is total minus organic.
FROM dm.webanalytics_ad_attribution_v0 waa
  INNER JOIN dm.date_dim dt
          ON waa.attribution_date = dt.actual_date
         AND dt.year_month = 201607
  LEFT OUTER JOIN dm.ad_dimension ad ON waa.ad_id = ad.ad_id
GROUP BY 1,2,3
-- SELECT * FROM tmp_data_dm.coe_market_waa

-- Hmmm.  From conversation w/ Rahul, I might want to take the first 
-- August record, since then m1 will contain July.
-- SELECT
--    process_date
--   ,COUNT(*) AS num_rows
-- FROM dm.tomahawk
-- WHERE process_date BETWEEN '2016-08-01' AND '2016-08-31'
-- GROUP BY 1 ORDER BY 1

-- Market appears if they have had any pageviews in past 3 calendar months plus current month to date.
DROP TABLE tmp_data_dm.coe_market_tom;
CREATE TABLE tmp_data_dm.coe_market_tom AS
SELECT
   cmi.year_month
  ,cmi.ad_market_id
  ,cmi.ad_type
   -- final_potacv_ values are the inventory value.
   -- For block markets, it’s 1 slot.
   -- For exclusive, it’s 3 slots so have to take the final_potacv_ field and divide by 3.
   -- For exclusive markets, no matter final potential value for Display was, we ignore that and set it to the 1-slot SL price.
   -- For block markets, the prices for Display and SL are independent.  We try to never change them.
  ,CASE WHEN cmi.ad_type =  'Display' AND cmi.inventory_type = 'Block' THEN final_potacv_for_da_blocks
        WHEN cmi.ad_type =  'Display' AND cmi.inventory_type = 'Exclusive' THEN final_potacv_for_da_exclusive / 3.0
        WHEN cmi.ad_type <> 'Display' AND cmi.inventory_type = 'Block' THEN final_potacv_for_sl_blocks
        ELSE final_potacv_for_sl_exclusive / 3.0
   END AS                                                                                          tom_inventory_avc
  ,CASE WHEN cmi.ad_type =  'Display' AND cmi.inventory_type = 'Block' THEN final_potacv_for_da_blocks
        WHEN cmi.ad_type =  'Display' AND cmi.inventory_type = 'Exclusive' THEN final_potacv_for_sl_exclusive / 3.0
        WHEN cmi.ad_type <> 'Display' AND cmi.inventory_type = 'Block' THEN final_potacv_for_sl_blocks
        ELSE final_potacv_for_sl_exclusive / 3.0
   END AS                                                                                          tom_inventory_avc_with_excl_display_logic
  ,CASE WHEN cmi.inventory_type = 'Exclusive' THEN NULL
        WHEN cmi.ad_type =  'Display' THEN da_total_block_recommendation
        ELSE                               sl_total_block_recommendation
   END AS                                                                                          tom_total_block_recommendation
  ,CASE WHEN cmi.inventory_type = 'Exclusive' THEN NULL
        WHEN cmi.ad_type =  'Display' THEN da_total_released
        ELSE                               sl_total_released
   END AS                                                                                          tom_total_block_released
  ,CASE WHEN cmi.inventory_type = 'Exclusive' THEN NULL
        WHEN cmi.ad_type =  'Display' THEN da_total_sold
        ELSE                               sl_total_sold
   END AS                                                                                          tom_total_block_sold
  ,CASE WHEN cmi.ad_type = 'Display' THEN da_business_rule ELSE sl_business_rule END AS            tom_business_rule
  ,CASE WHEN cmi.ad_type = 'Display' THEN da_review_reason ELSE sl_review_reason END AS            tom_review_reason
  ,CASE WHEN cmi.inventory_type = 'Exclusive' THEN NULL
        WHEN cmi.ad_type =  'Display' THEN backorder_da_blocks
        ELSE                               backorder_sl_blocks
   END AS                                                                                          tom_backorder_blocks
  ,CASE WHEN cmi.inventory_type = 'Exclusive' THEN current_exclusiveprice ELSE blockprice END AS   tom_current_price
  ,CASE WHEN cmi.inventory_type = 'Block' THEN NULL
        WHEN cmi.ad_type =  'Display' THEN da_exclusive_price_recommended
        ELSE                               sl_exclusive_price_recommended
   END AS                                                                                          tom_exclusive_recommended_price
  ,CASE WHEN cmi.ad_type = 'Display' THEN da_advertiser_count             ELSE sl_advertiser_count             END AS  tom_advertisers
  ,CASE WHEN cmi.ad_type = 'Display' THEN da_max_advertiser_acv           ELSE sl_max_advertiser_acv           END AS  tom_max_advertiser_acv
  ,CASE WHEN cmi.ad_type = 'Display' THEN da_potential_imps_other_month_1 ELSE sl_potential_imps_other_month_1 END AS  tom_potential_imps_other_month_1
  ,CASE WHEN cmi.ad_type = 'Display' THEN da_potential_imps_sem_month_1   ELSE sl_potential_imps_sem_month_1   END AS  tom_potential_imps_sem_month_1
  ,CASE WHEN cmi.ad_type = 'Display' THEN da_clicks_other_month_1         ELSE sl_clicks_other_month_1         END AS  tom_clicks_other_month_1
  ,CASE WHEN cmi.ad_type = 'Display' THEN da_clicks_sem_month_1           ELSE sl_clicks_sem_month_1           END AS  tom_clicks_sem_month_1
  ,CASE WHEN cmi.ad_type = 'Display' THEN da_imps_other_month_1           ELSE sl_imps_other_month_1           END AS  tom_imps_other_month_1
  ,CASE WHEN cmi.ad_type = 'Display' THEN da_imps_sem_month_1             ELSE sl_imps_sem_month_1             END AS  tom_imps_sem_month_1
FROM              tmp_data_dm.coe_market_intell_unrolled cmi
  INNER JOIN dm.tomahawk tom
          ON cmi.ad_market_id = tom.marketid
         AND tom.process_date = '2016-08-02'  -- LOOK change this when date range changes.
-- SELECT * FROM tmp_data_dm.coe_market_tom


----
-- Hand-rolled metrics

-- Note: previous version did entire-quarter MRR deltas.  This is month.

DROP TABLE tmp_data_dm.coe_market_mrr;
CREATE TABLE tmp_data_dm.coe_market_mrr AS
SELECT
   mrr.yearmonth AS                                   year_month
  ,mrr.market_id AS                                   ad_market_id
  ,CASE WHEN sub.ad_type LIKE 'Dis%' THEN 'Display'
        WHEN sub.ad_type LIKE 'Spo%' THEN 'Sponsored Listing'
        ELSE 'Unknown Ad Type'
   END AS                                             ad_type
  ,SUM(mrr.mrr_prior_month) AS                        beginning_mrr
  ,SUM(mrr.mrr_acquired + mrr.mrr_penetrated) AS      mrr_up
  ,SUM(mrr.mrr_churned + mrr.mrr_downsized) AS        mrr_down
  ,SUM(mrr.mrr_current_month) AS                      ending_mrr
  ,COUNT(DISTINCT CASE WHEN IFNULL(mrr.customer_category, 'CHURNED') NOT IN ('CHURNED', 'NO ACTIVITY') 
                         THEN mrr.customer_id ELSE NULL END) AS  ending_customers
  ,COUNT(*) AS                                        aggregate_num_subs
FROM         dm.mrr_subscription_classification mrr
 LEFT OUTER JOIN dm.subscription_dimension sub ON mrr.subscription_id = sub.subscription_id
WHERE mrr.yearmonth = 201607
  AND (sub.ad_type LIKE 'Dis%' OR sub.ad_type LIKE 'Spo%')
GROUP BY 1,2,3
-- SELECT * FROM tmp_data_dm.coe_market_mrr


DROP TABLE tmp_data_dm.coe_market_targets;
CREATE TABLE tmp_data_dm.coe_market_targets AS
SELECT
   tgt.year_month
  ,tgt.ad_market_id
  ,CASE WHEN ad.ad_detail_type LIKE 'Dis%' THEN 'Display'
        WHEN ad.ad_detail_type LIKE 'Spo%' THEN 'Sponsored Listing'
        ELSE 'Unknown Ad Type'
   END AS                             ad_type
  ,SUM(tgt.target_impression_cnt) AS  target_impressions
FROM         dm.profnl_target_impressions tgt
  LEFT OUTER JOIN dm.ad_dimension ad ON tgt.ad_id = ad.ad_id
WHERE tgt.year_month = 201607
  AND ad.ad_detail_type LIKE 'Dis%' OR ad.ad_detail_type LIKE 'Spo%'
GROUP BY 1,2,3
-- SELECT * FROM tmp_data_dm.coe_market_targets

DROP TABLE tmp_data_dm.coe_market_res;
CREATE TABLE tmp_data_dm.coe_market_res AS
SELECT
   cmi.year_month
  ,cmi.ad_market_id
  ,cmi.ad_type
  ,cmi.state
  ,cmi.county
  ,cmi.ad_region
  ,cmi.parent_pa
  ,cmi.practice_area
  ,cmi.inventory_type
  ,CASE WHEN waa.ad_market_id IS NULL THEN 'No impression data' ELSE 'Has impression data' END AS  has_imp_data
  ,CASE WHEN mrr.ad_market_id IS NULL THEN 'No mrr data' ELSE 'Has mrr data' END AS                has_mrr_data
  ,CASE WHEN tom.ad_market_id IS NULL THEN 'No tomahawk data' ELSE 'Has tomahawk data' END AS      has_tom_data
  ,CASE WHEN tom.ad_market_id IS NULL THEN 'No target imp data' ELSE 'Has target imp data' END AS  has_tgt_data
  ,cmi.lawyer_cnt
  ,cmi.potential_lawyer_cnt
  ,cmi.lawyer_claimed_cnt
  ,cmi.county_claim_rate
  ,cmi.price
  ,cmi.inventory_units
  ,cmi.sold_inventory_units
  ,cmi.value
  ,cmi.sold_value
  ,cmi.revenue
  ,CASE WHEN cmi.value = 0 THEN 0 ELSE cmi.revenue / cmi.value END AS  monetization  -- LOOK
  ,IFNULL(CAST(waa.ad_click_count AS STRING), '') AS                ad_click_count
  ,IFNULL(CAST(waa.ad_click_value AS STRING), '') AS                ad_click_value
  ,IFNULL(CAST(waa.email_acu AS STRING), '') AS                     email_acu
  ,IFNULL(CAST(waa.email_attributed_value AS STRING), '') AS        email_attributed_value
  ,IFNULL(CAST(waa.website_acu AS STRING), '') AS                   website_acu
  ,IFNULL(CAST(waa.website_attributed_value AS STRING), '') AS      website_attributed_value
  ,IFNULL(CAST(waa.phone_acu AS STRING), '') AS                     phone_acu
  ,IFNULL(CAST(waa.phone_attributed_value AS STRING), '') AS        phone_attributed_value
  ,IFNULL(CAST(waa.serp_headshot_count AS STRING), '') AS           serp_headshot_count
  ,IFNULL(CAST(waa.non_serp_headshot_count AS STRING), '') AS       non_serp_headshot_count
  ,IFNULL(CAST(waa.weighted_headshot_impression AS STRING), '') AS  weighted_headshot_impression
  ,IFNULL(CAST(waa.avc_delivered AS STRING), '') AS                 avc_delivered
  ,IFNULL(CAST(tgt.target_impressions AS STRING), '') AS            target_impressions
  ,IFNULL(CAST(mrr.beginning_mrr AS STRING), '') AS       beginning_mrr
  ,IFNULL(CAST(mrr.mrr_up AS STRING), '') AS              mrr_up
  ,IFNULL(CAST(mrr.mrr_down AS STRING), '') AS            mrr_down
  ,IFNULL(CAST(mrr.ending_mrr AS STRING), '') AS          ending_mrr
  ,IFNULL(CAST(mrr.ending_customers AS STRING), '') AS    ending_customers
  ,IFNULL(CAST(mrr.aggregate_num_subs AS STRING), '') AS  aggregate_num_subs
  ,IFNULL(CAST(tom.tom_inventory_avc AS STRING), '') AS                          tom_inventory_avc
  ,IFNULL(CAST(tom.tom_inventory_avc_with_excl_display_logic AS STRING), '') AS  tom_inventory_avc_with_excl_display_logic
  ,IFNULL(CAST(tom.tom_total_block_recommendation AS STRING), '') AS             tom_total_block_recommendation
  ,IFNULL(CAST(tom.tom_total_block_released AS STRING), '') AS                   tom_total_block_released
  ,IFNULL(CAST(tom.tom_total_block_sold AS STRING), '') AS                       tom_total_block_sold
  ,IFNULL(CAST(tom.tom_backorder_blocks AS STRING), '') AS                       tom_backorder_blocks
  ,IFNULL(CAST(tom.tom_current_price AS STRING), '') AS                          tom_current_price
  ,IFNULL(CAST(tom.tom_exclusive_recommended_price AS STRING), '') AS            tom_exclusive_recommended_price
FROM              tmp_data_dm.coe_market_intell_unrolled cmi
  LEFT OUTER JOIN tmp_data_dm.coe_market_waa waa
          ON cmi.year_month = waa.year_month
         AND cmi.ad_market_id = waa.ad_market_id
         AND cmi.ad_type = waa.ad_type
  LEFT OUTER JOIN tmp_data_dm.coe_market_mrr mrr
          ON cmi.year_month = mrr.year_month
         AND cmi.ad_market_id = mrr.ad_market_id
         AND cmi.ad_type = mrr.ad_type
  LEFT OUTER JOIN tmp_data_dm.coe_market_tom tom
          ON cmi.year_month = tom.year_month
         AND cmi.ad_market_id = tom.ad_market_id
         AND cmi.ad_type = tom.ad_type
  LEFT OUTER JOIN tmp_data_dm.coe_market_targets tgt
          ON cmi.year_month = tgt.year_month
         AND cmi.ad_market_id = tgt.ad_market_id
         AND cmi.ad_type = tgt.ad_type
-- SELECT * FROM tmp_data_dm.coe_market_res
-- WHERE county LIKE 'San Francisco%'
