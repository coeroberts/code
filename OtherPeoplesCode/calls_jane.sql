select distinct  cdr.call_id
    , cdr.call_date
    , cdr.call_datetm
    , cast((cast(cdr.CALL_DATETM as int)) as timestamp) as date_time
    , cdr.caller_phon_nbr
    , cdr.profnl_phon_nbr
    , cdr.profnl_id
    , m.cust_id
    , cdr.call_duratn_second_cnt as call_length_seconds        
    , concat(pd.professional_first_name, ' ', pd.professional_last_name) as name
    , pd.professional_city_name_1 as city
    , pd.professional_state_name_1 as state
    , pd.professional_phone_number_1 as phone_nbr
    , pd.professional_email_address_name as email
    , pd.professional_website_url as website
from  dm.call_detail_rec_fact cdr 
join dm.professional_dimension pd on pd.professional_id = cdr.profnl_id
join dm.date_dim d on d.actual_date = cdr.call_date
join 
    (
       select distinct d.year_month     
       from DM.DATE_DIM d
       where d.actual_date >= to_date(now()- interval 12 month)
        and d.actual_date <= now()
    ) dt on dt.year_month = d.year_month
join dm.etldm_ad_cust_profnl_map m on m.profnl_id = cdr.profnl_id