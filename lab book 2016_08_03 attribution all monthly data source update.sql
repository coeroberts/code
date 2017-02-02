From Nadine:
We need to update the Attribution_All Monthly data source on Tableau 
server that feeds the Finance dashboards.  I was thinking we had 
already made the change, but it was still the old data source.  I 
think it needs to be DM.ad_attribution_v0_all.
The numbers change slightly so we need to make sure we understand the 
differences before publishing/changing to the new table.  Slobodan 
had kept the previous table running, but we needed to move to the new 
one.  I’m looking at ACV right now because although traffic was up, 
ACV was down in July (as were contacts) so we’re trying to understand 
what’s happening. 



Current code:

select aa.ad_market_key 
    , am.ad_mkt_state_name 
    , am.ad_mkt_cnty_name
    , am.ad_mkt_regn_name
    , am.ad_mkt_speclty_name
    , aa.page_type 
    , ad.ad_detail_typ
    --, dm.actual_date 
    , dm.YEAR_MONTH
    , SUM(aa.adjusted_attribution_value) AS adjusted_attribution_value
    , SUM(aa.ad_click_count) AS ad_click_count
    , SUM(aa.email_attributed_count) AS email_attributed_count
                , SUM(aa.email_attributed_value) AS email_attributed_value
    , SUM(aa.phone_attributed_count) AS phone_attributed_count
                , SUM(aa.phone_attributed_value) AS phone_attributed_value
    , SUM(aa.website_attributed_count) AS website_attributed_count
                , SUM(aa.website_attributed_value) AS website_attributed_value
    , SUM(aa.total_attributed_value) AS total_attributed_value
  from  DM.attribution_all aa 
  JOIN DM.DATE_DIM DM ON DM.actual_date = aa.attribution_date
  join dm.ad_dim ad on ad.ad_id = aa.ad_id
  left join dm.ad_mkt_dim am on am.ad_mkt_key = aa.ad_market_key
GROUP BY 1,2,3,4,5,6,7,8

SELECT
   ad_detail_typ AS                    ad_detail_type
  ,SUM(adjusted_attribution_value) AS  adjusted_attribution_value
  ,SUM(ad_click_count) AS              ad_click_count
  ,SUM(email_attributed_count) AS      email_attributed_count
  ,SUM(email_attributed_value) AS      email_attributed_value
  ,SUM(phone_attributed_count) AS      phone_attributed_count
  ,SUM(phone_attributed_value) AS      phone_attributed_value
  ,SUM(website_attributed_count) AS    website_attributed_count
  ,SUM(website_attributed_value) AS    website_attributed_value
  ,SUM(total_attributed_value) AS      total_attributed_value
FROM
(
SELECT aa.ad_market_key 
    , am.ad_mkt_state_name 
    , am.ad_mkt_cnty_name
    , am.ad_mkt_regn_name
    , am.ad_mkt_speclty_name
    , aa.page_type 
    , ad.ad_detail_typ
    --, dm.actual_date 
    , dm.year_month
  ,SUM(aa.adjusted_attribution_value) AS  adjusted_attribution_value
  ,SUM(aa.ad_click_count) AS              ad_click_count
  ,SUM(aa.email_attributed_count) AS      email_attributed_count
  ,SUM(aa.email_attributed_value) AS      email_attributed_value
  ,SUM(aa.phone_attributed_count) AS      phone_attributed_count
  ,SUM(aa.phone_attributed_value) AS      phone_attributed_value
  ,SUM(aa.website_attributed_count) AS    website_attributed_count
  ,SUM(aa.website_attributed_value) AS    website_attributed_value
  ,SUM(aa.total_attributed_value) AS      total_attributed_value
  FROM  dm.attribution_all aa 
  JOIN dm.date_dim dm ON dm.actual_date = aa.attribution_date
  JOIN dm.ad_dim ad ON ad.ad_id = aa.ad_id
  LEFT JOIN dm.ad_mkt_dim am ON am.ad_mkt_key = aa.ad_market_key
GROUP BY 1,2,3,4,5,6,7,8
) qry
WHERE year_month = 201605
  -- AND ad_market_key = 208667
GROUP BY 1

Revised:
SELECT
   ad_detail_typ AS                    ad_detail_type
  ,SUM(adjusted_attribution_value) AS  adjusted_attribution_value
  ,SUM(ad_click_count) AS              ad_click_count
  ,SUM(email_attributed_count) AS      email_attributed_count
  ,SUM(email_attributed_value) AS      email_attributed_value
  ,SUM(phone_attributed_count) AS      phone_attributed_count
  ,SUM(phone_attributed_value) AS      phone_attributed_value
  ,SUM(website_attributed_count) AS    website_attributed_count
  ,SUM(website_attributed_value) AS    website_attributed_value
  ,SUM(total_attributed_value) AS      total_attributed_value
FROM
(
SELECT
   aa.ad_market_id 
  ,am.ad_market_state_name AS             ad_mkt_state_name
  ,am.ad_market_county_name AS            ad_mkt_cnty_name
  ,am.ad_market_region_name AS            ad_mkt_regn_name
  ,am.ad_market_specialty_name AS         ad_mkt_speclty_name
  ,aa.page_type 
  ,ad.ad_detail_type AS                   ad_detail_typ
  ,dt.year_month
  ,SUM(aa.adjusted_attribution_value) AS  adjusted_attribution_value
  ,SUM(aa.ad_click_count) AS              ad_click_count
  ,SUM(aa.email_attributed_count) AS      email_attributed_count
  ,SUM(aa.email_attributed_value) AS      email_attributed_value
  ,SUM(aa.phone_attributed_count) AS      phone_attributed_count
  ,SUM(aa.phone_attributed_value) AS      phone_attributed_value
  ,SUM(aa.website_attributed_count) AS    website_attributed_count
  ,SUM(aa.website_attributed_value) AS    website_attributed_value
  ,SUM(aa.total_attributed_value) AS      total_attributed_value
  FROM       dm.ad_attribution_v0_all aa 
  INNER JOIN dm.date_dim dt ON dt.actual_date = aa.attribution_date
  INNER JOIN dm.ad_dimension ad ON ad.ad_id = aa.ad_id
  LEFT OUTER JOIN dm.ad_market_dimension am ON am.ad_market_id = aa.ad_market_id
GROUP BY 1,2,3,4,5,6,7,8
) qry
WHERE year_month = 201605
  -- AND ad_market_id = 712441
GROUP BY 1

