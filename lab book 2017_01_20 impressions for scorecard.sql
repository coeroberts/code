Ad slots filled
Where do we have a market where we have fulfilled the impressions and potentially we would open up new slots.
Maybe sold inventory / inventory?

Impressions - base on deferred revenue.
Has to be prof and market.
# delivered impressions
# target impressions
# impressions overdelivered
# impressions underdelivered
# advertisers overdelivered - but mebe too complicated
# advertisers underdelivered - but mebe too complicated

Clicks - this is ad_clicks; do we have a reliable data source for it?  LOOK come back to me.

So... evaluate over/under at pro / market (and maybe cust).
Then roll up.

----
Coe Roberts
quick question, which you probably know the answer to because of 
deferred revenue: we always can get target impressions, right, 
whether Display or SL, and Block or Exclusive?

Katherine Baer 
display block and sl block yes
exclusive, we... don't... have a target? i thought?
it's just "100%"
----

SELECT
   drv.year_month
  ,SUM(target_impressions) AS             target_impressions
  ,SUM(ad_impressions) AS                 actual_impressions
  ,SUM(CASE WHEN over_under >= 0 THEN over_under ELSE 0 END) AS overdelivered_impressions
  ,SUM(CASE WHEN over_under <  0 THEN over_under ELSE 0 END) AS underdelivered_impressions
FROM
  (
  SELECT
     dr.ad_market_id
    ,dr.professional_id
    ,dr.customer_id
    ,CASE WHEN dr.ad_type LIKE 'Display%' THEN 'Display' ELSE dr.ad_type END AS ad_type
    ,dr.block_cancel_flag AS        cancelled_in_current_month
    ,dr.ad_impression_count AS      ad_impressions
    ,dr.target_impression_count AS  target_impressions
    ,dr.ad_sold_price
    ,dr.yearmonth AS year_month
    ,lm.last_month
    ,IFNULL(dr.ad_impression_count, 0) - IFNULL(dr.target_impression_count, 0) AS over_under
  FROM dm.deferred_revenue dr
  CROSS JOIN (SELECT CAST(from_unixtime(unix_timestamp(now() - interval 1 months), 'yyyyMM') AS INT) AS last_month) lm
        -- Jan for SL; Feb for Display
  WHERE (   (dr.ad_type NOT LIKE 'Display%') AND (dr.yearmonth BETWEEN 201501 AND lm.last_month)
         OR (dr.ad_type     LIKE 'Display%') AND (dr.yearmonth BETWEEN 201602 AND lm.last_month))
    AND dr.block_cancel_flag = 'N'
  ) drv
GROUP BY 1 ORDER BY 1
