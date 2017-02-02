
Robert Lee  [3:50 PM]  
Hi Coe, here''s an example as to how to derive an expiration_date 
from our src hist tables.  using this query you can tell when a 
particular field changed at a for a given point-in-time.  hence, 
fully_functional field changed from 0 to 1 on 9/6.

[3:50]  
select 
  id
 ,professional_id
 ,fully_functional
 ,etl_load_date as effective_date
 ,coalesce(date_add(lead(etl_load_date,1) over (partition by id, professional_id  
                                                    order by etl_load_date asc),-1), null,'9999-01-01') as expiration_date
from 
  src.hist_ocato_providers 
where 
   id = 3562 and professional_id = 4666985
order by etl_load_date;



Robert Lee  [3:53 PM]  
this expiration_date can be useful when filtering the dataset for a 
particular point-in-time.  see below for an example. 
select * from (
                select 
                    id
                   ,professional_id
                   ,enabled
                   ,etl_load_date as effective_date
                   ,coalesce(date_add(lead(etl_load_date,1) over (partition by id, professional_id  
                                                                      order by etl_load_date asc),-1), null,'9999-01-01') as expiration_date
                from 
                   src.hist_ocato_providers 
                where 
                    id = 3562 and professional_id = 4666985
               ) foo
where '2016-09-05' between effective_date and expiration_date
