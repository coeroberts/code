Notes on LLC Cube

Lawyer level or customer level?

Want both.  Focus on customer.

Revenue grouped into categories: 
Top 1-5 categories
PA, avvo rating, visits

Revenue decreased 5% MoM for lawyers in these PAs and < Y avvo rating.

Revenue, MRR, Mod up, Mod down, Churn, customer counts.

For each of those categories
Grouped in some reasonable way.

Anaplan:
Master w/ advertiser ID and metadata

Thinking about attribute grouping.
Want it as of how they are categorized in the month.

PA needs to be based on behavior (instead of what they reported).

Not just ratios, tho, total dollars are important even if
customers are coming into / going out of the category.

Roll up to month and then show trend.
(note: initially no history.  Gonna be really boring trend.)

Basics are active/not, advertiser/not, MRR high lo med zero?

BUSINESS QUESTIONS:
-- - Even though we are typically only interested in delta during month,
--   things like avvo rating and client reviews are cumulative over life. OK.
-- - Only active customers? Yes.
-- - Base Top PA on current month or trailing 1 year? Both.
- Rollup to pro will not be perfect if pro has > 1 customer.

DATA QUESTIONS
- Why only Avvo rating for 213 pros (Oct 9)?
  And 622 average_client_review_rating.


----

Workarounds:

- Use my version of customer_professional_map so we do not
  include customers for a pro if they are no longer being
  billed.
-- - If a pro is related to multiple customers:
--   - Flag the customer in the cube.
--   - Roll the pro up under every customer they are related to 
--     for that month.
- Pull MRR and revenue from mrr customer table; do not try to
  roll up professional-level values.
  (Actually, do both just so I can see magnitude.)
  Do we expect professional MRR to roll up to customer?  Seems unlikely because:
    - professional_id = -1
    - pro being rolled up to 1 customer
  Correct.


----

dm.lawyer_cube_data_by_day
dm.lawyer_cube_data_by_month
dm.professional_event_fact
dm.mrr_professional_daily_all_products

SELECT
   as_of_date
  ,COUNT(DISTINCT professional_id) AS professionals
  ,COUNT(*) AS num_rows
FROM dm.lawyer_cube_data_by_day
GROUP BY 1 ORDER BY 1

SELECT
   *
FROM dm.lawyer_cube_data_by_day
WHERE as_of_date = '2016-10-09'
AND is_active = 'Y'
LIMIT 100

customer_professional_purchase_map

SELECT
   customers, COUNT(*) AS professionals_with_that_many_customer_ids
FROM
  (
  SELECT professional_id, COUNT(*) AS customers
  FROM dm.customer_professional_purchase_map
  WHERE yearmonth = 201609
    AND professional_id <> -1
  GROUP BY 1
  ) prof
GROUP BY 1
ORDER BY 1

  ,CASE WHEN mth.month_begin_date <= cpp.last_billed_date
         AND ((cpp.last_cancelled_date = '-1') OR (mth.month_end_date < cpp.last_cancelled_date))
          THEN 'Include'
          ELSE 'Exclude'
   END AS status

SELECT
   customers, COUNT(*) AS professionals_with_that_many_customer_ids
FROM
  (
  SELECT professional_id, COUNT(*) AS customers
  FROM
    (
    SELECT
       cpp.customer_id
      ,cpp.professional_id
      ,cpp.last_purchased_date
      ,cpp.last_billed_date
      ,cpp.last_cancelled_date
      ,cpp.etl_load_date
      ,cpp.yearmonth
      ,mth.month_begin_date
      ,mth.month_end_date
    FROM
                 dm.customer_professional_purchase_map cpp
      INNER JOIN dm.month_dim mth
              ON cpp.yearmonth = mth.year_month
    WHERE mth.month_begin_date <= cpp.last_billed_date
      -- AND ((cpp.last_cancelled_date = '-1') OR (mth.month_end_date < cpp.last_cancelled_date))
    ) flt
  WHERE yearmonth = 201609
    AND professional_id <> -1
  GROUP BY 1
  ) prof
GROUP BY 1
ORDER BY 1

SELECT COUNT(DISTINCT professional_id)
FROM dm.order_line_accumulation_fact
WHERE order_line_begin_date BETWEEN '2016-09-01' AND '2016-09-30'
ok that is 24K while the previous query gave me about 15.5K.
not good.
OK cannot look at cancelled date.  then we are fine.

SELECT * FROM
  (SELECT DISTINCT professional_id, customer_id
   FROM dm.order_line_accumulation_fact
   WHERE order_line_begin_date BETWEEN '2016-09-01' AND '2016-09-30'
  ) prof
  LEFT OUTER JOIN 
    (
    SELECT
       cpp.customer_id
      ,cpp.professional_id
      ,cpp.last_purchased_date
      ,cpp.last_billed_date
      ,cpp.last_cancelled_date
      ,cpp.etl_load_date
      ,cpp.yearmonth
      ,mth.month_begin_date
      ,mth.month_end_date
      ,CASE WHEN mth.month_begin_date <= cpp.last_billed_date
             AND ((cpp.last_cancelled_date = '-1') OR (mth.month_end_date < cpp.last_cancelled_date))
              THEN 'Include'
              ELSE 'Exclude'
       END AS status
    FROM
                 dm.customer_professional_purchase_map cpp
      INNER JOIN dm.month_dim mth
              ON cpp.yearmonth = mth.year_month
    WHERE 
    -- mth.month_begin_date <= cpp.last_billed_date
    --   AND ((cpp.last_cancelled_date = '-1') OR (mth.month_end_date < cpp.last_cancelled_date))
          cpp.yearmonth = 201609
      AND cpp.professional_id <> -1
    ) flt
     ON prof.professional_id = flt.professional_id
    AND prof.customer_id = flt.customer_id
OK it looks like last_cancelled_date is meaningless.  We have
many cases where there is a bill past that.
My guess is it shows when the last cancel was requested, not
when their service stopped.  It might not even get reset if
they re-up.


OK I am good with this as customer professional map:
    SELECT
       cpp.customer_id
      ,cpp.professional_id
      ,cpp.last_purchased_date
      ,cpp.last_billed_date
      ,cpp.last_cancelled_date
      ,cpp.etl_load_date
      ,cpp.yearmonth
      ,mth.month_begin_date
      ,mth.month_end_date
      ,CASE WHEN mth.month_begin_date <= cpp.last_billed_date
             AND ((cpp.last_cancelled_date = '-1') OR (mth.month_end_date < cpp.last_cancelled_date))
              THEN 'Include'
              ELSE 'Exclude'
       END AS status
    FROM
                 dm.customer_professional_purchase_map cpp
      INNER JOIN dm.month_dim mth
              ON cpp.yearmonth = mth.year_month
    WHERE mth.month_begin_date <= cpp.last_billed_date
      AND cpp.professional_id <> -1
If I need to make it one customer per, could probably figure out a way 
to do that.  For now, I think I am going to include a pro in every
customer they are related to.

Wahoo!  Dev is going to give us customer_id.

----

SELECT practicing_flag, count(*)
FROM dm.lawyer_cube_data_by_day
WHERE as_of_date = '2016-10-09'
  AND is_active = 'Y'
GROUP BY 1

-- SELECT *
-- FROM
--   (
--   SELECT
--      professional_id
--     ,as_of_date
--     -- ,month_begin_date
--     ,avvo_rating
--     ,average_client_review_rating
--     ,client_reviews
--     ,client_reviews_all_time
--     ,last_negative_client_review_date
--     ,negative_client_reviews_all_time
--     ,practice_area
--     ,top_ad_revenue_practice_area
--     ,top_ad_revenue_practice_area_1_year
--     ,top_ad_revenue_parent_practice_area
--     ,top_ad_revenue_parent_practice_area_1_year
--     ,months_since_first_licensed
--     ,months_since_claimed
--     ,first_active_date
--     ,target_impressions
--     -- ,ad_revenue_mtd
--     -- ,revenue_mtd
--     -- ,mrr_ad
--     -- ,mrr
--     ,ls_participation
--     ,has_ads
--     ,state
--     ,ad_revenue_state
--     ,recent_active_months
--     ,visits
--     ,delivered_phone_call_acu + delivered_email_acu + delivered_website_contact_acu AS delivered_acu
--     ,delivered_phone_call_acu
--     ,delivered_email_acu
--     ,delivered_website_contact_acu
--     ,delivered_phone_calls
--     ,delivered_phone_calls_ge_120s
--     ,delivered_emails
--     ,delivered_chat_messages
--     ,delivered_chat_conversations
--     ,delivered_website_contacts
--     ,target_acv
--     ,acv
--     ,phone_acv
--     ,email_acv
--     ,website_acv
--     ,questions_answered
--     ,questions_answered_1_year
--     ,questions_answered_all_time
--     ,peer_endorsements_given
--     ,peer_endorsements_given_1_year
--     ,peer_endorsements_given_all_time
--     ,peer_endorsements_received
--     ,peer_endorsements_received_1_year
--     ,peer_endorsements_received_all_time
--     ,delivered_impressions_block
--     ,delivered_impressions_block_network
--     ,delivered_impressions_exclusive
--     ,delivered_impressions_exclusive_network
--     ,practicing_flag  -- charming.  72 active attorneys in oct are marked not practicing.
--     -- ,mrr_category_in_month
--     ,ROW_NUMBER() OVER(PARTITION BY professional_id
--                            ORDER BY revenue_mtd DESC) AS dedup_num  -- LOOK hack; will create bad data.
--   FROM dm.lawyer_cube_data_by_day
--   WHERE as_of_date = '2016-10-09'
--     AND is_active = 'Y'
--   ) prof
-- WHERE dedup_num = 1
-- AND professional_id % 1923 = 8

SELECT
   avvo_rating
  ,COUNT(DISTINCT professional_id) AS professionals_ish
FROM dm.lawyer_cube_data_by_day
WHERE as_of_date = '2016-10-11'
  AND is_active = 'Y'
GROUP BY 1

-- SELECT
--    COUNT(*) AS professionals
--   ,SUM(CASE WHEN avvo_rating IS NOT NULL THEN 1 ELSE 0 END) AS avvo_rating_chk
--   ,SUM(CASE WHEN average_client_review_rating IS NOT NULL THEN 1 ELSE 0 END) AS average_client_review_rating_chk
--   ,SUM(CASE WHEN client_reviews IS NOT NULL THEN 1 ELSE 0 END) AS client_reviews_chk
--   ,SUM(CASE WHEN client_reviews_all_time IS NOT NULL THEN 1 ELSE 0 END) AS client_reviews_all_time_chk
--   ,SUM(CASE WHEN last_negative_client_review_date IS NOT NULL THEN 1 ELSE 0 END) AS last_negative_client_review_date_chk
--   ,SUM(CASE WHEN negative_client_reviews_all_time IS NOT NULL THEN 1 ELSE 0 END) AS negative_client_reviews_all_time_chk
--   ,SUM(CASE WHEN practice_area IS NOT NULL THEN 1 ELSE 0 END) AS practice_area_chk
--   ,SUM(CASE WHEN top_ad_revenue_practice_area IS NOT NULL THEN 1 ELSE 0 END) AS top_ad_revenue_practice_area_chk
--   ,SUM(CASE WHEN top_ad_revenue_practice_area_1_year IS NOT NULL THEN 1 ELSE 0 END) AS top_ad_revenue_practice_area_1_year_chk
--   ,SUM(CASE WHEN top_ad_revenue_parent_practice_area IS NOT NULL THEN 1 ELSE 0 END) AS top_ad_revenue_parent_practice_area_chk
--   ,SUM(CASE WHEN top_ad_revenue_parent_practice_area_1_year IS NOT NULL THEN 1 ELSE 0 END) AS top_ad_revenue_parent_practice_area_1_year_chk
--   ,SUM(CASE WHEN months_since_first_licensed IS NOT NULL THEN 1 ELSE 0 END) AS months_since_first_licensed_chk
--   ,SUM(CASE WHEN months_since_claimed IS NOT NULL THEN 1 ELSE 0 END) AS months_since_claimed_chk
--   ,SUM(CASE WHEN first_active_date IS NOT NULL THEN 1 ELSE 0 END) AS first_active_date_chk
--   ,SUM(CASE WHEN target_impressions IS NOT NULL THEN 1 ELSE 0 END) AS target_impressions_chk
--   ,SUM(CASE WHEN ad_revenue_mtd IS NOT NULL THEN 1 ELSE 0 END) AS ad_revenue_mtd_chk
--   ,SUM(CASE WHEN revenue_mtd IS NOT NULL THEN 1 ELSE 0 END) AS revenue_mtd_chk
--   ,SUM(CASE WHEN mrr_ad IS NOT NULL THEN 1 ELSE 0 END) AS mrr_ad_chk
--   ,SUM(CASE WHEN mrr IS NOT NULL THEN 1 ELSE 0 END) AS mrr_chk
--   ,SUM(CASE WHEN ls_participation IS NOT NULL THEN 1 ELSE 0 END) AS ls_participation_chk
--   ,SUM(CASE WHEN has_ads IS NOT NULL THEN 1 ELSE 0 END) AS has_ads_chk
--   ,SUM(CASE WHEN state IS NOT NULL THEN 1 ELSE 0 END) AS state_chk
--   ,SUM(CASE WHEN ad_revenue_state IS NOT NULL THEN 1 ELSE 0 END) AS ad_revenue_state_chk
--   ,SUM(CASE WHEN recent_active_months IS NOT NULL THEN 1 ELSE 0 END) AS recent_active_months_chk
--   ,SUM(CASE WHEN visits IS NOT NULL THEN 1 ELSE 0 END) AS visits_chk
--   ,SUM(CASE WHEN delivered_phone_call_acu IS NOT NULL THEN 1 ELSE 0 END) AS delivered_phone_call_acu_chk
--   ,SUM(CASE WHEN delivered_email_acu IS NOT NULL THEN 1 ELSE 0 END) AS delivered_email_acu_chk
--   ,SUM(CASE WHEN delivered_website_contact_acu IS NOT NULL THEN 1 ELSE 0 END) AS delivered_website_contact_acu_chk
--   ,SUM(CASE WHEN delivered_phone_calls IS NOT NULL THEN 1 ELSE 0 END) AS delivered_phone_calls_chk
--   ,SUM(CASE WHEN delivered_phone_calls_ge_120s IS NOT NULL THEN 1 ELSE 0 END) AS delivered_phone_calls_ge_120s_chk
--   ,SUM(CASE WHEN delivered_emails IS NOT NULL THEN 1 ELSE 0 END) AS delivered_emails_chk
--   ,SUM(CASE WHEN delivered_chat_messages IS NOT NULL THEN 1 ELSE 0 END) AS delivered_chat_messages_chk
--   ,SUM(CASE WHEN delivered_chat_conversations IS NOT NULL THEN 1 ELSE 0 END) AS delivered_chat_conversations_chk
--   ,SUM(CASE WHEN delivered_website_contacts IS NOT NULL THEN 1 ELSE 0 END) AS delivered_website_contacts_chk
--   ,SUM(CASE WHEN target_acv IS NOT NULL THEN 1 ELSE 0 END) AS target_acv_chk
--   ,SUM(CASE WHEN acv IS NOT NULL THEN 1 ELSE 0 END) AS acv_chk
--   ,SUM(CASE WHEN phone_acv IS NOT NULL THEN 1 ELSE 0 END) AS phone_acv_chk
--   ,SUM(CASE WHEN email_acv IS NOT NULL THEN 1 ELSE 0 END) AS email_acv_chk
--   ,SUM(CASE WHEN website_acv IS NOT NULL THEN 1 ELSE 0 END) AS website_acv_chk
--   ,SUM(CASE WHEN questions_answered IS NOT NULL THEN 1 ELSE 0 END) AS questions_answered_chk
--   ,SUM(CASE WHEN questions_answered_1_year IS NOT NULL THEN 1 ELSE 0 END) AS questions_answered_1_year_chk
--   ,SUM(CASE WHEN questions_answered_all_time IS NOT NULL THEN 1 ELSE 0 END) AS questions_answered_all_time_chk
--   ,SUM(CASE WHEN peer_endorsements_given IS NOT NULL THEN 1 ELSE 0 END) AS peer_endorsements_given_chk
--   ,SUM(CASE WHEN peer_endorsements_given_1_year IS NOT NULL THEN 1 ELSE 0 END) AS peer_endorsements_given_1_year_chk
--   ,SUM(CASE WHEN peer_endorsements_given_all_time IS NOT NULL THEN 1 ELSE 0 END) AS peer_endorsements_given_all_time_chk
--   ,SUM(CASE WHEN peer_endorsements_received IS NOT NULL THEN 1 ELSE 0 END) AS peer_endorsements_received_chk
--   ,SUM(CASE WHEN peer_endorsements_received_1_year IS NOT NULL THEN 1 ELSE 0 END) AS peer_endorsements_received_1_year_chk
--   ,SUM(CASE WHEN peer_endorsements_received_all_time IS NOT NULL THEN 1 ELSE 0 END) AS peer_endorsements_received_all_time_chk
--   ,SUM(CASE WHEN delivered_impressions_block IS NOT NULL THEN 1 ELSE 0 END) AS delivered_impressions_block_chk
--   ,SUM(CASE WHEN delivered_impressions_block_network IS NOT NULL THEN 1 ELSE 0 END) AS delivered_impressions_block_network_chk
--   ,SUM(CASE WHEN delivered_impressions_exclusive IS NOT NULL THEN 1 ELSE 0 END) AS delivered_impressions_exclusive_chk
--   ,SUM(CASE WHEN delivered_impressions_exclusive_network IS NOT NULL THEN 1 ELSE 0 END) AS delivered_impressions_exclusive_network_chk
--   ,SUM(CASE WHEN practicing_flag IS NOT NULL THEN 1 ELSE 0 END) AS practicing_flag_chk
-- FROM
--   (
--     SELECT
--        professional_id
--       ,MAX(avvo_rating) AS avvo_rating
--       ,MAX(average_client_review_rating) AS average_client_review_rating
--       ,MAX(client_reviews) AS client_reviews
--       ,MAX(client_reviews_all_time) AS client_reviews_all_time
--       ,MAX(last_negative_client_review_date) AS last_negative_client_review_date
--       ,MAX(negative_client_reviews_all_time) AS negative_client_reviews_all_time
--       ,MAX(practice_area) AS practice_area
--       ,MAX(top_ad_revenue_practice_area) AS top_ad_revenue_practice_area
--       ,MAX(top_ad_revenue_practice_area_1_year) AS top_ad_revenue_practice_area_1_year
--       ,MAX(top_ad_revenue_parent_practice_area) AS top_ad_revenue_parent_practice_area
--       ,MAX(top_ad_revenue_parent_practice_area_1_year) AS top_ad_revenue_parent_practice_area_1_year
--       ,MAX(months_since_first_licensed) AS months_since_first_licensed
--       ,MAX(months_since_claimed) AS months_since_claimed
--       ,MAX(first_active_date) AS first_active_date
--       ,MAX(target_impressions) AS target_impressions
--       ,MAX(ad_revenue_mtd) AS ad_revenue_mtd
--       ,MAX(revenue_mtd) AS revenue_mtd
--       ,MAX(mrr_ad) AS mrr_ad
--       ,MAX(mrr) AS mrr
--       ,MAX(ls_participation) AS ls_participation
--       ,MAX(has_ads) AS has_ads
--       ,MAX(state) AS state
--       ,MAX(ad_revenue_state) AS ad_revenue_state
--       ,MAX(recent_active_months) AS recent_active_months
--       ,MAX(visits) AS visits
--       ,MAX(delivered_phone_call_acu) AS delivered_phone_call_acu
--       ,MAX(delivered_email_acu) AS delivered_email_acu
--       ,MAX(delivered_website_contact_acu) AS delivered_website_contact_acu
--       ,MAX(delivered_phone_calls) AS delivered_phone_calls
--       ,MAX(delivered_phone_calls_ge_120s) AS delivered_phone_calls_ge_120s
--       ,MAX(delivered_emails) AS delivered_emails
--       ,MAX(delivered_chat_messages) AS delivered_chat_messages
--       ,MAX(delivered_chat_conversations) AS delivered_chat_conversations
--       ,MAX(delivered_website_contacts) AS delivered_website_contacts
--       ,MAX(target_acv) AS target_acv
--       ,MAX(acv) AS acv
--       ,MAX(phone_acv) AS phone_acv
--       ,MAX(email_acv) AS email_acv
--       ,MAX(website_acv) AS website_acv
--       ,MAX(questions_answered) AS questions_answered
--       ,MAX(questions_answered_1_year) AS questions_answered_1_year
--       ,MAX(questions_answered_all_time) AS questions_answered_all_time
--       ,MAX(peer_endorsements_given) AS peer_endorsements_given
--       ,MAX(peer_endorsements_given_1_year) AS peer_endorsements_given_1_year
--       ,MAX(peer_endorsements_given_all_time) AS peer_endorsements_given_all_time
--       ,MAX(peer_endorsements_received) AS peer_endorsements_received
--       ,MAX(peer_endorsements_received_1_year) AS peer_endorsements_received_1_year
--       ,MAX(peer_endorsements_received_all_time) AS peer_endorsements_received_all_time
--       ,MAX(delivered_impressions_block) AS delivered_impressions_block
--       ,MAX(delivered_impressions_block_network) AS delivered_impressions_block_network
--       ,MAX(delivered_impressions_exclusive) AS delivered_impressions_exclusive
--       ,MAX(delivered_impressions_exclusive_network) AS delivered_impressions_exclusive_network
--       ,MAX(practicing_flag) AS practicing_flag
--     FROM dm.lawyer_cube_data_by_day
--     WHERE as_of_date = '2016-10-09'
--       AND is_active = 'Y'
--     GROUP BY 1
--     ) prof

-- DROP TABLE tmp_data_dm.coe_llc_cust;
-- CREATE TABLE tmp_data_dm.coe_llc_cust AS
-- SELECT
--    cub.professional_id AS customer_id
--   ,dt.month_begin_date
--   ,dt.month_end_date
--   ,dt.year_month
--   -- ,dt.month_end_date AS                                            as_of_date
--   ,cub.as_of_date                                   -- LOOK
--   ,COUNT(*) AS                                                     professionals
--   ,MAX(1) AS                                                       customers
--   ,MIN(cub.avvo_rating) AS                                         avvo_rating_min
--   ,AVG(cub.avvo_rating) AS                                         avvo_rating_avg
--   ,MAX(cub.avvo_rating) AS                                         avvo_rating_max
--   ,MIN(cub.average_client_review_rating) AS                        average_client_review_rating_min
--   ,AVG(cub.average_client_review_rating) AS                        average_client_review_rating_avg
--   ,MAX(cub.average_client_review_rating) AS                        average_client_review_rating_max
--   ,MIN(IFNULL(cub.client_reviews, 0)) AS                           client_reviews_min
--   ,AVG(IFNULL(cub.client_reviews, 0)) AS                           client_reviews_avg
--   ,MAX(IFNULL(cub.client_reviews, 0)) AS                           client_reviews_max
--   ,MIN(IFNULL(cub.client_reviews_all_time, 0)) AS                  client_reviews_all_time_min
--   ,AVG(IFNULL(cub.client_reviews_all_time, 0)) AS                  client_reviews_all_time_avg
--   ,MAX(IFNULL(cub.client_reviews_all_time, 0)) AS                  client_reviews_all_time_max
--   ,MAX(cub.last_negative_client_review_date) AS                    last_negative_client_review_date
--   ,MIN(IFNULL(cub.negative_client_reviews_all_time, 0)) AS         negative_client_reviews_all_time_min
--   ,AVG(IFNULL(cub.negative_client_reviews_all_time, 0)) AS         negative_client_reviews_all_time_avg
--   ,MAX(IFNULL(cub.negative_client_reviews_all_time, 0)) AS         negative_client_reviews_all_time_max
--   ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
--               THEN cub.practice_area ELSE NULL END) AS                               practice_area
--   ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
--               THEN cub.top_ad_revenue_practice_area ELSE NULL END) AS                top_ad_revenue_practice_area
--   ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
--               THEN cub.top_ad_revenue_practice_area_1_year ELSE NULL END) AS         top_ad_revenue_practice_area_1_year
--   ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
--               THEN cub.top_ad_revenue_parent_practice_area ELSE NULL END) AS         top_ad_revenue_parent_practice_area
--   ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
--               THEN cub.top_ad_revenue_parent_practice_area_1_year ELSE NULL END) AS  top_ad_revenue_parent_practice_area_1_year
--   ,MIN(cub.months_since_first_licensed) AS                         months_since_first_licensed_min
--   ,AVG(cub.months_since_first_licensed) AS                         months_since_first_licensed_avg
--   ,MAX(cub.months_since_first_licensed) AS                         months_since_first_licensed_max
--   ,MIN(cub.months_since_claimed) AS                                months_since_claimed_min
--   ,AVG(cub.months_since_claimed) AS                                months_since_claimed_avg
--   ,MAX(cub.months_since_claimed) AS                                months_since_claimed_max
--   ,MIN(cub.first_active_date) AS                                   first_active_date
--   /*
--   -- ,MAX(((CAST(STRLEFT(cub.as_of_date, 4) AS INTEGER)) - CAST(STRLEFT(cub.first_active_date, 4) AS INTEGER)) * 12) +
--   --     (  CAST(SUBSTR(cub.as_of_date, 6, 2) AS INTEGER)) - CAST(SUBSTR(cub.first_active_date, 6, 2) AS INTEGER)) + 1) AS tenure_month
--   -- ,MAX(
--   --       1 +
--   --       (
--   --          (
--   --             CAST(STRLEFT(cub.as_of_date, 4) AS INTEGER)
--   --             - 
--   --             CAST(STRLEFT(cub.first_active_date, 4) AS INTEGER)
--   --          ) 
--   --          * 12
--   --       ) 
--   --       +
--   --       (
--   --         CAST(SUBSTR(cub.as_of_date, 6, 2) AS INTEGER)
--   --         - 
--   --         CAST(SUBSTR(cub.first_active_date, 6, 2) AS INTEGER)
--   --       )
--   --     ) AS tenure_month
--   */
--   ,MAX( 1 +
--         ((CAST(STRLEFT(cub.as_of_date, 4) AS INTEGER) - CAST(STRLEFT(cub.first_active_date, 4) AS INTEGER) ) * 12) +
--         (CAST(SUBSTR(cub.as_of_date, 6, 2) AS INTEGER) - CAST(SUBSTR(cub.first_active_date, 6, 2) AS INTEGER))
--       ) AS tenure_month
--   ,SUM(IFNULL(cub.target_impressions, 0)) AS                       target_impressions
--   ,SUM(IFNULL(cub.ad_revenue_mtd, 0)) AS                           ad_revenue_prof
--   ,SUM(IFNULL(cub.revenue_mtd, 0)) AS                              revenue_prof
--   ,SUM(IFNULL(cub.mrr_ad, 0)) AS                                   mrr_ad_prof
--   ,SUM(IFNULL(cub.mrr, 0)) AS                                      mrr_prof
--   ,MAX(cub.ls_participation) AS                                    ls_participation
--   ,MAX(cub.has_ads) AS                                             has_ads
--   ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
--               THEN cub.state ELSE NULL END) AS                     state
--   ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
--               THEN cub.ad_revenue_state ELSE NULL END) AS          ad_revenue_state
--   ,MAX(cub.recent_active_months) AS                                recent_active_months
--   ,SUM(IFNULL(cub.visits, 0)) AS                                   visits
--   ,SUM(IFNULL(cub.delivered_phone_call_acu, 0) + 
--        IFNULL(cub.delivered_email_acu, 0) + 
--        IFNULL(cub.delivered_website_contact_acu, 0)) AS            delivered_acu
--   ,SUM(IFNULL(cub.delivered_phone_call_acu, 0)) AS                 delivered_phone_call_acu
--   ,SUM(IFNULL(cub.delivered_email_acu, 0)) AS                      delivered_email_acu
--   ,SUM(IFNULL(cub.delivered_website_contact_acu, 0)) AS            delivered_website_contact_acu
--   ,SUM(IFNULL(cub.delivered_phone_calls, 0)) AS                    delivered_phone_calls
--   ,SUM(IFNULL(cub.delivered_phone_calls_ge_120s, 0)) AS            delivered_phone_calls_ge_120s
--   ,SUM(IFNULL(cub.delivered_emails, 0)) AS                         delivered_emails
--   ,SUM(IFNULL(cub.delivered_chat_messages, 0)) AS                  delivered_chat_messages
--   -- ,SUM(IFNULL(cub.delivered_chat_conversations, 0)) AS             delivered_chat_conversations  -- LOOK
--   ,SUM(IFNULL(CAST(cub.delivered_chat_conversations AS INTEGER), 0)) AS    delivered_chat_conversations
--   ,SUM(IFNULL(cub.delivered_website_contacts, 0)) AS               delivered_website_contacts
--   ,SUM(IFNULL(cub.target_acv, 0)) AS                               target_acv
--   ,SUM(IFNULL(cub.acv, 0)) AS                                      acv
--   ,SUM(IFNULL(cub.phone_acv, 0)) AS                                phone_acv
--   ,SUM(IFNULL(cub.email_acv, 0)) AS                                email_acv
--   ,SUM(IFNULL(cub.website_acv, 0)) AS                              website_acv
--   ,MIN(IFNULL(cub.questions_answered, 0)) AS                       questions_answered_min
--   ,AVG(IFNULL(cub.questions_answered, 0)) AS                       questions_answered_avg
--   ,MAX(IFNULL(cub.questions_answered, 0)) AS                       questions_answered_max
--   ,MIN(IFNULL(cub.questions_answered_1_year, 0)) AS                questions_answered_1_year_min
--   ,AVG(IFNULL(cub.questions_answered_1_year, 0)) AS                questions_answered_1_year_avg
--   ,MAX(IFNULL(cub.questions_answered_1_year, 0)) AS                questions_answered_1_year_max
--   ,MIN(IFNULL(cub.questions_answered_all_time, 0)) AS              questions_answered_all_time_min
--   ,AVG(IFNULL(cub.questions_answered_all_time, 0)) AS              questions_answered_all_time_avg
--   ,MAX(IFNULL(cub.questions_answered_all_time, 0)) AS              questions_answered_all_time_max
--   ,MIN(IFNULL(cub.peer_endorsements_given, 0)) AS                  peer_endorsements_given_min
--   ,AVG(IFNULL(cub.peer_endorsements_given, 0)) AS                  peer_endorsements_given_avg
--   ,MAX(IFNULL(cub.peer_endorsements_given, 0)) AS                  peer_endorsements_given_max
--   ,MIN(IFNULL(cub.peer_endorsements_given_1_year, 0)) AS           peer_endorsements_given_1_year_min
--   ,AVG(IFNULL(cub.peer_endorsements_given_1_year, 0)) AS           peer_endorsements_given_1_year_avg
--   ,MAX(IFNULL(cub.peer_endorsements_given_1_year, 0)) AS           peer_endorsements_given_1_year_max
--   ,MIN(IFNULL(cub.peer_endorsements_given_all_time, 0)) AS         peer_endorsements_given_all_time_min
--   ,AVG(IFNULL(cub.peer_endorsements_given_all_time, 0)) AS         peer_endorsements_given_all_time_avg
--   ,MAX(IFNULL(cub.peer_endorsements_given_all_time, 0)) AS         peer_endorsements_given_all_time_max
--   ,MIN(IFNULL(cub.peer_endorsements_received, 0)) AS               peer_endorsements_received_min
--   ,AVG(IFNULL(cub.peer_endorsements_received, 0)) AS               peer_endorsements_received_avg
--   ,MAX(IFNULL(cub.peer_endorsements_received, 0)) AS               peer_endorsements_received_max
--   ,MIN(IFNULL(cub.peer_endorsements_received_1_year, 0)) AS        peer_endorsements_received_1_year_min
--   ,AVG(IFNULL(cub.peer_endorsements_received_1_year, 0)) AS        peer_endorsements_received_1_year_avg
--   ,MAX(IFNULL(cub.peer_endorsements_received_1_year, 0)) AS        peer_endorsements_received_1_year_max
--   ,MIN(IFNULL(cub.peer_endorsements_received_all_time, 0)) AS      peer_endorsements_received_all_time_min
--   ,AVG(IFNULL(cub.peer_endorsements_received_all_time, 0)) AS      peer_endorsements_received_all_time_avg
--   ,MAX(IFNULL(cub.peer_endorsements_received_all_time, 0)) AS      peer_endorsements_received_all_time_max
--   ,SUM(IFNULL(cub.delivered_impressions_block, 0)) AS              delivered_impressions_block
--   ,SUM(IFNULL(cub.delivered_impressions_block_network, 0)) AS      delivered_impressions_block_network
--   ,SUM(IFNULL(cub.delivered_impressions_exclusive, 0)) AS          delivered_impressions_exclusive
--   ,SUM(IFNULL(cub.delivered_impressions_exclusive_network, 0)) AS  delivered_impressions_exclusive_network
--   ,MAX(cub.practicing_flag) AS                                     practicing_flag
--    -- These don't need to be aggregated but it's simplest if the SQL thinks they do.
--   ,MAX(IFNULL(mrr.mrr_customer_category, 'NOT BILLED')) AS         mrr_category_in_month
--   ,MAX(IFNULL(mrr.mrr_current_ad, 0)) AS                           mrr_ad_cust
--   ,MAX(IFNULL(mrr.mrr_current_non_ad, 0)) AS                       mrr_non_ad_cust
--   ,MAX(IFNULL(mrr.mrr_current_total, 0)) AS                        mrr_total_cust
--   ,MAX(IFNULL(mrr.revenue_current_ad, 0)) AS                       revenue_ad_cust
--   ,MAX(IFNULL(mrr.revenue_current_non_ad, 0)) AS                   revenue_non_ad_cust
--   ,MAX(IFNULL(mrr.revenue_current_total, 0)) AS                    revenue_total_cust
--   ,MAX(CASE WHEN cpp.primary_professional_id IS NULL THEN 'Problem' ELSE 'OK' END) AS check_primary_pro
-- FROM
--              dm.lawyer_cube_data_by_day cub
--   INNER JOIN dm.date_dim dt
--           ON TO_DATE(cub.as_of_date) = dt.actual_date
--   LEFT OUTER JOIN tmp_data_dm.coe_llc_cust_primary_prof cpp
--           ON cub.professional_id = cpp.customer_id  -- LOOK
--          AND cub.as_of_date = cpp.as_of_date
--   LEFT OUTER JOIN tmp_data_dm.coe_llc_cust_mrr mrr
--           ON cub.professional_id = mrr.customer_id  -- LOOK
--          AND dt.year_month = mrr.year_month
-- WHERE cub.as_of_date BETWEEN '2016-10-11' AND '2016-10-12'
--   AND cub.is_active = 'Y'
-- -- AND professional_id % 1923 = 8
-- GROUP BY 1,2,3,4,5


DROP TABLE tmp_data_dm.coe_llc_cust_primary_prof;
CREATE TABLE tmp_data_dm.coe_llc_cust_primary_prof AS
SELECT
   as_of_date
  ,professional_id AS customer_id  -- LOOK
  ,MAX(professional_id) OVER (PARTITION BY professional_id, as_of_date  -- LOOK
                              ORDER BY mrr DESC) AS primary_professional_id  -- LOOK maybe this should be revenue.
FROM dm.lawyer_cube_data_by_day

DROP TABLE tmp_data_dm.coe_llc_cust_mrr;
CREATE TABLE tmp_data_dm.coe_llc_cust_mrr AS
SELECT
   -- mrr.yearmonth AS year_month
   201610 AS year_month  -- LOOK
  ,mrr.customer_id
  ,mrr.mrr_customer_category
  ,mrr.mrr_current_advertisement AS mrr_current_ad
  ,mrr.mrr_current_avvopro + mrr.mrr_current_ignite + mrr.mrr_current_website + mrr.mrr_current_adplacement AS mrr_current_non_ad
  ,mrr.mrr_current_total
  ,mrr.revenue_current_advertisement AS revenue_current_ad
  ,mrr.revenue_current_avvopro + mrr.revenue_current_ignite + mrr.revenue_current_website + mrr.revenue_current_adplacement AS revenue_current_non_ad
  ,mrr.revenue_current_total
FROM dm.mrr_customer_category_all_products mrr
WHERE mrr.mrr_customer_category <> 'NOT BILLED'
  AND yearmonth = 201609


DROP TABLE tmp_data_dm.coe_llc_cust;
CREATE TABLE tmp_data_dm.coe_llc_cust AS
SELECT
   cub.customer_id
  ,dt.month_begin_date
  ,dt.month_end_date
  ,dt.year_month
  -- ,dt.month_end_date AS                                            as_of_date
  ,cub.as_of_date                                   -- LOOK
  ,COUNT(*) AS                                                     professionals
  ,MAX(1) AS                                                       customers
  ,AVG(cub.avvo_rating) AS                                         avvo_rating
  ,AVG(cub.average_client_review_rating) AS                        average_client_review_rating
  ,AVG(IFNULL(cub.client_reviews, 0)) AS                           client_reviews
  ,AVG(IFNULL(cub.client_reviews_all_time, 0)) AS                  client_reviews_all_time
  ,MAX(cub.last_negative_client_review_date) AS                    last_negative_client_review_date
  ,AVG(IFNULL(cub.negative_client_reviews_all_time, 0)) AS         negative_client_reviews_all_time
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN cub.practice_area ELSE NULL END) AS                               practice_area
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN pa.parent_specialty_name ELSE NULL END) AS                        parent_practice_area
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN cub.top_ad_revenue_practice_area ELSE NULL END) AS                top_ad_revenue_practice_area
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN cub.top_ad_revenue_practice_area_1_year ELSE NULL END) AS         top_ad_revenue_practice_area_1_year
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN cub.top_ad_revenue_parent_practice_area ELSE NULL END) AS         top_ad_revenue_parent_practice_area
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN cub.top_ad_revenue_parent_practice_area_1_year ELSE NULL END) AS  top_ad_revenue_parent_practice_area_1_year
  ,AVG(cub.months_since_first_licensed) AS                         months_since_first_licensed
  ,AVG(cub.months_since_claimed) AS                                months_since_claimed
  ,MIN(cub.first_active_date) AS                                   first_active_date
  ,MAX( 1 +
        ((CAST(STRLEFT(cub.as_of_date, 4) AS INTEGER) - CAST(STRLEFT(cub.first_active_date, 4) AS INTEGER) ) * 12) +
        (CAST(SUBSTR(cub.as_of_date, 6, 2) AS INTEGER) - CAST(SUBSTR(cub.first_active_date, 6, 2) AS INTEGER))
      ) AS tenure_month
  ,SUM(IFNULL(cub.target_impressions, 0)) AS                       target_impressions
  ,SUM(IFNULL(cub.ad_revenue_mtd, 0)) AS                           ad_revenue_prof
  ,SUM(IFNULL(cub.revenue_mtd, 0)) AS                              revenue_prof
  ,SUM(IFNULL(cub.mrr_ad, 0)) AS                                   mrr_ad_prof
  ,SUM(IFNULL(cub.mrr, 0)) AS                                      mrr_prof
  ,MAX(cub.ls_participation) AS                                    ls_participation
  ,MAX(cub.has_ads) AS                                             has_ads
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN IFNULL(reg.state, cub.state) ELSE NULL END) AS  state
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN reg.division ELSE NULL END) AS                  us_division
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN reg.region ELSE NULL END) AS                    us_region
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN reg.time_zone_approx ELSE NULL END) AS          us_time_zone_approx
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN reg.time_zone_offset_approx ELSE NULL END) AS   us_time_zone_offset_approx
  ,MAX(CASE WHEN IFNULL(cpp.primary_professional_id, professional_id) = professional_id
              THEN cub.ad_revenue_state ELSE NULL END) AS          ad_revenue_state
  ,MAX(cub.recent_active_months) AS                                recent_active_months
  ,SUM(IFNULL(cub.visits, 0)) AS                                   visits
  ,SUM(IFNULL(cub.delivered_phone_call_acu, 0) + 
       IFNULL(cub.delivered_email_acu, 0) + 
       IFNULL(cub.delivered_website_contact_acu, 0)) AS            delivered_acu
  ,SUM(IFNULL(cub.delivered_phone_call_acu, 0)) AS                 delivered_phone_call_acu
  ,SUM(IFNULL(cub.delivered_email_acu, 0)) AS                      delivered_email_acu
  ,SUM(IFNULL(cub.delivered_website_contact_acu, 0)) AS            delivered_website_contact_acu
  ,SUM(IFNULL(cub.delivered_phone_calls, 0)) AS                    delivered_phone_calls
  ,SUM(IFNULL(cub.delivered_phone_calls_ge_120s, 0)) AS            delivered_phone_calls_ge_120s
  ,SUM(CASE WHEN IFNULL(cub.delivered_phone_calls, 0) = 0 THEN 0.0
       ELSE IFNULL(cub.delivered_phone_calls_ge_120s, 0) / IFNULL(cub.delivered_phone_calls, 0) END) AS pct_long_phone_calls
  ,SUM(IFNULL(cub.delivered_emails, 0)) AS                         delivered_emails
  ,SUM(IFNULL(cub.delivered_chat_messages, 0)) AS                  delivered_chat_messages
  ,SUM(IFNULL(cub.delivered_chat_conversations, 0)) AS             delivered_chat_conversations
  ,SUM(IFNULL(cub.delivered_website_contacts, 0)) AS               delivered_website_contacts
  ,SUM(IFNULL(cub.delivered_phone_calls, 0)) +
   SUM(IFNULL(cub.delivered_emails, 0)) +
  SUM(IFNULL(cub.delivered_chat_conversations, 0)) +
   SUM(IFNULL(cub.delivered_website_contacts, 0)) AS               delivered_contacts
  ,SUM(IFNULL(cub.target_acv, 0)) AS                               target_acv
  ,SUM(IFNULL(cub.acv, 0)) AS                                      acv
  ,SUM(IFNULL(cub.phone_acv, 0)) AS                                phone_acv
  ,SUM(IFNULL(cub.email_acv, 0)) AS                                email_acv
  ,SUM(IFNULL(cub.website_acv, 0)) AS                              website_acv
  ,AVG(IFNULL(cub.questions_answered, 0)) AS                       questions_answered
  ,AVG(IFNULL(cub.questions_answered_1_year, 0)) AS                questions_answered_1_year
  ,AVG(IFNULL(cub.questions_answered_all_time, 0)) AS              questions_answered_all_time
  ,AVG(IFNULL(cub.peer_endorsements_given, 0)) AS                  peer_endorsements_given
  ,AVG(IFNULL(cub.peer_endorsements_given_1_year, 0)) AS           peer_endorsements_given_1_year
  ,AVG(IFNULL(cub.peer_endorsements_given_all_time, 0)) AS         peer_endorsements_given_all_time
  ,AVG(IFNULL(cub.peer_endorsements_received, 0)) AS               peer_endorsements_received
  ,AVG(IFNULL(cub.peer_endorsements_received_1_year, 0)) AS        peer_endorsements_received_1_year
  ,AVG(IFNULL(cub.peer_endorsements_received_all_time, 0)) AS      peer_endorsements_received_all_time
  ,SUM(IFNULL(cub.delivered_impressions_block, 0)) AS              delivered_impressions_block
  ,SUM(IFNULL(cub.delivered_impressions_block_network, 0)) AS      delivered_impressions_block_network
  ,SUM(CASE WHEN IFNULL(cub.delivered_impressions_block, 0) = 0 THEN 0.0
       ELSE IFNULL(cub.delivered_impressions_block_network, 0) / IFNULL(cub.delivered_impressions_block, 0) END) AS         pct_block_network_impressions
  ,SUM(IFNULL(cub.delivered_impressions_exclusive, 0)) AS          delivered_impressions_exclusive
  ,SUM(IFNULL(cub.delivered_impressions_exclusive_network, 0)) AS  delivered_impressions_exclusive_network
  ,SUM(CASE WHEN IFNULL(cub.delivered_impressions_exclusive, 0) = 0 THEN 0.0
       ELSE IFNULL(cub.delivered_impressions_exclusive_network, 0) / IFNULL(cub.delivered_impressions_exclusive, 0) END) AS pct_exclusive_network_impressions
  ,MAX(cub.practicing_flag) AS                                     practicing_flag
   -- These don't need to be aggregated but it's simplest if the SQL thinks they do.
  ,MAX(IFNULL(mrr.mrr_customer_category, 'NOT BILLED')) AS         mrr_category_in_month
  ,MAX(IFNULL(mrr.mrr_current_ad, 0)) AS                           mrr_ad_cust
  ,MAX(IFNULL(mrr.mrr_current_non_ad, 0)) AS                       mrr_non_ad_cust
  ,MAX(IFNULL(mrr.mrr_current_total, 0)) AS                        mrr_total_cust
  ,MAX(IFNULL(mrr.revenue_current_ad, 0)) AS                       revenue_ad_cust
  ,MAX(IFNULL(mrr.revenue_current_non_ad, 0)) AS                   revenue_non_ad_cust
  ,MAX(IFNULL(mrr.revenue_current_total, 0)) AS                    revenue_total_cust
  ,MAX(CASE WHEN cpp.primary_professional_id IS NULL THEN 'Problem' ELSE 'OK' END) AS check_primary_pro
FROM
             dm.lawyer_cube_data_by_day cub
  -- INNER JOIN dm.date_dim dt  -- LOOK hack
  INNER JOIN (
             SELECT
                actual_date, 
                date_key, day_name, day_short_name, day_nbr_in_wk, day_nbr_in_month, 
                day_nbr_in_qtr, day_nbr_in_year, week_begin_date, week_end_date, 
                week_nbr_in_year, month_name, short_month_name, month_begin_date,
                month_end_date, month_nbr_in_qtr, month_nbr_in_year, qtr_nbr_in_year, 
                year, year_month, mktg_wk_nbr_in_month, mktg_month_nbr_in_qtr, 
                wkday_ind, us_bank_holiday_ind, qtr_begin_ind, qtr_end_ind, 
                month_begin_ind, month_end_ind, year_begin_ind, year_end_ind, 
                rpt_day_nbr_in_year, rpt_wk_nbr_in_year, rpt_year, rpt_wk_begin_date, 
                rpt_prev_year_wk_begin_date, rpt_prev_year_date, etl_load_tag
             FROM dm.date_dim
             WHERE actual_date <> '2016-10-11'
               AND actual_date LIKE '2016%'
             UNION
             SELECT
               '2016-10-11' AS actual_date, 
                date_key, day_name, day_short_name, day_nbr_in_wk, day_nbr_in_month, 
                day_nbr_in_qtr, day_nbr_in_year, week_begin_date, week_end_date, 
                week_nbr_in_year, month_name, short_month_name, month_begin_date,
                month_end_date, month_nbr_in_qtr, month_nbr_in_year, qtr_nbr_in_year, 
                year, year_month, mktg_wk_nbr_in_month, mktg_month_nbr_in_qtr, 
                wkday_ind, us_bank_holiday_ind, qtr_begin_ind, qtr_end_ind, 
                month_begin_ind, month_end_ind, year_begin_ind, year_end_ind, 
                rpt_day_nbr_in_year, rpt_wk_nbr_in_year, rpt_year, rpt_wk_begin_date, 
                rpt_prev_year_wk_begin_date, rpt_prev_year_date, etl_load_tag
             FROM dm.date_dim
             WHERE actual_date = '2016-09-01'
             ) dt
          ON TO_DATE(cub.as_of_date) = dt.actual_date
  LEFT OUTER JOIN tmp_data_dm.coe_llc_cust_primary_prof cpp
          ON cub.customer_id = cpp.customer_id
         AND cub.as_of_date = cpp.as_of_date
  LEFT OUTER JOIN tmp_data_dm.coe_llc_cust_mrr mrr
          ON cub.customer_id = mrr.customer_id
         AND dt.year_month = mrr.year_month
  LEFT OUTER JOIN dm.specialty_dimension pa
          ON cub.practice_area = pa.specialty_name
  LEFT OUTER JOIN tmp_data_dm.coe_state_x_us_region reg
          ON LOWER(cub.state) = LOWER(reg.state)
WHERE cub.as_of_date BETWEEN '2016-10-11' AND '2016-10-17'
  AND cub.is_active = 'Y'
-- AND professional_id % 1923 = 8
GROUP BY 1,2,3,4,5

-- SELECT * FROM tmp_data_dm.coe_llc_cust


So, for tenure_months, for example:
- Want to categorize, such as 1-3m, 4-6m, 7-12m, etc.
- Want to calculate average tenure for a segment of customers.

----

Prepare for friday demo:

Pull time of day for claims.
Look at average review score and rating by whether they had neg review.
Something comparing reported PA with revenue PA?

Does personal injury really stick to itself?

SELECT
   as_of_date
  ,COUNT(DISTINCT professional_id) AS professionals
  ,COUNT(*) AS num_rows
FROM dm.lawyer_cube_data_by_day
GROUP BY 1 ORDER BY 1

SELECT
*
FROM dm.lawyer_cube_data_by_day
WHERE is_active = 'Y'
-- WHERE first_active_date = '2016-07-16'

=IF(AND(M2>0, N2<>M2, O2<>N2),"look","")

SELECT
   HOUR(claim_date) AS claim_hour
  ,COUNT(*) AS professionals
FROM dm.lawyer_cube_data_by_day
WHERE as_of_date = '2016-10-15'
  AND YEAR(claim_date) IN (2015, 2016)
GROUP BY 1
ORDER BY 1


SELECT
   HOUR(cub.claim_date) AS claim_hour
  ,cub.state
  ,reg.region
  ,reg.time_zone_approx
  ,reg.time_zone_offset_approx
  ,(HOUR(cub.claim_date) + 24 + reg.time_zone_offset_approx) % 24 AS adjusted_hour
  ,COUNT(*) AS professionals
  ,AVG(cub.avvo_rating) AS avvo_rating
FROM         dm.lawyer_cube_data_by_day cub
  LEFT OUTER JOIN tmp_data_dm.coe_state_x_us_region reg
          ON LOWER(cub.state) = LOWER(reg.state)
WHERE cub.as_of_date = '2016-10-15'
  AND YEAR(cub.claim_date) IN (2015, 2016)
  AND reg.time_zone_short IN ('EST', 'CST', 'MST', 'PST')
GROUP BY 1,2,3,4,5,6

113 fields
Sample lawyer.
Look at code in lab book 2016_08_16 customer dataset pieces b.sql.
Note types of data wanted.
Have to get fancy to find primary practice area.
Ah yeah, in the reviews query, I learned I had to filter to just lawyers.
Oh wait... that''s the old code!
New code is in lab book 2016_10_18 lawyer lifecycle prof.sql.
Use that to get 2 lawyers.
To CSV.
To Excel.
Transpose and resize columns.
Look at things like reviews and stuff.


Run simple query.
What about time zone?
Run query.
Download as CSV.
Copy to clipboard.
New Tableau report.
Paste into Tableau.
Drag Claim Hour to Dimensions.
Select Claim Hour and Professionals and click Show Me -> Bar.
Swap rows and columns.
Drag Region onto Rows.
Exclude NULL, Alaska, and Hawaii.
On chart, drag a region to re-sort. (Eastern, Central, Mountain, Pacific)
On SUM(Professionals), Quick Table Calculation -> Percent of total.
NOTE: who knows if statistically significant.  This kind of exploration
  is great to figure out which hypotheses you might want to look into further.
Drag Professionals onto Level of Detail.
Color by Avvo Rating.
On the Avvo Rating pill, change aggregation to average.
Edit Color -> Stepped.
Duplicate sheet
Replace Claim Hour with Adjusted Hour
Wow!



-- Change Time Zone Offset Approx data type to Number (Whole)
-- Create Calculated Field:
--   Adjusted Hour
--   [Claim Hour]+[Time Zone Offset Approx]
Drag in State after Region.
Drag in State as filter -> CA and NY.


-- SELECT
--    HOUR(cub.claim_date) AS claim_hour
--  ,(HOUR(cub.claim_date) + 24 - 2) % 24 AS hour_minus_2
--  ,(HOUR(cub.claim_date) + 24 - 1) % 24 AS hour_minus_1
--  ,(HOUR(cub.claim_date) + 24 + 0) % 24 AS hour_plus_0
--  ,(HOUR(cub.claim_date) + 24 + 1) % 24 AS hour_plus_1
--  ,(HOUR(cub.claim_date) + 24 + 2) % 24 AS hour_plus_2
--  ,(HOUR(cub.claim_date) + 24 + 3) % 24 AS hour_plus_3
-- FROM 
-- (SELECT * FROM
--   (
--         SELECT '2016-07-16 00:01:01' AS claim_date
--   UNION SELECT '2016-07-16 01:01:01' AS claim_date
--   UNION SELECT '2016-07-16 02:01:01' AS claim_date
--   UNION SELECT '2016-07-16 03:01:01' AS claim_date
--   UNION SELECT '2016-07-16 04:01:01' AS claim_date
--   UNION SELECT '2016-07-16 05:01:01' AS claim_date
--   UNION SELECT '2016-07-16 20:01:01' AS claim_date
--   UNION SELECT '2016-07-16 21:01:01' AS claim_date
--   UNION SELECT '2016-07-16 22:01:01' AS claim_date
--   UNION SELECT '2016-07-16 23:01:01' AS claim_date
--   ) qry
-- ) cub
-- ORDER BY 1

SELECT
   yearmonth AS year_month
  ,DATEDIFF(order_line_begin_date, order_line_purchase_date) AS days_from_begin_to_purchase
  ,COUNT(*) AS order_lines
FROM dm.order_line_accumulation_fact
WHERE order_line_purchase_date >= '2014-01-01'
GROUP BY 1,2

IF [Days From Begin To Purchase] = 1 THEN '1 day'
ELSEIF [Days From Begin To Purchase] >= 0 AND [Days From Begin To Purchase] <= 62 THEN STR([Days From Begin To Purchase])+' days'
ELSEIF [Days From Begin To Purchase] >= 63 AND [Days From Begin To Purchase] <= 100 THEN '32 - 100 days'
ELSEIF [Days From Begin To Purchase] >= 101 AND [Days From Begin To Purchase] <= 365 THEN '100 - 365 days'
ELSEIF [Days From Begin To Purchase] >= 366 THEN '366+ days'
ELSEIF [Days From Begin To Purchase] >= -31 AND [Days From Begin To Purchase] <= -1 THEN '-31 to -1 days'
ELSE '<= -32 days'
END

SELECT
   olaf.yearmonth AS year_month
  ,DATEDIFF(olaf.order_line_begin_date, olaf.order_line_purchase_date) AS days_from_begin_to_purchase
  ,olaf.order_line_begin_date
  ,olaf.order_line_purchase_date
  ,prod.product_line_class_name
  ,COUNT(*) AS order_lines
FROM dm.order_line_accumulation_fact olaf
  INNER JOIN product_line_dimension prod
          ON olaf.product_line_id = prod.product_line_id
WHERE olaf.order_line_purchase_date >= '2014-01-01'
GROUP BY 1,2,3,4,5

IF [Days From Begin To Purchase] = 1 THEN '1 day'
ELSEIF [Days From Begin To Purchase] >=   0 AND [Days From Begin To Purchase] <=  32 THEN STR([Days From Begin To Purchase])+' days'
ELSEIF [Days From Begin To Purchase] >=  33 AND [Days From Begin To Purchase] <=  58 THEN  '33 - 58 days'
ELSEIF [Days From Begin To Purchase] >=  59 AND [Days From Begin To Purchase] <=  62 THEN STR([Days From Begin To Purchase])+' days'
ELSEIF [Days From Begin To Purchase] >=  63 AND [Days From Begin To Purchase] <=  88 THEN  '63 - 88 days'
ELSEIF [Days From Begin To Purchase] >=  89 AND [Days From Begin To Purchase] <=  92 THEN STR([Days From Begin To Purchase])+' days'
ELSEIF [Days From Begin To Purchase] >=  93 AND [Days From Begin To Purchase] <= 182 THEN  '93 - 182 days'
ELSEIF [Days From Begin To Purchase] >= 183 AND [Days From Begin To Purchase] <= 366 THEN '183 - 366 days'
ELSEIF [Days From Begin To Purchase] >= 367 THEN '367+ days'
ELSEIF [Days From Begin To Purchase] >= -31 AND [Days From Begin To Purchase] <= -1 THEN '-31 to -1 days'
ELSE '<= -32 days'
END

Lawyer''s lifecycle
In directory
Claim Profile
Become Advertiser
Upsell

And events that might shape propensity or length of time:
Client Review
Profile Views
LS Participation
LS Sale

