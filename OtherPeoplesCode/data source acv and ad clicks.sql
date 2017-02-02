select a.ad_market_id
  , y.ad_market_region_name as ad_region
  , y.ad_market_state_name as ad_state
  , y.ad_market_county_name as ad_county
  , y.ad_market_specialty_name as ad_specialty
  , y.specialty_id as ad_specialty_id
  , a.ad_render_type 
  , a.lpv_page_type
  , case
when lpv_source = '' and lpv_medium = '' and lpv_campaign = '' and lpv_content = '' then 'Organic/Direct'
when lpv_source = 'marchex' then 'Paid Call Channels - Marchex'
when lpv_source = 'elocal' then 'Paid Call Channels - eLocal'
when lpv_source = 'pbx' then 'Paid Call Channels - SEM Call Ext'
when lpv_medium in ('utm_medium=affiliate', 'utm_medium=affiliates', 'utm_medium=affiliawww')
                    or lpv_source in ('utm_source=boomerater', 'utm_source=boomerater%20', 'utm_source=lifecare', 'utm_source=affiliates', 'utm_source=affiliate')
                    then 'Marketing - Affiliates'
when lpv_medium in ('utm_medium=em', 'utm_medium=ema', 'utm_medium=emai', 'utm_medium=email', 'utm_medium=emailutm_content')
                    or lpv_source = 'utm_source=email'
                    then 'Marketing - Email'
when lpv_campaign like 'utm_campaign=FB_%' or lpv_campaign like 'utm_campaign=pls_avvofb%' or lpv_campaign = 'utm_campaign=pls_fb%'
                    or lpv_source in ('utm_source=facebook', 'utm_source=twitter', 'utm_source=linkedin', 'utm_source=gplus', 'utm_source=plus',
                                                             'utm_source=googleplus', 'utm_source=youtube', 'utm_source=pinterest', 'utm_source=twitterfeed',
                                                             'utm_source=Facebook', 'utm_source=Twitter', 'utm_source=topix',
                                                             'utm_source=SocialProof', 'utm_source=thetwitter', 'utm_source=faceb', 'utm_source=social')
                                           or lpv_medium in ('utm_medium=facebook', 'utm_medium=twitter')
                    then 'Marketing - Social'
when lpv_content = 'utm_content=adblock' or (lpv_campaign = 'utm_campaign=adblock' and lpv_content != 'utm_content=brand')
                    then 'SEM - Adblock'
when lpv_content = 'utm_content=sgt' or lpv_medium = 'utm_medium=sem%2F%3Futm_source%3Dgoogle%2F%3Futm_content%3Dsgt' or lpv_campaign = 'utm_campaign=sgt'
                    then 'SEM - Network'
when (lpv_medium in ('utm_medium=display','utm_medium=video','utm_medium=mobile_video', 'utm_medium=mobile', 'utm_medium=content', 'utm_medium=mobile_tablet')
                    and lpv_source != 'utm_source=google' and lpv_source != 'utm_source=gsp')
                    or lpv_source = 'utm_source=Outbrain' or lpv_source = 'utm_source=preroll'
                    then 'Marketing - Digital Brand and Engagement'
when lpv_campaign in ('utm_campaign=brand', 'utm_campaign=Branded_Terms', 'utm_campaign=legalbroad') or lpv_content = 'utm_content=brand'
                    then 'Marketing - SEM Brand'
when lpv_medium = 'utm_medium=sem' or lpv_medium = 'utm_medium=cpc' or lpv_medium = 'utm_medium=sem%3Fpromo_code%3DAVVO25'
                    then 'Marketing - SEM Nonbrand'
when lpv_campaign like 'utm_campaign=pls%' or lpv_campaign like 'utm_campaign=PLS%' 
                    then 'Marketing - Other Paid Marketing'
when lpv_medium in ('utm_medium=avvo_badge', 'utm_medium=avvo_badg', 'utm_medium=avvo_bad', 'utm_medium=avvo_ba', 'utm_medium=avvo_b')
                    then 'Other - Avvo Badge'
when lpv_source = 'utm_source=avvo' or lpv_source = 'utm_source=eboutique' then 'Other - Other'
else 'Marketing - Other Paid Marketing' end channel
  , a.partner_source
  , a.ad_page_type
  , a.event_date
  , sum(a.page_view) as page_view
  , sum(a.sl_adimpression_avail) as sl_ad_request
  , sum(a.sl_adimpression) as sl_ad_impression
  , sum(a.sl_adclick) as sl_ad_click
  , sum(a.sl_adcontact_value) as sl_acv
  , sum(a.da_adimpression_avail) as da_ad_request
  , sum(a.da_adimpression) as da_ad_impression
  , sum(a.da_adclick) as da_ad_click
  , sum(a.da_adcontact_value) as da_acv  
from dm.webanalytics_ad_attribution_v3 a
left join dm.ad_market_dimension y on y.ad_market_id = a.ad_market_id
-- where a.event_date>='2016-01-01'
where a.event_date>='2015-01-01'
group by 1,2,3,4,5,6,7,8,9,10,11,12

----

select 
    dt.year_month
  , sum(a.da_adcontact_value) as da_acv  
  , sum(a.sl_adcontact_value) as sl_acv
  , sum(a.sl_adcontact_value) +
    sum(a.da_adcontact_value) as total_acv  
from dm.webanalytics_ad_attribution_v3 a
inner join dm.date_dim dt on a.event_date = dt.actual_date
where a.event_date>='2015-01-01'
group by 1
order by 1

