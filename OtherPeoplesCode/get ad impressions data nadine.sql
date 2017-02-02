select daw.calculation_DATE
               ,admkt.AD_MKT_KEY
               ,daw.AD_ID
               ,pro.professional_id as lawyerid
               ,pro.name
               ,admkt.AD_MKT_STATE_NAME
               ,admkt.AD_MKT_CNTY_NAME
               ,admkt.AD_MKT_REGN_NAME
               ,admkt.AD_MKT_SPECLTY_NAME
               ,MIN(TARGET_BLOCK_CouNT) as TARGET_BLOCK_CNT
               ,MIN(TARGET_IMPRession_CouNT) as TARGET_IMPRSN_CNT
               ,MIN(TARGET_PURCHase_PRICE) as TARGET_PURCH_PRICE_AMT
               ,MIN(DELivered_IMPRession_CouNT) as DELVR_IMPRSN_CNT
               ,MIN(DELivered_ATTRIBution_VALUE) as DELVR_ATTRIB_VALUE
               ,MIN(IQ) as IQ
               ,MIN(VQ) as VQ 
               ,MAX(daw.MAX_BLOCK_CouNT) as BlockAvailable
               ,MAX(daw.TOTaL_SOLD_BLOCK_CouNT)  BlockSold
from dm.webanalytics_ad_weight daw
join DM.ad_mkt_dim admkt on admkt.ad_mkt_key = daw.AD_market_KEY
left join 
(
               select admap.ad_id
                              , pf.professional_id
                              , concat(pf.professional_first_name,' ',pf.professional_last_name) as name
               from
               (
                              select adcustmap.ad_id, min(adcustmap.professional_id) as professional_id, count(distinct adcustmap.professional_id) as pcount
                              from dm.historical_ad_customer_professional_map adcustmap
                              where adcustmap.etl_effective_end_date >= <Parameters.current_date>
                              group by adcustmap.ad_id
                              order by pcount desc
               ) admap
               left join DM.professional_dimension pf on pf.professional_id = admap.professional_id
) pro on pro.ad_id = daw.AD_ID
where daw.calculation_DATE >= '2015-01-01'
               and admkt.AD_MKT_BLOCK_FLAG = 'Y'
group by 1,2,3,4,5,6,7,8,9
