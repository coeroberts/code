-- Number of attorneys with 1 and +1 review by PA

with rv as                
(                
  select pf.professional_id              
    , d.year_month as review_month            
  --  , MIN(pf.PROFNL_FRST_NAME) as first_name            
  --  , MIN(pf.PROFNL_LAST_NAME) as last_name            
  --  , MIN(case when PROFNL_CLAIM_DATETM is null then 'Not Claimed' else 'Claimed' end) as is_claim            
  --  , MIN(pf.PROFNL_CLAIM_DATETM) as claim_date            
  --  , MIN(pfrv.CREATE_DATETM) as first_review_date            
    , COUNT(pfrv.id) as review_cnt            
  --  , AVG(pfrv.PROFNL_REVIEW_OVRALL_RTG) as avg_review_rating            
  from src.barrister_professional_review pfrv              
  join DM.professional_dimension pf on pf.professional_id = pfrv.professional_id    
  join dm.date_dim d on d.actual_date = to_date(pfrv.created_at)
  where pfrv.approval_status_id in (2)              
    -- and pfrv.DEL_FLAG = 'N'            
    and pf.professional_delete_indicator = 'Not Deleted'            
    and pf.professional_name = 'lawyer'            
    and pf.industry_name = 'Legal'  
  group by 1,2              
  order by 1,2              
)                
                
, july as                
(                
  select professional_id              
    , sum(case when review_month<=201307 then review_cnt end) as rv_201307            
  from rv              
  group by 1              
)                
                
, prof as                
(                
  select j.professional_id              
    , 201307 as review_month            
    , case when rv_201307 is null then 0 else rv_201307 end as review_cnt            
  from july j              
                
  union all              
                
  select r.professional_id              
    , r.review_month            
    , r.review_cnt            
  from rv r              
  where r.review_month>=201308              
)                
                
,ym as                
(                
  select * from               
  (              
    select distinct year_month            
    from dm.date_dim dm            
    where dm.year_month>=201307            
    -- and dm.year_month<=201510            
  ) p,               
  (              
    select distinct professional_id            
    from prof            
--    where prof.professional_id in (20,49)            
  ) q              
)                
                
,review as 
(                
  select ym.year_month              
    , ym.professional_id  
    , coalesce(ps.primary_specialty,'N/A') as primary_pa
    , coalesce(prof.review_cnt,0) as review_cnt            
  from ym               
  left join prof on ym.professional_id=prof.professional_id and ym.year_month=prof.review_month
  left join 
  (
    select x.professional_id        
      , MIN(case when x.rt = 1 then x.specialty_name else NULL end) as primary_specialty       
  --    , MIN(case when x.rt = 2 then x.specialty_name else NULL end) as secondary_specialty     
    from           
    (          
      select pfsp.professional_id
        , pfsp.specialty_percent 
        , sp.specialty_name  
        , ROW_NUMBER() OVER(partition by pfsp.professional_id order by pfsp.specialty_percent desc, sp.specialty_name) rt   
      from DM.professional_specialty_bridge pfsp      
      join DM.specialty_dimension sp on sp.specialty_id = pfsp.specialty_id       
      where pfsp.delete_flag = 'N'   
    ) x        
    group by 1    
  ) ps on ps.professional_id = ym.professional_id
  order by 2,1              
)                
                
select x.year_month                
  , x.review_cnt    
  , x.primary_pa
        , to_date(dt.month_begin_date) as month_begin_date
  , count(distinct x.professional_id) as attorney_cnt              
from                
(                
  select r1.year_month              
    , r1.professional_id  
    , r1.primary_pa  
    , case when sum(r2.review_cnt)= 1 then 'one' when sum(r2.review_cnt)>1 then 'plus_one' end as review_cnt            
  from review r1, review r2              
  where r1.professional_id=r2.professional_id              
    and r1.year_month>=r2.year_month  
    and r1.primary_pa = r2.primary_pa
  group by 1,2,3            
  order by 2,1              
) x
join dm.date_dim dt on dt.year_month = x.year_month                  
where x.review_cnt is not null                
group by 1,2,3,4              
order by 1,2,3,4