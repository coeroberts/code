-- This is information on delivered ad impressions, and the recent 
-- dive into why reports differ.

-- The attached query gives delivered impression results that match the 
-- ad_rotation logic.   There are a number of places where we currently 
-- show impressions, and here are reasons why they differ:
--     Ad_rotation:  let’s consider this our best source of truth for 
--             impressions to an advertiser in a given ad market.
--     Impressions_forecast:  this has the ad_id at the lowest grain 
--             which causes discrepancies with the ad_rotation for 
--             various reasons – current example is when ad_id changes 
--             mid-month in an ad_market and the delivered impressions 
--             resets to 0 when the new ad_id shows up
--         Gowthami has a ticket to account for this in a new view 
--             she’s creating for the SEM team that uses this table as 
--             the basis
--         This table is mostly used for the SEM team to understand 
--             where they need to drive network traffic
--     Ad Performance Dashboard:  it uses a version of the attached 
--             query, but without the join to the pageview table, and 
--             that typically means the impressions will be a little 
--             higher than the other sources because not every event 
--             in the ad_request + ad_impression join actually happens 
--             and shows up on the pageview table
--         We should change this at some point so that it more closely 
--             matches the ad_rotation logic
--     Deferred_revenue:  this uses the same logic as Ad Performance 
--             Dashboard
--         We will queue this up with the data engineers to change the 
--         source (probably early Q4 ticket & Coe will need to work 
--           with Finance on changed data)

-- If you have a need to pull impressions delivered for an advertiser, 
-- please use the attached query. 
----

with 
delivered_imprsn as (
SELECT d.session_id
,max(imp.event_date) as event_date
,imp.ad_id
,amd.ad_market_id
,req.ad_type
,p.professional_id 
,p.professional_email_address_name 
,p.professional_first_name 
,p.professional_middle_name 
,p.professional_last_name 
,cust.customer_id
,cust.customer_name
,count(DISTINCT imp.ad_impression_guid) imps
, max(dd.year_month) as year_month
FROM ${srcDatabase}.ad_impression imp
JOIN ${srcDatabase}.ad_request req ON 
    req.ad_request_guid = imp.ad_request_guid 
    and ad_type in ('sponsored_listing_ad','sponsored_listing','display_ad')
    and req.event_date = cast(date_sub(FROM_UNIXTIME(UNIX_TIMESTAMP(),'yyyy-MM-dd'),1) as string)
    and imp.event_date =cast(date_sub(FROM_UNIXTIME(UNIX_TIMESTAMP(),'yyyy-MM-dd'),1) as string)
JOIN specialty_dimension sd ON 
    req.specialty_id = sd.specialty_id
JOIN ad_region_dimension ard ON 
    req.sales_region_id = ard.ad_region_id
JOIN ad_market_dimension amd ON 
    amd.specialty_id = sd.specialty_id
     and amd.ad_region_id = ard.ad_region_id
     AND amd.ad_market_active_flag = 'Y'
     AND amd.ad_market_block_flag = 'Y'
JOIN ad_customer_professional_map mp on 
    mp.ad_id = imp.ad_id
JOIN professional_dimension p ON 
    p.professional_id = mp.professional_id
and p.professional_delete_indicator = 'Not Deleted'
join date_dim dd on 
    imp.event_date =dd.actual_date
LEFT JOIN customer_dimension cust ON cust.customer_id = mp.customer_id
LEFT JOIN (SELECT render_instance_guid
,max(session_id) session_id
,max(event_date) event_date
FROM ${srcDatabase}.page_view
WHERE session_id IS NOT NULL
AND persistent_session_id IS NOT NULL
AND render_instance_guid IS NOT NULL
AND render_instance_guid <> 'dummy-value-replaced-by-javascript'
and event_date =cast(date_sub(FROM_UNIXTIME(UNIX_TIMESTAMP(),'yyyy-MM-dd'),1) as string)
GROUP BY render_instance_guid
) d ON d.render_instance_guid = req.render_instance_guid
AND d.event_date = req.event_date
GROUP BY d.session_id
,imp.ad_id
,amd.ad_market_id
,req.ad_type
,p.professional_id
,p.professional_email_address_name
,p.professional_first_name
,p.professional_middle_name
,p.professional_last_name
,cust.customer_id
,cust.customer_name
), 
session_network as (
  SELECT event_date,session_id,medium,content
FROM (
  SELECT event_date ,session_id
      ,CASE WHEN regexp_extract(url, 'utm_medium=(\\w|%)*', 0) = 'utm_medium=sem' THEN 'sem' ELSE 'nonsem' END AS medium
      ,CASE WHEN regexp_extract(url, 'utm_content=(\\w|%)*', 0) = 'utm_content=sgt' THEN 'network'
            WHEN regexp_extract(url, 'utm_content=(\\w|%)*', 0) = 'utm_content=adblock' THEN 'adblock'
            ELSE 'other' END AS content
      ,row_number() OVER (PARTITION BY session_id ORDER BY gmt_timestamp ASC) rankNum
   FROM ${srcDatabase}.page_view
   WHERE session_id IS NOT NULL
   AND event_date =cast(date_sub(FROM_UNIXTIME(UNIX_TIMESTAMP(),'yyyy-MM-dd'),1) as string)
   AND persistent_session_id IS NOT NULL
   AND render_instance_guid IS NOT NULL
   AND render_instance_guid <> 'dummy-value-replaced-by-javascript'
    ) sessions
WHERE sessions.rankNum = 1
  )
SELECT di.event_date
,di.ad_id
,di.ad_market_id
,di.ad_type
,sn.medium
,sn.content
,di.professional_id
,di.professional_email_address_name
,di.professional_first_name
,di.professional_middle_name
,di.professional_last_name
,di.customer_id
,di.customer_name 
,sum(di.imps) as daily_imprsn_cnt
,max(to_date(current_timestamp())) as etl_load_date
,year_month
from delivered_imprsn di
join session_network sn on 
di.session_id = sn.session_id
and di.event_date=sn.event_date
group by 
di.event_date,di.ad_id,di.ad_market_id,di.ad_type,di.professional_id,di.professional_email_address_name,di.professional_first_name,
di.professional_middle_name,di.professional_last_name,di.customer_id,di.customer_name,di.year_month,sn.medium,sn.content;