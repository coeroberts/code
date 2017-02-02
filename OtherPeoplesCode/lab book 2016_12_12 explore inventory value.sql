Inventory value

SELECT
   year_month
  ,market_type AS          inventory_type
  ,SUM(sl_value) AS       sl_value
  ,SUM(sl_sold_value) AS  sl_sold_value
  ,SUM(sl_revenue) AS     sl_revenue
  ,SUM(da_value) AS       da_value
  ,SUM(da_sold_value) AS  da_sold_value
  ,SUM(da_revenue) AS     da_revenue
FROM dm.market_intelligence_detail
WHERE year_month BETWEEN 201411 AND 201611
GROUP BY 1,2
ORDER BY 1,2

Only 201510 on available.

SEM and paid inventory is only block.

Yep this matches the $ inventory from the charts I am trying to replicate.

----

Attempt at getting conversion % of 16 no way

SELECT
   dt.year_month
  ,waa.page_type
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
  -- LEFT OUTER JOIN dm.ad_dimension ad ON waa.ad_id = ad.ad_id
GROUP BY 1,2

SELECT
   dt.year_month
  ,waa.page_type
  ,SUM(waa.email_attributed_count) AS              email_acu  -- want this one.  LOOK!!! need to multiply this by 2.
  ,SUM(waa.website_attributed_count) AS            website_acu  -- want this one.
  ,SUM(waa.phone_attributed_count) AS              phone_acu  -- want this one.
  ,SUM(2 * waa.email_attributed_count) AS              email_acu_x2  -- want this one.  LOOK!!! need to multiply this by 2.
FROM dm.webanalytics_ad_attribution_v0 waa
  INNER JOIN dm.date_dim dt
          ON waa.attribution_date = dt.actual_date
         AND dt.year_month BETWEEN 201601 AND 201610
  -- LEFT OUTER JOIN dm.ad_dimension ad ON waa.ad_id = ad.ad_id
GROUP BY 1,2

----

SELECT
   dt.year_month
  ,SUM(waa.adjusted_attribution_value) AS          avc_delivered  -- This is total minus organic.
FROM dm.webanalytics_ad_attribution_v0 waa
  INNER JOIN dm.date_dim dt
          ON waa.attribution_date = dt.actual_date
         AND dt.year_month >= 201412
GROUP BY 1
ORDER BY 1

Block, exclusive, and display
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

SELECT
   dt.year_month
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
  ,SUM(waa.adjusted_attribution_value) AS          acv_delivered  -- want this one.  This is total minus organic.
FROM dm.webanalytics_ad_attribution_v0 waa
  INNER JOIN dm.date_dim dt
          ON waa.attribution_date = dt.actual_date
         AND dt.year_month between 201506 and 201611
  LEFT OUTER JOIN dm.ad_dimension ad ON waa.ad_id = ad.ad_id
GROUP BY 1,2
----

Trying to find ACV by paid and unpaid:

Channels included in M2 paid channel classification:
SEM - Adblock
SEM - Network
Paid Call Channels - Marchex
Paid Call Channels - eLocal
Paid Call Channels - SEM Call Ext
Marketing - SEM Brand
Marketing - SEM Nonbrand

If you click directly on the ad and it takes you to atty website it’s ad_click.
If you click on ad, then go to atty profile page, and then you click on website, 

Non-associated means the user has never seen the atty’s ad.
That is the one that we adjust.  Associated they have, and ratio is
(almost) always 1.

NOTE that ac_click_count SHOULD factor into ACV but is not in 
total_acv in _v0 because it should never be adjusted.

ad_click is NEVER adjusted.
email and website are NOT adjusted for associated, and they are adjusted for 
  non-associated.
Phone is ALWAYS adjusted, whether associated or non.  It may still
  be tagged as associated, if the user viewed an ad within 10 minutes
  before the call, but this would be a case where an associated 
  contact does get adjusted.
