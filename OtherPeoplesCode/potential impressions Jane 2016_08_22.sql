From: Jane Wang 
Sent: Thursday, August 11, 2016 4:33 PM
To: Yantao Wang <ywang@avvo.com>; Yuhang An <yan@avvo.com>
Subject: RE: sem impressions by channel

Hi there,

In case you need it, here’s the query I modified a bit to pull potential impressions by ad market, page type and channel.

select cast(concat(cast(year(a.event_date) as string), lpad(cast(month(a.event_date) as string),2,'0')) as int) as year_month
               , a.ad_market_id
               , a.state
               , a.county
               , a.region
               , a.specialty_name
               , a.parent_specialty_name
               , a.block_flag
               , case when a.page in ('Attorney_Directory_Browse', 'Attorney_Search') then 'Lawyer SERP'
                                             when a.page in ('Attorney_Profile','Attorney_Profile_Aboutme','Attorney_Profile_Contact','Attorney_Profile_Endorsement','Attorney_Profile_Review','Attorney_Review') then 'Lawyer Profile'
                                             else 'Others' end as page
               , case when a.ad_type in ('sponsored_listing_ad','sponsored_listing') then 'Sponsored Listing' else 'Display' end as ad_type 
               , b.medium
               , sum(a.num_ads_requested) as num_ads_requested         
from 
(
               select ar.*
                              , pv.session_id
                              , pv.page_type as page
                              , amd.ad_market_id                       
                              , amd.ad_market_state_name as state
                              , amd.ad_market_county_name as county
                              , amd.ad_market_region_name as region
                              , sd.specialty_name
                              , sd.parent_specialty_name
                              , amd.ad_market_block_flag as block_flag
               from src.ad_request ar 
               join src.page_view pv on pv.render_instance_guid = ar.render_instance_guid
                              and pv.event_date = ar.event_date
               left join dm.specialty_dimension sd on ar.specialty_id = sd.specialty_id                      
               left join dm.ad_region_dimension ard on ar.sales_region_id = ard.ad_region_id                     
               left join dm.ad_market_dimension amd on amd.specialty_id = sd.specialty_id and amd.ad_region_id = ard.ad_region_id      
               where ar.ad_type in ('sponsored_listing_ad','sponsored_listing','display_ad','display_medium_rectangle')            
                              and ar.event_date between '2016-05-01' and '2016-07-31'
) a
join 
(
               select event_date
                              , session_id
                              , medium
               from 
               (
                              select event_date
                                             , session_id
                                             , case when url like '%utm_campaign=brand%' then 'brand'              
                                                                           when url like '%utm_campaign=pls%'  then 'pls'
                                                                           when url like '%utm_content=sgt%' then 'network'
                                                                           when url like '%utm_campaign=adblock%' then 'adblock' else 'nonsem' end as medium            
                  ,row_number() OVER (PARTITION BY session_id ORDER BY gmt_timestamp ASC) rankNum
                              from src.page_view
                              WHERE session_id IS NOT NULL 
                              AND persistent_session_id IS NOT NULL
                              AND render_instance_guid IS NOT NULL
                              and event_date between '2016-05-01' and '2016-07-31'
               ) c
               where rankNum=1
) b on b.event_date = a.event_date and b.session_id = a.session_id
group by 1,2,3,4,5,6,7,8,9,10,11

From: Yantao Wang 
Sent: Thursday, August 11, 2016 10:19 AM
To: Jane Wang <jwang@avvo.com>; Yuhang An <yan@avvo.com>
Subject: sem impressions by channel

create table tmp_data_dm.yw_imp as (
               select hacpm.customer_id
               ,12*(year(g.event_date)-2013)+month(g.event_date) as months
                  -- ,sum(g.imps) as imps
                  -- ,sum(CASE g.medium WHEN 'sem' THEN g.imps else 0 END) AS sem_imps
                  ,sum(CASE g.medium WHEN 'nonsem' THEN g.imps else 0 END) AS nonsem_imps
                  ,sum(CASE g.medium WHEN 'brand' THEN g.imps else 0 END) AS brand_imps
                  ,sum(CASE g.medium WHEN 'pls' THEN g.imps else 0 END) AS pls_imps
       ,sum(CASE g.medium WHEN 'adblock' THEN g.imps else 0 END) AS adblock_imps
       ,sum(CASE g.medium WHEN 'network' THEN g.imps else 0 END) AS network_imps
               from (
                              select a.ad_id, a.event_date,b.medium
                              ,count(distinct a.ad_impression_guid) as imps
                              from (select ai.ad_id,ai.event_date,ai.ad_impression_guid
                                             ,pv.session_id
                                             from src.ad_impression ai
                                             join src.ad_request ar
                                             on ai.ad_request_guid=ar.ad_request_guid and ai.event_date=ar.event_date
                                             join src.page_view pv
                                             on ar.render_instance_guid=pv.render_instance_guid and ar.event_date=pv.event_date
                                             WHERE pv.session_id IS NOT NULL 
                                             AND pv.persistent_session_id IS NOT NULL
                                             AND pv.render_instance_guid IS NOT NULL
                                             and pv.event_date between '2014-06-01' and '2016-07-31'
                                             and ai.event_date between '2014-06-01' and '2016-06-31'
                                             and ar.event_date between '2014-06-01' and '2016-06-31') a
                              join (
                                             select event_date,session_id,medium
                                             from (
                                                            select event_date,session_id
--                                                                        ,CASE WHEN regexp_extract(url, 'utm_medium=(\\w|%)*', 0) = 'utm_medium=sem' THEN 'sem'
--                                                                                       ELSE 'nonsem' END AS medium
                    ,case when url like '%utm_campaign=brand%' then 'brand'              
                         when url like '%utm_campaign=pls%'  then 'pls'
                          when url like '%utm_content=sgt%' then 'network'
                          when url like '%utm_campaign=adblock%' then 'adblock'
                          else 'nonsem' end as medium            
                                                                           ,row_number() OVER (PARTITION BY session_id ORDER BY gmt_timestamp ASC) rankNum
                                                            from src.page_view
                                                            WHERE session_id IS NOT NULL 
                                                            AND persistent_session_id IS NOT NULL
                                                            AND render_instance_guid IS NOT NULL
                                                            and event_date between '2014-06-01' and '2016-06-30') c
                                             where rankNum=1) b
                              on a.session_id=b.session_id
                              and a.event_date=b.event_date
                              group by 1,2,3
                              order by 1,2,3
                              )g 
               left join dm.historical_ad_customer_professional_map hacpm
               on g.ad_id=hacpm.ad_id
               and g.event_date>=hacpm.etl_effective_begin_date
               and g.event_date<=hacpm.etl_effective_end_date
               where hacpm.professional_id!=-1
               group by 1,2
               order by 1,2
  )
