
select event_date, 
       channel, 
       content_group,  
       count(*) as pageviews

from flatten(( 
    select date(date) as event_date,   
           trafficSource.medium as channel, 
           hits.page.pagePath as url, 
           MAX(IF(hits.customDimensions.index=19,hits.customDimensions.value, NULL)) WITHIN hits as content_group

FROM TABLE_DATE_RANGE([75615261.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -3, 'DAY'), DATE_ADD(CURRENT_TIMESTAMP(), -1, 'DAY'))

where hits.type = 'PAGE'

),content_group) c


group by event_date, 
         channel,
         content_group

----

select event_date, 
       channel, 
       count(*) as pageviews

from flatten(( 
    select date(date) as event_date,   
           trafficSource.medium as channel, 
           hits.page.pagePath as url, 
           MAX(IF(hits.customDimensions.index=19,hits.customDimensions.value, NULL)) WITHIN hits as content_group

FROM TABLE_DATE_RANGE([75615261.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -100, 'DAY'), DATE_ADD(CURRENT_TIMESTAMP(), -1, 'DAY'))

where hits.type = 'PAGE'

),content_group) c


group by event_date, 
         channel
