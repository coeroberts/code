-- If you have any reports / dashboards reporting ACV data, please don’t forget to incorporate ACV generated from partner sources such as Marchex and elocal.
-- Below is a sample query based on attribution table v0, partner generated ACV is classified into SL. 
-- @Elisabeth, you may want to use the same logic for AM performance dashboard, let me know if you have any questions.
 
select x.professional_id
   , x.ad_market_id
   , x.ad_detail_type
   , x.customer_id
   , x.year_month
   , sum(x.ADJ_ATTRIB_VALUE) as ADJ_ATTRIB_VALUE
from
(
               select ARVSF.professional_id
                , ARVSF.AD_MARKET_ID
                , ad.ad_detail_type
                , ARVSF.customer_id
                , cast(
                       concat(
                              cast(year(ARVSF.attribution_date) as string)
                              , lpad(cast(month(ARVSF.attribution_date) as string),2,'0')
                             ) 
                   as int) as YEAR_MONTH
                , SUM(ARVSF.adjusted_attribution_value) AS ADJ_ATTRIB_VALUE
               from DM.webanalytics_ad_attribution_v0 ARVSF 
                   join dm.ad_dimension ad on ad.ad_id = arvsf.ad_id
               where ARVSF.attribution_date <= now()
                and year(ARVSF.attribution_date) >= extract(now()- interval 5 month, "year")
                and month(ARVSF.attribution_date) >= extract(now()- interval 5 month, "month")
                and arvsf.partner_source is null
               GROUP BY 1,2,3,4,5
               
               union all
               
               select ARVSF.professional_id
               , ARVSF.AD_MARKET_ID
               , 'Sponsored Listing' as ad_detail_type
               , ARVSF.customer_id
               , cast(
                      concat(
                             cast(year(ARVSF.attribution_date) as string)
                             , lpad(cast(month(ARVSF.attribution_date) as string),2,'0')
                            ) 
                        as int) as YEAR_MONTH
               , SUM(ARVSF.adjusted_attribution_value) AS ADJ_ATTRIB_VALUE
               from DM.webanalytics_ad_attribution_v0 ARVSF 
               where ARVSF.attribution_date <= now()
                 and year(ARVSF.attribution_date) >= extract(now()- interval 5 month, "year")
                 and month(ARVSF.attribution_date) >= extract(now()- interval 5 month, "month")
                 and arvsf.partner_source is not null
               GROUP BY 1,2,3,4,5
) x 
group by 1,2,3,4,5
