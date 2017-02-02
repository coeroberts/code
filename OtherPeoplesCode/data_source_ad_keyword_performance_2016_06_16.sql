select a.event_date
,a.engine
, a.ad_market_key
  , a.ad_state
  , a.ad_region
  , a.ad_specialty
  , a.avg_quality_score
  , a.sem_impressions
  , a.sem_clicks
  , a.sem_cost
  , a.ad_click
  , a.ad_click_value
  , a.ad_contact_value
  , b.SL_SEM_ADBLOCK_ADCLICK
  , b.SL_SEM_ADBLOCK_ADCLICK_VALUE
  , b.SL_SEM_ADBLOCK_ACV
  , b.DA_SEM_ADBLOCK_ADCLICK
  , b.DA_SEM_ADBLOCK_ADCLICK_VALUE
  , b.DA_SEM_ADBLOCK_ACV
  , b.SEM_ADBLOCK_ADCLICK
  , b.SEM_ADBLOCK_ADCLICK_VALUE
  , b.SEM_ADBLOCK_ACV
from 
(
select 
  'Google' as engine,
  adkp.event_date
  , cast(regexp_extract(adkp.campaign,'[0-9]+$|[0-9]+[0-9]',0) as integer) as ad_market_key
  , MAX(adm.ad_mkt_state_name) as ad_state
  , MAX(adm.ad_mkt_regn_name) as ad_region
  , MAX(adm.ad_mkt_speclty_name) as ad_specialty
  , SUM(cast(adkp.quality_score as double) * cast(adkp.external_clicks as integer))/SUM(cast(adkp.external_clicks as integer)) as avg_quality_score
  , SUM(cast(adkp.external_impressions as integer)) as sem_impressions
  , SUM(cast(adkp.external_clicks as integer)) as sem_clicks
  , SUM(cast(adkp.external_cost as double)) as sem_cost
  , SUM(cast(adkp.internal_clicks as double)) as ad_click
  , SUM(cast(adkp.internal_clicks_value as double)) as ad_click_value
  , SUM(cast(adkp.internal_ad_contact_value as double)) as ad_contact_value
from dm.adwords_keyword_performance adkp
join dm.ad_mkt_dim adm on adm.ad_mkt_key = cast(regexp_extract(adkp.campaign,'[0-9]+$|[0-9]+[0-9]',0) as integer)
where adkp.account like '%|AdBlock%'
and adkp.event_date >= '2016-01-01' --'2015-04-01'
group by 1,2,3
  
  union all
  
select
  'Bing' as engine,
br.event_date
  , cast(regexp_extract(br.campaignname,'[0-9]+$|[0-9]+[0-9]',0) as integer) as ad_market_key
  , max(adm.ad_mkt_state_name) as ad_state
  , max(adm.ad_mkt_regn_name) as ad_region
  , max(adm.ad_mkt_speclty_name) as ad_specialty
  , sum(cast(br.qualityscore as double) * cast(br.clicks as double))/sum(cast(br.clicks as double)) as avg_quality_score
  , sum(cast(br.impressions as double)) as sem_impressions
  , sum(cast(br.clicks as double)) as sem_clicks
  , sum(cast(br.spend as double)) as sem_cost
  , sum(cast(br.ad_click as double)) as ad_click
  , sum(cast(br.ad_click_value as double)) as ad_click_value
  , sum(cast(br.ad_contact_value as double)) as ad_contact_value
from dm.bing_report br
  join dm.ad_mkt_dim adm on adm.ad_mkt_key = cast(regexp_extract(br.campaignname,'[0-9]+$|[0-9]+[0-9]',0) as integer)
where br.accountname like '%AdBlock%'
  and br.event_date >= '2016-01-01' --'2015-04-01'
 group by 1,2,3
) a
left join
(
SELECT aas.EVENT_DATE
  ,'Google' as engine
  , aas.AD_MARKET_KEY
  , SUM(aas.SL_ADCLICK) as SL_SEM_ADBLOCK_ADCLICK
  , SUM(aas.SL_ADCLICK_VALUE) as SL_SEM_ADBLOCK_ADCLICK_VALUE
  , SUM(aas.SL_ADCONTACT_VALUE) as SL_SEM_ADBLOCK_ACV
  , SUM(aas.DA_ADCLICK) as DA_SEM_ADBLOCK_ADCLICK
  , SUM(aas.DA_ADCLICK_VALUE) as DA_SEM_ADBLOCK_ADCLICK_VALUE
  , SUM(aas.DA_ADCONTACT_VALUE) as DA_SEM_ADBLOCK_ACV
  , SUM(aas.SL_ADCLICK + aas.DA_ADCLICK) as SEM_ADBLOCK_ADCLICK
  , SUM(aas.SL_ADCLICK_VALUE + aas.DA_ADCLICK_VALUE) as SEM_ADBLOCK_ADCLICK_VALUE
  , SUM(aas.SL_ADCONTACT_VALUE + aas.DA_ADCONTACT_VALUE) as SEM_ADBLOCK_ACV
FROM DM.ad_attribution_by_session_all aas
where aas.EVENT_DATE >= '2016-01-01' --'2015-04-01'
    and aas.lpv_source = 'utm_source=google'
  and aas.LPV_MEDIUM = 'utm_medium=sem' 
  and aas.LPV_CONTENT = 'utm_content=adblock'
GROUP BY 1,2,3
  
  union all
  
  SELECT aas.EVENT_DATE
  ,'Bing' as engine
  , aas.AD_MARKET_KEY
  , SUM(aas.SL_ADCLICK) as SL_SEM_ADBLOCK_ADCLICK
  , SUM(aas.SL_ADCLICK_VALUE) as SL_SEM_ADBLOCK_ADCLICK_VALUE
  , SUM(aas.SL_ADCONTACT_VALUE) as SL_SEM_ADBLOCK_ACV
  , SUM(aas.DA_ADCLICK) as DA_SEM_ADBLOCK_ADCLICK
  , SUM(aas.DA_ADCLICK_VALUE) as DA_SEM_ADBLOCK_ADCLICK_VALUE
  , SUM(aas.DA_ADCONTACT_VALUE) as DA_SEM_ADBLOCK_ACV
  , SUM(aas.SL_ADCLICK + aas.DA_ADCLICK) as SEM_ADBLOCK_ADCLICK
  , SUM(aas.SL_ADCLICK_VALUE + aas.DA_ADCLICK_VALUE) as SEM_ADBLOCK_ADCLICK_VALUE
  , SUM(aas.SL_ADCONTACT_VALUE + aas.DA_ADCONTACT_VALUE) as SEM_ADBLOCK_ACV
FROM DM.ad_attribution_by_session_all aas
where aas.EVENT_DATE >= '2016-01-01' --'2015-04-01'
    and aas.lpv_source = 'utm_source=bing'
  and aas.LPV_MEDIUM = 'utm_medium=sem' 
  and aas.LPV_CONTENT = 'utm_content=adblock'
GROUP BY 1,2,3
  
) b on b.event_date = a.event_date and a.ad_market_key = b.ad_market_key and b.engine = a.engine