select event_date,
event_name,
event_transaction_in_dollars,
discount_transaction_in_dollars,
table_c.name,
table_c.advisor,
table_geo.state,
parent_specialty_name
from
(select to_date(created_at) as event_date,
event_type as event_name,
offer_id,
order_id,
event_transaction_amount_in_cents/100 as event_transaction_in_dollars,
discount_amount_in_cents/100 as discount_transaction_in_dollars
from src.ocato_financial_event_logs
where to_date(created_at) >= "2016-02-01"
and event_type ='purchase') as table_a
left join
(select order_id, source, state_id, location_id from src.ocato_advice_sessions
where to_date(created_at) >= "2016-02-01") as table_b
on table_b.order_id = table_a.order_id
left join
(select id,
package_id 
from src.ocato_offers) as table_q
on table_a.offer_id = table_q.id
left join (select id,
advisor,
name,
specialty_id,
package_category_id
from src.ocato_packages ) as table_c
on table_q.package_id = table_c.id
left join
(select id, name as state from src.ocato_states ) as table_geo
on table_b.state_id = table_geo.id
left join
(select * from dm.specialty_dimension) as table_specialty
on table_specialty.specialty_id = table_c.specialty_id
