From Cameron''s mockup:

In hist_market_intelligence_detail:
Market ID
Ad Region
State
DA Inventory
DA Price
DA Sold Inventory
DA Inventory Revenue
SL Inventory
SL Price
SL Sold Inventory
SL Inventory Revenue
# of Customers
# of Claimed attorneys
Ad Inventory Type
Parent PA
PA
-- Flag for obscure specialty

In webanalytics_ad_attribution_v0:
ACU: SUM(email_attributed_count), SUM(website_attributed_count), SUM(phone_attributed_count)
ACV Delivered: SUM(adjusted_attribution_value)
Impressions Delivered: SUM(prof_market_total_impression_count)

Questions webanalytics_ad_attribution_v0:
Is there one row per professional_id, ad_market_id, attribution_date, page_type??
My guess is that ad_market_total_impression_count would be the same for all professionals in that market on that day, right?
Does not look like it.
Is it only block markets?
What is the difference between associated counts, non-associated counts, and attributed counts?
Looks like assoc + non-assoc = attributed?  Yes.
Assoc means it is associated with an ad.

Elsewhere:
Cancels in last 90 days - churned subscriptions in that market
ACV Target - might be simple to get from deferred_revenue.  - nice to have.
# of active professionals
# of active customers
profnl_target_impressions also exists which will give it to you by month (ignore etl_load_date in that one)

CAMERON: not just block markets? right, but if that's all that's available phase 1 maybe ok.

----

SELECT
   year_month
  ,SUM(ad_value) AS            ad_value
  ,SUM(ad_sold_value) AS       ad_sold_value
  ,SUM(ad_revenue) AS          ad_revenue
FROM tmp_data_dm.coe_ad_market_detail_rows
WHERE year_month = 201603
GROUP BY 1 ORDER BY 1

SELECT
   year_month
  ,SUM(ad_inventory_value) AS            ad_inventory_value
  ,SUM(ad_sold_inventory_value) AS       ad_sold_inventory_value
  ,SUM(ad_revenue) AS          ad_revenue
FROM tmp_data_dm.coe_ad_market_detail_v2
GROUP BY 1 ORDER BY 1


SELECT
   year_month
  ,market_type
  ,SUM(da_value) AS            da_value
  ,SUM(da_inventory) AS        da_inventory
  ,SUM(da_price) AS            da_price
  ,SUM(da_sold_value) AS       da_sold_value
  ,SUM(da_revenue) AS          da_revenue
  ,SUM(sl_value) AS            sl_value
  ,SUM(sl_inventory) AS        sl_inventory
  ,SUM(sl_price) AS            sl_price
  ,SUM(sl_sold_value) AS       sl_sold_value
  ,SUM(sl_revenue) AS          sl_revenue
FROM tmp_data_dm.coe_ad_market_detail
WHERE year_month = 201603
GROUP BY 1,2 ORDER BY 1,2

SELECT
   year_month
  ,SUM(da_inventory_value) AS       da_inventory_value
  ,SUM(da_inventory_units) AS       da_inventory_units
  ,SUM(da_price) AS                 da_price
  ,SUM(da_sold_inventory_value) AS  da_sold_inventory_value
  ,SUM(da_revenue) AS               da_revenue
  ,SUM(sl_inventory_value) AS       sl_inventory_value
  ,SUM(sl_inventory_units) AS       sl_inventory_units
  ,SUM(sl_price) AS                 sl_price
  ,SUM(sl_sold_inventory_value) AS  sl_sold_inventory_value
  ,SUM(sl_revenue) AS               sl_revenue
FROM tmp_data_dm.coe_ad_market_detail_v2
GROUP BY 1 ORDER BY 1

SELECT
   year_month
  ,market_type
  ,SUM(da_inventory_value) AS       da_inventory_value
  ,SUM(da_inventory_units) AS       da_inventory_units
  ,SUM(da_price) AS                 da_price
  ,SUM(da_sold_inventory_value) AS  da_sold_inventory_value
  ,SUM(da_revenue) AS               da_revenue
  ,SUM(sl_inventory_value) AS       sl_inventory_value
  ,SUM(sl_inventory_units) AS       sl_inventory_units
  ,SUM(sl_price) AS                 sl_price
  ,SUM(sl_sold_inventory_value) AS  sl_sold_inventory_value
  ,SUM(sl_revenue) AS               sl_revenue
FROM tmp_data_dm.coe_ad_market_detail_v2
GROUP BY 1,2 ORDER BY 1,2

----

DROP TABLE tmp_data_dm.coe_explore_contacts;
CREATE TABLE tmp_data_dm.coe_explore_contacts AS
SELECT
   imp.year_month
  ,imp.contact_type
  ,IFNULL(ord.has_ads, 'N') AS        has_ads
  ,IFNULL(ord.is_net_paying, 'N') AS  is_net_paying
  ,SUM(imp.contacts) AS               contacts
FROM
    (
    SELECT
       dt.year_month
      ,ci.professional_id
      ,ci.contact_type
      ,COUNT(*) AS contacts
    FROM src.contact_impression ci
      INNER JOIN dm.date_dim dt ON ci.event_date = dt.actual_date
    WHERE ci.event_date BETWEEN '2016-01-01' AND '2016-06-30'
    GROUP BY 1,2,3
    ) imp
  LEFT OUTER JOIN
    (
    SELECT
       dt.year_month
      ,olaf.professional_id
      ,MAX(CASE WHEN olaf.product_line_id IN (2,7) THEN 'Yes has ads' ELSE 'No ads' END) AS has_ads
      ,MAX(CASE WHEN olaf.order_line_net_price_amount_usd > 0 THEN 'Yes net paying' ELSE 'Not net paying' END) AS is_net_paying
    FROM dm.order_line_accumulation_fact olaf
      INNER JOIN dm.date_dim dt ON olaf.order_line_begin_date = dt.actual_date
    WHERE olaf.order_line_begin_date BETWEEN '2016-01-01' AND '2016-06-30'
    GROUP BY 1,2
    ) ord
   ON imp.professional_id = ord.professional_id
  AND imp.year_month = ord.year_month
GROUP BY 1,2,3,4
-- SELECT * FROM tmp_data_dm.coe_explore_contacts

SELECT market_type, sl_inventory_type, sl_price, sl_market_segment, da_inventory_type, da_price, da_market_segment, count(*) as num_rows
FROM dm.hist_market_intelligence_detail
WHERE etl_load_date = '2016-06-30'
GROUP BY 1,2,3,4,5,6,7

geo data
tmp_data_dm.Traffic_Internal_Full

  ,CASE WHEN specialty_id > 131 THEN 'Obscure' ELSE 'Normal' END AS is_obscure_practice_area
----

Notes about this data pull:

We always exclude practice areas with ID > 131, which are obscure 
practice areas, but if we are looking at what markets we could 
combine, wouldn''t we was to include them in the analysis?
Ah, they are not in the sales tool, so should have no customers.


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
WHERE year_month = 201606
-- SELECT * FROM tmp_data_dm.coe_market_intell

-- FROM dm.hist_market_intelligence_detail
  -- LOOK if we hit the hist table it should instead go on ETL date.

-- We can calculate these:
--   ,sl_revenue_opportunity  -- sl_value – sl_revenue
--   ,sl_breakage             -- sl_sold_value – sl_revenue
--   ,claim_rate              -- lawyer_claimed_cnt / lawyer_cnt
--   ,potential_claim_rate    -- lawyer_claimed_cnt / potential_lawyer_cnt

DROP TABLE tmp_data_dm.coe_market_intell_unrolled;
CREATE TABLE tmp_data_dm.coe_market_intell_unrolled AS
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

-- SELECT * FROM tmp_data_dm.coe_market_intell_unrolled


-- ACU: SUM(email_attributed_count), SUM(website_attributed_count), SUM(phone_attributed_count)
-- ACV Delivered: SUM(adjusted_attribution_value)
-- Impressions Delivered: SUM(prof_market_total_impression_count)
-- Very likely all block markets w/ traffic.  LOOK inpressions data here is not reliable.  Overstated.
-- There is an email from Nadine that says pull from the ad weight table.
DROP TABLE tmp_data_dm.coe_market_waa;
CREATE TABLE tmp_data_dm.coe_market_waa AS
SELECT
   201606 AS                                       year_month
  ,waa.ad_market_id
  ,CASE WHEN ad.ad_detail_type LIKE 'Display%' THEN 'Display' ELSE ad.ad_detail_type END as ad_type
  ,SUM(waa.ad_click_count) AS                      ad_click_count
  ,SUM(waa.ad_click_value) AS                      ad_click_value
  ,SUM(waa.email_attributed_count) AS              email_acu  -- want this one.
  ,SUM(waa.email_attributed_value) AS              email_attributed_value
  ,SUM(waa.website_attributed_count) AS            website_acu  -- want this one.
  ,SUM(waa.website_attributed_value) AS            website_attributed_value
  ,SUM(waa.phone_attributed_count) AS              phone_acu  -- want this one.
  ,SUM(waa.phone_attributed_value) AS              phone_attributed_value
  -- ,SUM(waa.total_attributed_value) AS              total_attributed_value  -- Total ACV.  Includes value from organic.  Do not use.
  -- ,SUM(waa.ad_serp_impression_count) AS            ad_serp_impression_count
  -- ,SUM(waa.ad_non_serp_impression_count) AS        ad_non_serp_impression_count
  -- ,SUM(waa.ad_market_total_impression_count) AS    ad_market_total_impression_count  -- serp + non-serp
  -- ,SUM(waa.prof_market_total_impression_count) AS  impressions_delivered  -- want this one.
  -- ,SUM(waa.weighted_ad_impression_count) AS        weighted_ad_impression_count  -- LOOK what is this?
  ,SUM(waa.serp_headshot_count) AS                 serp_headshot_count
  ,SUM(waa.non_serp_headshot_count) AS             non_serp_headshot_count
  -- ,SUM(waa.total_headshot_count) AS                total_headshot_count  -- LOOK Is this always = serp + non?  Yes.
  ,SUM(waa.weighted_headshot_impression) AS        weighted_headshot_impression
  ,SUM(waa.adjusted_attribution_value) AS          avc_delivered  -- want this one.  This is total minus organic.
FROM dm.webanalytics_ad_attribution_v0 waa
  LEFT OUTER JOIN dm.ad_dimension ad ON waa.ad_id = ad.ad_id
WHERE attribution_date BETWEEN '2016-06-01' AND '2016-06-30'
GROUP BY 1,2,3
-- SELECT * FROM tmp_data_dm.coe_market_waa

-- Very likely all markets w/ traffic.

-- select * from dm.tomahawk
-- where marketid = 426
-- and process_date BETWEEN '2016-06-01' AND '2016-06-30'
Impressions data is as valid and reliable as we can make it, so yes, think of it as solid.
For blocks, the price is fixed, and it's per block. You'll find the block price in the column "blockprice".
Potential impressions is prediction of how many impressions we could get if we had enough ads sold.

Hmmm.  From conversation w/ Rahul, I might want to take the first July record, since then
m1 will contain June.
-- SELECT
--    sl_business_rule
--   ,da_business_rule
--   ,sl_review_reason
--   ,da_review_reason
--   ,COUNT(DISTINCT marketid)
-- FROM dm.tomahawk
-- WHERE process_date BETWEEN '2016-06-01' AND '2016-06-30'
-- (will have redundant rows for the same market)

-- SELECT
--    cmi.year_month
--   ,cmi.ad_market_id
--   ,cmi.ad_type
--   ,cmi.state
--   ,cmi.county
--   ,cmi.ad_region
--   ,cmi.parent_pa
--   ,cmi.practice_area
--   ,cmi.inventory_type
--   ,cmi.lawyer_cnt
--   ,cmi.potential_lawyer_cnt
--   ,cmi.lawyer_claimed_cnt
--   ,cmi.county_claim_rate
--   ,cmi.price
--   ,cmi.inventory_units
--   ,cmi.sold_inventory_units
--   ,cmi.value
--   ,cmi.sold_value
--   ,cmi.revenue
--   ,IFNULL(CAST(waa.ad_click_count AS STRING), '') AS                ad_click_count
--   ,IFNULL(CAST(waa.ad_click_value AS STRING), '') AS                ad_click_value
--   ,IFNULL(CAST(waa.email_acu AS STRING), '') AS                     email_acu
--   ,IFNULL(CAST(waa.email_attributed_value AS STRING), '') AS        email_attributed_value
--   ,IFNULL(CAST(waa.website_acu AS STRING), '') AS                   website_acu
--   ,IFNULL(CAST(waa.website_attributed_value AS STRING), '') AS      website_attributed_value
--   ,IFNULL(CAST(waa.phone_acu AS STRING), '') AS                     phone_acu
--   ,IFNULL(CAST(waa.phone_attributed_value AS STRING), '') AS        phone_attributed_value
--   ,IFNULL(CAST(waa.ad_serp_impression_count AS STRING), '') AS      ad_serp_impression_count
--   ,IFNULL(CAST(waa.ad_non_serp_impression_count AS STRING), '') AS  ad_non_serp_impression_count
--   ,IFNULL(CAST(waa.impressions_delivered AS STRING), '') AS         impressions_delivered
--   ,IFNULL(CAST(waa.weighted_ad_impression_count AS STRING), '') AS  weighted_ad_impression_count
--   ,IFNULL(CAST(waa.serp_headshot_count AS STRING), '') AS           serp_headshot_count
--   ,IFNULL(CAST(waa.non_serp_headshot_count AS STRING), '') AS       non_serp_headshot_count
--   ,IFNULL(CAST(waa.weighted_headshot_impression AS STRING), '') AS  weighted_headshot_impression
--   ,IFNULL(CAST(waa.avc_delivered AS STRING), '') AS                 avc_delivered
-- FROM              tmp_data_dm.coe_market_intell_unrolled cmi
--   LEFT OUTER JOIN tmp_data_dm.coe_market_waa waa
--           ON cmi.year_month = waa.year_month
--          AND cmi.ad_market_id = waa.ad_market_id
--          AND cmi.ad_type = waa.ad_type
-- want a flag for has tomahawk data
-- and has impressions data
  -- ,CASE WHEN cmi.ad_type = 'Display' THEN da_aaaaaa                ELSE sl_aaaaaa                END AS aaaaaa
  -- ,CASE WHEN cmi.ad_type =  'Display' AND cmi.inventory_type = 'Block' THEN da_block_aaaaaa
  --       WHEN cmi.ad_type =  'Display' AND cmi.inventory_type = 'Exclusive' THEN da_exc_aaaaaa
  --       WHEN cmi.ad_type <> 'Display' AND cmi.inventory_type = 'Block' THEN sl_block_aaaaaa
  --       ELSE sl_exclusive_aaaaaa
  --  END AS aaaaaa
  -- ,CASE WHEN cmi.inventory_type = 'Exclusive' THEN NULL
  --       WHEN cmi.ad_type =  'Display' THEN da_block_aaaaaa
  --       ELSE sl_block_aaaaaa
  --  END AS aaaaaa

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
         AND tom.process_date = '2016-07-02'
-- SELECT * FROM tmp_data_dm.coe_market_tom

-- SELECT
--    CASE WHEN final_potacv_for_sl_exclusive IS NULL AND final_potacv_for_da_exclusive IS NOT NULL THEN 1 ELSE 0 END AS problem_with_final_potacv_for_da_exclusive
--   ,CASE WHEN final_potacv_for_da_exclusive IS NULL AND final_potacv_for_sl_exclusive IS NOT NULL THEN 1 ELSE 0 END AS problem_with_final_potacv_for_sl_exclusive
--   ,CASE WHEN final_potacv_for_sl_blocks IS NULL AND final_potacv_for_da_blocks IS NOT NULL THEN 1 ELSE 0 END AS problem_with_final_potacv_for_da_blocks
--   ,CASE WHEN final_potacv_for_da_blocks IS NULL AND final_potacv_for_sl_blocks IS NOT NULL THEN 1 ELSE 0 END AS problem_with_final_potacv_for_sl_blocks
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND final_potacv_for_sl_blocks IS NULL THEN 1 ELSE 0 END AS problem_with_final_potacv_for_sl_blocks
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND final_potacv_for_da_blocks IS NULL THEN 1 ELSE 0 END AS problem_with_final_potacv_for_da_blocks
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND sl_total_block_recommendation IS NULL THEN 1 ELSE 0 END AS problem_with_sl_total_block_recommendation
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND sl_organic_block_recommendation IS NULL THEN 1 ELSE 0 END AS problem_with_sl_organic_block_recommendation
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND sl_sem_block_recommendation IS NULL THEN 1 ELSE 0 END AS problem_with_sl_sem_block_recommendation
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND da_total_block_recommendation IS NULL THEN 1 ELSE 0 END AS problem_with_da_total_block_recommendation
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND da_organic_block_recommendation IS NULL THEN 1 ELSE 0 END AS problem_with_da_organic_block_recommendation
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND da_sem_block_recommendation IS NULL THEN 1 ELSE 0 END AS problem_with_da_sem_block_recommendation
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND backorder_sl_blocks IS NULL THEN 1 ELSE 0 END AS problem_with_backorder_sl_blocks
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND backorder_da_blocks IS NULL THEN 1 ELSE 0 END AS problem_with_backorder_da_blocks
--   ,CASE WHEN final_potacv_for_sl_exclusive IS NULL AND blockprice IS NULL THEN 1 ELSE 0 END AS problem_with_blockprice
--   ,CASE WHEN final_potacv_for_sl_blocks IS NULL AND current_exclusiveprice IS NULL THEN 1 ELSE 0 END AS problem_with_current_exclusiveprice
--   ,CASE WHEN final_potacv_for_sl_blocks IS NULL AND sl_exclusive_price_recommended IS NULL THEN 1 ELSE 0 END AS problem_with_sl_exclusive_price_recommended
--   ,CASE WHEN final_potacv_for_sl_blocks IS NULL AND da_exclusive_price_recommended IS NULL THEN 1 ELSE 0 END AS problem_with_da_exclusive_price_recommended
--   ,COUNT(*) AS num_rows
-- FROM dm.tomahawk tom
-- WHERE tom.process_date = '2016-07-02'
-- GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
-- Sweet!
So if a market is block it has the block fields.

--   ,cmi.ad_market_id
--   ,cmi.state
--   ,mkt.ad_market_state_name
--   ,reg.ad_region_state_name
--   ,cmi.county
--   ,mkt.ad_market_county_name
--   ,reg.ad_region_county_name
--   ,cmi.ad_region
--   ,mkt.ad_market_region_name
--   ,reg.ad_region_name
--   ,cmi.parent_pa
--   ,pa.parent_specialty_name
--   ,cmi.practice_area
--   ,mkt.ad_market_specialty_name
--   ,pa.specialty_name
-- GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24

-- SELECT
--    cmi.year_month
--   ,cmi.ad_type
--   ,cmi.inventory_type
--   ,mkt.ad_market_active_flag
--   ,mkt.ad_market_block_flag
--   ,reg.ad_region_active_flag
--   ,mkt.record_flag
--   ,CASE WHEN LOWER(cmi.county) <> LOWER(mkt.ad_market_county_name) OR LOWER(cmi.county) <> LOWER(reg.ad_region_county_name) THEN 1 ELSE 0 END AS problem_with_county
--   ,CASE WHEN LOWER(cmi.state) <> LOWER(mkt.ad_market_state_name) OR LOWER(cmi.state) <> LOWER(reg.ad_region_state_name) THEN 1 ELSE 0 END AS problem_with_state
--   ,CASE WHEN LOWER(cmi.ad_region) <> LOWER(mkt.ad_market_region_name) OR LOWER(cmi.ad_region) <> LOWER(reg.ad_region_name) THEN 1 ELSE 0 END AS problem_with_ad_region
--   ,CASE WHEN LOWER(cmi.practice_area) <> LOWER(mkt.ad_market_specialty_name) OR LOWER(cmi.practice_area) <> LOWER(pa.specialty_name) THEN 1 ELSE 0 END AS problem_with_practice_area
--   ,CASE WHEN LOWER(cmi.parent_pa) <> LOWER(pa.parent_specialty_name) THEN 1 ELSE 0 END AS problem_with_parent_pa
--   ,COUNT(*) AS markets
-- FROM              tmp_data_dm.coe_market_intell_unrolled cmi
--   LEFT OUTER JOIN dm.ad_market_dimension mkt
--           ON cmi.ad_market_id = mkt.ad_market_id
--   LEFT OUTER JOIN dm.specialty_dimension pa ON mkt.specialty_id = pa.specialty_id 
--   LEFT OUTER JOIN dm.ad_region_dimension reg ON mkt.ad_region_id = reg.ad_region_id
-- GROUP BY 1,2,3,4,5,6,7,8,9,10,11,12
-- OK geo fields are lowercased in cmi so I would rather pull from the metadata table.
-- In every case, LOWER(field) matches between the (potentially) 3 sources.

So now CMI has the right lookups and I could drive things from that.

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
  ,cmi.lawyer_cnt
  ,cmi.potential_lawyer_cnt
  ,cmi.lawyer_claimed_cnt
  ,cmi.county_claim_rate
  ,cmi.sl_subscription_price
  ,cmi.price
  ,cmi.inventory_units
  ,cmi.sold_inventory_units
  ,cmi.value
  ,cmi.sold_value
  ,cmi.revenue
  ,tom.tom_inventory_avc
  ,tom.tom_inventory_avc_with_excl_display_logic
  ,tom.tom_raw_total_block_recommendation
  ,tom.tom_raw_total_block_released
  ,tom.tom_raw_total_block_sold
  ,tom.tom_business_rule
  ,tom.tom_review_reason
  ,tom.tom_backorder_blocks
  ,tom.tom_current_price
  ,tom.tom_exclusive_recommended_price
  ,tom.tom_advertisers
  ,tom.tom_max_advertiser_acv
  ,tom.tom_potential_imps_other_month_1
  ,tom.tom_potential_imps_sem_month_1
  ,tom.tom_clicks_other_month_1
  ,tom.tom_clicks_sem_month_1
  ,tom.tom_imps_other_month_1
  ,tom.tom_imps_sem_month_1
LOOK next pull, include tom.potential_sem_da_acv and potential_sem_sl_acv.
FROM              tmp_data_dm.coe_market_intell_unrolled cmi
  INNER JOIN tmp_data_dm.coe_market_tom tom
          ON cmi.year_month = tom.year_month
         AND cmi.ad_market_id = tom.ad_market_id
         AND cmi.ad_type = tom.ad_type

----
Hand-rolled metrics

-- Cancels in last 90 days - churned subscriptions in that market
ACV Target - might be simple to get from deferred_revenue.  - nice to have.
# of active professionals
# of active customers
profnl_target_impressions also exists which will give it to you by month (ignore etl_load_date in that one)

Do I have MRR categories at sub level?
Yep.  Use ''em.
Up (mrr_acquired, mrr_penetrated), down (mrr_churned, mrr_downsized), 
beginning MRR (mrr_prior_month WHERE yearmonth = 201604),
ending MRR (mrr_current_month WHERE yearmonth = 201604).
WHERE yearmonth IN (201604. 201605, 201606)

Actually turns out there is a customer_level MRR table that has market. mrr_market_classification
But I think I want the sub-level view.

-- Get trailing 3 months MRR.
DROP TABLE tmp_data_dm.coe_market_mrr;
CREATE TABLE tmp_data_dm.coe_market_mrr AS
SELECT
   201606 AS                                                               year_month
  ,mrr.market_id AS                                                        ad_market_id
  ,CASE WHEN sub.ad_type LIKE 'Dis%' THEN 'Display'
        WHEN sub.ad_type LIKE 'Spo%' THEN 'Sponsored Listing'
        ELSE 'Unknown Ad Type'
   END AS                                                                  ad_type
  ,SUM(CASE WHEN yearmonth = 201604 THEN mrr_prior_month ELSE 0 END) AS    beginning_mrr
  ,SUM(mrr.mrr_acquired + mrr.mrr_penetrated) AS                           mrr_up
  ,SUM(mrr.mrr_churned + mrr.mrr_downsized) AS                             mrr_down
  ,SUM(CASE WHEN yearmonth = 201606 THEN mrr_current_month ELSE 0 END) AS  ending_mrr
  ,COUNT(DISTINCT CASE WHEN yearmonth = 201606 THEN mrr.customer_id ELSE NULL END) AS  ending_customers
  ,COUNT(*) AS                                                             aggregate_num_subs
FROM         dm.mrr_subscription_classification mrr
  LEFT OUTER JOIN dm.subscription_dimension sub ON mrr.subscription_id = sub.subscription_id
WHERE mrr.yearmonth IN (201604, 201605, 201606)
  AND sub.ad_type LIKE 'Dis%' OR sub.ad_type LIKE 'Spo%'
GROUP BY 1,2,3
-- SELECT * FROM tmp_data_dm.coe_market_mrr

-- SELECT
--    CASE WHEN sub.ad_type LIKE 'Dis%' THEN 'Display'
--         WHEN sub.ad_type LIKE 'Spo%' THEN 'Sponsored Listing'
--         ELSE 'Unknown Ad Type'
--    END AS ad_type
--   ,SUM(aaaaaa) AS aaaaaa
--   ,SUM(aaaaaa) AS aaaaaa
--   ,SUM(aaaaaa) AS aaaaaa
--   ,SUM(aaaaaa) AS aaaaaa
--   ,SUM(aaaaaa) AS aaaaaa
--   ,COUNT(*) AS num_rows
-- FROM         dm.mrr_subscription_classification mrr
--   LEFT OUTER JOIN dm.subscription_dimension sub ON mrr.subscription_id = sub.subscription_id
-- WHERE mrr.yearmonth = 201606  -- LOOK later change to 3mo
-- GROUP BY 1,2

-- SELECT
--    ad_type
--   ,SUM(beginning_mrr) AS  beginning_mrr
--   ,SUM(mrr_up) AS         mrr_up
--   ,SUM(mrr_down) AS       mrr_down
--   ,SUM(ending_mrr) AS     ending_mrr
--   ,SUM(num_rows) AS       num_subs
--   ,COUNT(*) AS num_rows
-- FROM tmp_data_dm.coe_market_mrr
-- GROUP BY 1 ORDER BY 1

-- select year_month, cancel_date, count(*) as num_rows, sum(target_impression_cnt) AS target_impression_cnt from dm.profnl_target_impressions 
-- where year_month = 201606
-- group by 1,2 order by 1,2

-- Yeah and for that month I think target impressions is already prorated so so not have to look
-- at cancel date.
-- ah but one to many professionals to ads.

DROP TABLE tmp_data_dm.coe_market_targets;
CREATE TABLE tmp_data_dm.coe_market_targets AS
SELECT
   201606 AS                          year_month
  ,tgt.ad_market_id
  ,CASE WHEN ad.ad_detail_type LIKE 'Dis%' THEN 'Display'
        WHEN ad.ad_detail_type LIKE 'Spo%' THEN 'Sponsored Listing'
        ELSE 'Unknown Ad Type'
   END AS                             ad_type
  ,SUM(tgt.target_impression_cnt) AS  target_impressions
FROM         dm.profnl_target_impressions tgt
  LEFT OUTER JOIN dm.ad_dimension ad ON tgt.ad_id = ad.ad_id
WHERE tgt.year_month = 201606
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
   ,CASE WHEN tom.ad_market_id IS NULL THEN 'No tomahawk data' ELSE 'Has tomahawk data' END AS     has_tom_data
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
  ,IFNULL(CAST(waa.ad_click_count AS STRING), '') AS                ad_click_count
  ,IFNULL(CAST(waa.ad_click_value AS STRING), '') AS                ad_click_value
  ,IFNULL(CAST(waa.email_acu AS STRING), '') AS                     email_acu
  ,IFNULL(CAST(waa.email_attributed_value AS STRING), '') AS        email_attributed_value
  ,IFNULL(CAST(waa.website_acu AS STRING), '') AS                   website_acu
  ,IFNULL(CAST(waa.website_attributed_value AS STRING), '') AS      website_attributed_value
  ,IFNULL(CAST(waa.phone_acu AS STRING), '') AS                     phone_acu
  ,IFNULL(CAST(waa.phone_attributed_value AS STRING), '') AS        phone_attributed_value
  -- ,IFNULL(CAST(waa.ad_serp_impression_count AS STRING), '') AS      ad_serp_impression_count
  -- ,IFNULL(CAST(waa.ad_non_serp_impression_count AS STRING), '') AS  ad_non_serp_impression_count
  -- ,IFNULL(CAST(waa.impressions_delivered AS STRING), '') AS         impressions_delivered
  -- ,IFNULL(CAST(waa.weighted_ad_impression_count AS STRING), '') AS  weighted_ad_impression_count
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

LOOK next pull, include tom.potential_sem_da_acv and potential_sem_sl_acv.
Ah probably not I think I already include what they need.
