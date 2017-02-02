select table_a.*
  , table_c.slug as description
  , table_c.specialty_id as specialty_id
  , case
    when table_c.package_category_id = 1 then "Advisor"
    when table_c.package_category_id = 2 then "Doc Review"
    else "Other Legal Services"
    end as package_type
  , table_c.advisor as is_advisor
  , table_e.parent_specialty_name as parent_specialty
from (
  select to_date(created_at_pst) as event_date
    , case
      when event_type = 'capture_succeeded' then "successful charge" 
      else event_type
      end as event_name
    , offer_id
    , order_id
    , event_transaction_amount_in_cents/100 as event_transaction_in_dollars
    , discount_amount_in_cents/100 as discount_transaction_in_dollars
  from src.ocato_financial_event_logs
  where created_at_pst >= "2016-04-01"
    and event_type in ('purchase', 'void', 'refund','capture_succeeded')
) as table_a
left join (
  select id
    , package_id   
  from src.ocato_offers
) as table_b
on table_a.offer_id = table_b.id
left join (
  select id
    , advisor
    , specialty_id
    , package_category_id
    , name as slug
  from src.ocato_packages
) as table_c
on table_b.package_id = table_c.id
left join dm.specialty_dimension as table_e
on table_c.specialty_id = table_e.specialty_id
