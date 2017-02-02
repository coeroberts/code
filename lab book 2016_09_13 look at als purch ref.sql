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
  , purch.purch_date
  , purch.purchase_transaction_in_dollars
from (
  select to_date(created_at) as event_date
    , case
      when event_type = 'capture_succeeded' then "successful charge" 
      else event_type
      end as event_name
    , offer_id
    , order_id
    , event_transaction_amount_in_cents/100 as event_transaction_in_dollars
    , discount_amount_in_cents/100 as discount_transaction_in_dollars
  from src.ocato_financial_event_logs
  where created_at  >= "2016-04-01"
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
left join (
  select to_date(created_at) as purch_date
    , offer_id
    , order_id
    , event_transaction_amount_in_cents/100 as purchase_transaction_in_dollars
    , discount_amount_in_cents/100 as discount_transaction_in_dollars
  from src.ocato_financial_event_logs
  where created_at  >= "2016-04-01"
    and event_type in ('purchase')
) as purch
on table_a.order_id = purch.order_id


-- SELECT order_number, count(*)
-- FROM (
-- SELECT order_line_purchase_date, order_number, count(*)
-- FROM dm.order_line_accumulation_fact
-- WHERE order_line_purchase_date <> '1900-01-01'
-- group by 1,2
-- ) qry
-- group by 1
-- having COUNT(*) > 1

-- SELECT order_number, count(*)
-- FROM (
-- SELECT order_line_purchase_date, order_number, count(*)
--   select *
-- FROM dm.order_line_accumulation_fact
--   where order_number = 106702
-- group by 1,2
-- ) qry
-- group by 1
-- having COUNT(*) > 1

-- SELECT order_id, count(*)
-- FROM (
--   select to_date(created_at) as event_date
--     , case
--       when event_type = 'capture_succeeded' then "successful charge" 
--       else event_type
--       end as event_name
--     , offer_id
--     , order_id
--     , event_transaction_amount_in_cents/100 as event_transaction_in_dollars
--     , discount_amount_in_cents/100 as discount_transaction_in_dollars
--   from src.ocato_financial_event_logs
--   where created_at  >= "2016-04-01"
--     and event_type in ('purchase')
-- ) as purch
-- group by 1
-- having count(*) > 1
-- Confirmed only 1 record per purchase.

DROP TABLE tmp_data_dm.coe_check_dates;
CREATE TABLE tmp_data_dm.coe_check_dates AS
SELECT
   event_date
  ,purch_date
  ,CASE WHEN event_name = 'refund' THEN purch_date ELSE event_date END AS adj_date
  ,event_name
  ,SUM(event_transaction_in_dollars) AS     event_transaction_in_dollars
  ,SUM(discount_transaction_in_dollars) AS  discount_transaction_in_dollars
  ,COUNT(*) AS num_rows
FROM (
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
  , purch.purch_date
  , purch.purchase_transaction_in_dollars
from (
  select to_date(created_at) as event_date
    , case
      when event_type = 'capture_succeeded' then "successful charge" 
      else event_type
      end as event_name
    , offer_id
    , order_id
    , event_transaction_amount_in_cents/100 as event_transaction_in_dollars
    , discount_amount_in_cents/100 as discount_transaction_in_dollars
  from src.ocato_financial_event_logs
  where created_at  >= "2016-04-01"
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
left join (
  select to_date(created_at) as purch_date
    , offer_id
    , order_id
    , event_transaction_amount_in_cents/100 as purchase_transaction_in_dollars
    , discount_amount_in_cents/100 as discount_transaction_in_dollars
  from src.ocato_financial_event_logs
  where created_at  >= "2016-04-01"
    and event_type in ('purchase')
) as purch
on table_a.order_id = purch.order_id
) qry
GROUP BY 1,2,3,4

OK wrap back to purpose.  Are we losing important information or
creating spurious information as a result of naiive date handling?


