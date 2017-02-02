select to_date(eds.created_at) as Endorse_Date
  , eds.endorsee_id 
  , eds.endorser_id
  , eds.ID as Endorsement_ID
  , coalesce(ps.primary_specialty,'N/A') as primary_specialty
from src.barrister_professional_endorsement eds
left join 
(
  select x.professional_id        
    , MIN(case when x.rt = 1 then x.specialty_name else NULL end) as primary_specialty        
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
) ps on ps.professional_id = eds.endorsee_id
where to_date(eds.created_at)>='2013-01-01'
