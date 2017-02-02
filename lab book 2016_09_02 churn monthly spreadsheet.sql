# This used to be "lab book 2016_05_02 mrr and churn.sql"

#Customer-monthly
    #cust-monthly
CustomerMRR-monthly
    MRR-monthly
#Customer-LT - add one more month in the following tables
    #Retained-LT0
        t4
        the final query
    #Retained-LT
        the final query
    #Churned-LT
        retained
        the final query
    %Churned-LT
        retained
        churned
        the final query
CustomerMRR-LT - add one more month in the following tables
    RetainedMRR-LT0
        t4
        the final query
    RetainedMRR-LT
        the final query
    ChurnedMRR-LT
        retained
        the final query
    %ChurnedMRR-LT
        retained
        churned
        the final query


----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
-- #Customer-monthly
--     #cust-monthly
with t1 as
(
  select x.cust_id
    --, a.PRODUCT_LN_KEY 
    , x.year_month as active_month                
    , case when x.year_month between 201301 and 201312                 
     then (x.year_month-201300)                
     when x.year_month between 201401 and 201412                 
     then (x.year_month-201400+12)                 
     when x.year_month between 201501 and 201512                 
     then (x.year_month-201500+24)
     when x.year_month between 201601 and 201612                 
     then (x.year_month-201600+36)
    end as month_number                
  , sum(x.final_price) as revenue        
  from
  (
    select xx.customer_id as cust_id  
      --, a.ORDER_NBR
      --, a.INVC_ID
      -- , a.PRODUCT_LN_KEY 
      --, d.actual_date as purchase_date 
      , xx.year_month              
      , xx.order_line_payment_date as payment_date              
      , xx.order_line_begin_date as begin_use_date  
      --, d2.actual_date as cancel_date
      --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP
      --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price
      , case when xx.order_line_payment_date='-1' then 0  else sum(xx.order_line_net_price_amount_usd) end as final_price
    from 
    (                
      select *               
        , cast(yearmonth as int) as year_month            
      from dm.order_line_accumulation_fact               
    ) xx    
    where 
    --c.cust_id in (100)
    xx. product_line_id in (2,7)                
    and xx.order_line_begin_date>='2013-01-01'
    group by 1,2,3,4
   ) x
  group by 1,2,3
),

t2 as
(
  select a.cust_id
    , min(a.month_number) as Start_Month
    , max(a.month_number) as End_Month
  from
  (
    select t1.*
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap
    from t1
  ) a
  group by a.gap, a.cust_id
  -- order by min(a.month_number)
),

t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
),  

t4 as
(
  select t3.cust_id
    , min(t3.start_month) as min_start_month
    , max(t3.end_month) as max_end_month
  from t3
  group by 1
)

select z.year_month
  , z.customers_from_previous_month as starting_customer_cnt
  --, z.retained_customers_from_previous_month as retained_customer_cnt
  , z.customers_from_previous_month-z.retained_customers_from_previous_month as churned_customer_cnt
  , z.reactivated_customers as reactivated_customer_cnt
  , z.new_customers as new_customer_cnt
  --, z.new_customers+z.reactivated_customers-churned_customers_from_previous_month as net_new_customers
  , z.retained_customers_from_previous_month+z.new_customers+z.reactivated_customers as ending_customer_cnt
  , z.retained_customers_from_previous_month+z.new_customers+z.reactivated_customers-z.customers_from_previous_month as Customer_Growth
  , cast(z.customers_from_previous_month-z.retained_customers_from_previous_month as float)/cast (z.customers_from_previous_month as float) as Customer_Churn_Percent
  , cast(z.retained_customers_from_previous_month+z.new_customers+z.reactivated_customers as float)/cast(z.customers_from_previous_month as float)-1 as Customer_Growth_Percent  
from
(
  select x1.active_month as Year_Month
    , y.customer_cnt as customers_from_previous_month
    , x3.retained_customers_from_previous_month
    , x1.new_customers
    , x2.reactivated_customerscustomer_churn_pct
  from
  (
    select t3.active_month
      , t3.month_number
      , count(distinct case when t4.min_start_month=t3.month_number then t3.cust_id end) as new_customers
    from t3
    join t4 on t4.cust_id = t3.cust_id
    group by t3.active_month, t3.month_number
  ) x1
  join 
  (
    select t3.active_month
      , t3.month_number
      , count(distinct case when t3.start_month=t3.month_number and t4.min_start_month!=t3.month_number then t3.cust_id end) as reactivated_customers
    from t3
    join t4 on t4.cust_id = t3.cust_id
    group by t3.active_month, t3.month_number
  ) x2 on x2.active_month=x1.active_month
  join
  (
    select t3.active_month
      , t3.month_number
      , count(distinct case when t3.start_month<t3.month_number then t3.cust_id end) as retained_customers_from_previous_month
    from t3
    join t4 on t4.cust_id = t3.cust_id
    group by t3.active_month, t3.month_number
  ) x3 on x3.active_month=x1.active_month
  join 
  (
    select t3.month_number
      , count(distinct t3.cust_id) as customer_cnt
    from t3
    group by 1
  ) y on y.month_number=x1.month_number-1
) z
where z.year_month>=201304
order by 1


----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
-- CustomerMRR-monthly
--     MRR-monthly
with base as                    
(                    
  select x.cust_id                  
  --, a.PRODUCT_LN_KEY                   
    , x.year_month as active_month                
    , case when x.year_month between 201301 and 201312                 
     then (x.year_month-201300)                
     when x.year_month between 201401 and 201412                 
     then (x.year_month-201400+12)                 
     when x.year_month between 201501 and 201512                 
     then (x.year_month-201500+24)
     when x.year_month between 201601 and 201612                 
     then (x.year_month-201600+36)
    end as month_number                
  , sum(x.final_price) as final_price                  
  from                  
  (                  
    select xx.customer_id as cust_id                
      --, a.ORDER_NBR              
      --, a.INVC_ID              
      --, a.PRODUCT_LN_KEY               
      --, d.actual_date as purchase_date               
      , xx.year_month              
      , xx.order_line_payment_date as payment_date              
      , xx.order_line_begin_date as begin_use_date              
      --, d2.actual_date as cancel_date              
      --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP              
      --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price              
      , case when xx.order_line_payment_date='-1' then 0               
        else (            
            case when day(xx.order_line_begin_date)=1 then sum(xx.order_line_net_price_amount_usd)        
            else (        
                case when month(xx.order_line_begin_date) in (1,3,5,7,8,10,12)     
                  then   
                  (  
                    case when day(xx.order_line_begin_date)=31 then sum(xx.order_line_net_price_amount_usd)*31
                     else sum(xx.order_line_net_price_amount_usd)*31/(31-day(xx.order_line_begin_date)) end
                  )  
                  when  month(xx.order_line_begin_date)=2  
                  then   
                  (  
                    case when day(xx.order_line_begin_date)=28 then sum(xx.order_line_net_price_amount_usd)*28
                     else sum(xx.order_line_net_price_amount_usd)*28/(28-day(xx.order_line_begin_date)) end
                  )  
                  else   
                  (  
                    case when day(xx.order_line_begin_date)=30 then sum(xx.order_line_net_price_amount_usd)*30
                     else sum(xx.order_line_net_price_amount_usd)*30/(30-day(xx.order_line_begin_date)) end
                  )  
                  end  
              ) end      
          )           
      end as final_price              
    from                 
    (                
      select *               
        , cast(yearmonth as int) as year_month            
      from dm.order_line_accumulation_fact               
    ) xx                
    where                 
    --c.cust_id in (100)                
    xx.product_line_id in (2,7)                
    and xx.order_line_begin_date>='2013-03-01'                 
    --and p.cust_id!='-1'                              
    group by 1,2,3,4                
  ) x                  
  group by 1,2,3                  
),                    
                    
                    
t1 as                    
(                    
  select y.cust_id                  
    , y.active_month                
    , y.month_number                
    , case when y.active_month<=201407                 
      then (              
          case when y.price_lastmonth=0 then           
          (          
            case when y.price_nextmonth=0 then y.final_price         
            else y.price_nextmonth end         
          )          
           else y.final_price end          
        )            
      else y.final_price end as revenue  ---prorated adjusted to full month price:MRR              
  from                  
  (                  
    select b1.*                
      , coalesce(b2.final_price,0) as price_lastmonth              
      , coalesce(b3.final_price,0) as price_nextmonth              
    from base b1                
    left join                
    base b2 on b1.month_number=b2.month_number+1 and b1.cust_id=b2.cust_id                
    left join base b3 on b1.month_number=b3.month_number-1 and b1.cust_id=b3.cust_id                
  ) y                   
),                    
                    
t2 as                    
(                    
  select a.cust_id                  
    , min(a.month_number) as Start_Month                
    , max(a.month_number) as End_Month                
  from                  
  (                  
    select t1.*                
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap              
    from t1                
  ) a                  
  group by a.gap, a.cust_id                  
  -- order by min(a.month_number)                  
),                    
                    
t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
),                    
                    
t4 as                    
(                    
  select t3.cust_id                  
    , min(t3.start_month) as min_start_month                
    , max(t3.end_month) as max_end_month                
  from t3                  
  group by 1                  
)                    
                    
select year_month                    
  , MRR_from_previous_month as starting_MRR                  
  -- , retained_MRR_from_previous_month as retained_advertiser_MRR                  
  , upsell+MRR_from_previous_month-retained_MRR_from_previous_month as churned_MRR                  
  , upsell                  
  , MRR_from_reactivated_customers as reactivated_MRR                  
  , new_MRR as new_MRR                  
  -- , starting_advertiser_MRR-retained_advertiser_MRR as churned_advertiser_MRR                  
  -- , new_advertiser_MRR+reactivated_advertiser_MRR-churned_advertiser_MRR as net_new_advertiser_MRR                  
  , retained_MRR_from_previous_month+new_MRR+MRR_from_reactivated_customers as ending_MRR                  
  , (retained_MRR_from_previous_month+new_MRR+MRR_from_reactivated_customers)-MRR_from_previous_month as MRR_Growth                  
    , cast(upsell+MRR_from_previous_month-retained_MRR_from_previous_month as float)/cast (MRR_from_previous_month as float) as MRR_Churn_Percent
  , cast(retained_MRR_from_previous_month+new_MRR+MRR_from_reactivated_customers as float)/cast(MRR_from_previous_month as float)-1 as MRR_Growth_Percent                  
from                    
(                    
  select x.active_month as year_month                  
    , y.MRR as MRR_from_previous_month                
    , x.retained_MRR_from_previous_month                 
    , xy.upsell                
    , x.new_MRR                
    , case when x.MRR_from_reactivated_customers is null then 0 else x.MRR_from_reactivated_customers end as MRR_from_reactivated_customers                
  from                  
  (                  
    select t3.active_month                
      , t3.month_number              
      , sum(case when t3.month_number=t4.min_start_month then t3.revenue end) as new_MRR              
      , sum(case when t3.start_month=t3.month_number and t4.min_start_month!=t3.month_number then t3.revenue end) as MRR_from_reactivated_customers              
      , sum(case when t3.start_month<t3.month_number then t3.revenue end) as retained_MRR_from_previous_month              
    from t3                 
    join t4 on t4.cust_id=t3.cust_id                
    group by t3.active_month, t3.month_number                
  ) x                  
  join                   
  (                  
    select t3.month_number                
      , sum(t3.revenue) as MRR              
    from t3                
    group by 1                
  ) y on y.month_number=x.month_number-1                  
  join                   
  (                  
    select a1.month_number                
      , sum(a1.revenue) - sum(a2.revenue) as upsell              
    from t3 a1, t3 a2                
    where a1.month_number-1=a2.month_number                
      and a1.cust_id=a2.cust_id              
    group by 1                
  ) xy on xy.month_number=x.month_number                  
) z    
where z.year_month>=201304                
order by 1


----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
-- #Customer-LT
--     #Retained-LT0
with t1 as
(
  select x.cust_id
    --, a.PRODUCT_LN_KEY 
    , x.year_month as active_month                
    , case when x.year_month between 201301 and 201312                 
     then (x.year_month-201300)                
     when x.year_month between 201401 and 201412                 
     then (x.year_month-201400+12)                 
     when x.year_month between 201501 and 201512                 
     then (x.year_month-201500+24)
     when x.year_month between 201601 and 201612                 
     then (x.year_month-201600+36)
    end as month_number                
  , sum(x.final_price) as revenue        
  from
  (
    select xx.customer_id as cust_id  
      --, a.ORDER_NBR
      --, a.INVC_ID
      -- , a.PRODUCT_LN_KEY 
      --, d.actual_date as purchase_date 
      , xx.year_month              -- Note: all of these used to have a space.
      , xx.order_line_payment_date as payment_date              
      , xx.order_line_begin_date as begin_use_date  
      --, d2.actual_date as cancel_date
      --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP
      --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price
      , case when xx.order_line_payment_date='-1' then 0  else sum(xx.order_line_net_price_amount_usd) end as final_price
    from 
    (                
      select *               
        , cast(yearmonth as int) as year_month            
      from dm.order_line_accumulation_fact               
    ) xx    
    where 
    --c.cust_id in (100)
    xx. product_line_id in (2,7)                
    and xx.order_line_begin_date>='2013-01-01'
    group by 1,2,3,4
  ) x
  group by 1,2,3
),

t2 as
(
  select a.cust_id
    , min(a.month_number) as Start_Month
    , max(a.month_number) as End_Month
  from
  (
    select t1.*
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap
    from t1
  ) a
  group by a.gap, a.cust_id
  -- order by min(a.month_number)
),

t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
),  

ms as
(
  select t3.cust_id
    , min(t3.start_month) as min_start_month
  from t3
  group by 1
),

t4 as
(
  select t3.cust_id
    , t3.startmonth as start_month
    --, case when t3.active_month='201301' then 1 else 0 end as Jan_2013
    --, case when t3.active_month='201302' then 1 else 0 end as Feb_2013
    --, case when t3.active_month='201303' then 1 else 0 end as Mar_2013
    , case when t3.active_month=201304 then 1 else 0 end as Apr_2013
    , case when t3.active_month=201305 then 1 else 0 end as May_2013
    , case when t3.active_month=201306 then 1 else 0 end as Jun_2013
    , case when t3.active_month=201307 then 1 else 0 end as Jul_2013
    , case when t3.active_month=201308 then 1 else 0 end as Aug_2013
    , case when t3.active_month=201309 then 1 else 0 end as Sep_2013
    , case when t3.active_month=201310 then 1 else 0 end as Oct_2013
    , case when t3.active_month=201311 then 1 else 0 end as Nov_2013
    , case when t3.active_month=201312 then 1 else 0 end as Dec_2013
    , case when t3.active_month=201401 then 1 else 0 end as Jan_2014
    , case when t3.active_month=201402 then 1 else 0 end as Feb_2014
    , case when t3.active_month=201403 then 1 else 0 end as Mar_2014
    , case when t3.active_month=201404 then 1 else 0 end as Apr_2014
    , case when t3.active_month=201405 then 1 else 0 end as May_2014
    , case when t3.active_month=201406 then 1 else 0 end as Jun_2014
    , case when t3.active_month=201407 then 1 else 0 end as Jul_2014
    , case when t3.active_month=201408 then 1 else 0 end as Aug_2014
    , case when t3.active_month=201409 then 1 else 0 end as Sep_2014
    , case when t3.active_month=201410 then 1 else 0 end as Oct_2014
    , case when t3.active_month=201411 then 1 else 0 end as Nov_2014
    , case when t3.active_month=201412 then 1 else 0 end as Dec_2014
    , case when t3.active_month=201501 then 1 else 0 end as Jan_2015
    , case when t3.active_month=201502 then 1 else 0 end as Feb_2015
    , case when t3.active_month=201503 then 1 else 0 end as Mar_2015
    , case when t3.active_month=201504 then 1 else 0 end as Apr_2015
    , case when t3.active_month=201505 then 1 else 0 end as May_2015
    , case when t3.active_month=201506 then 1 else 0 end as Jun_2015
    , case when t3.active_month=201507 then 1 else 0 end as Jul_2015
    , case when t3.active_month=201508 then 1 else 0 end as Aug_2015
    , case when t3.active_month=201509 then 1 else 0 end as Sep_2015
    , case when t3.active_month=201510 then 1 else 0 end as Oct_2015
    , case when t3.active_month=201511 then 1 else 0 end as Nov_2015
    , case when t3.active_month=201512 then 1 else 0 end as Dec_2015
    , case when t3.active_month=201601 then 1 else 0 end as Jan_2016  -- Added by Coe
    , case when t3.active_month=201602 then 1 else 0 end as Feb_2016  -- Added by Coe
    , case when t3.active_month=201603 then 1 else 0 end as Mar_2016  -- Added by Coe
    , case when t3.active_month=201604 then 1 else 0 end as Apr_2016  -- Added by Coe
    , case when t3.active_month=201605 then 1 else 0 end as May_2016  -- Added by Coe
    , case when t3.active_month=201606 then 1 else 0 end as Jun_2016  -- Added by Coe
    , case when t3.active_month=201607 then 1 else 0 end as Jul_2016  -- Added by Coe
    , case when t3.active_month=201608 then 1 else 0 end as Aug_2016  -- Added by Coe
    , case when t3.active_month=201609 then 1 else 0 end as Sep_2016  -- Added by Coe
  from t3, ms
  where t3.cust_id = ms.cust_id and t3.start_month = ms.min_start_month
)

select t4.start_month
  --, sum(t4.Jan_2013) as Jan_2013
  --, sum(t4.Feb_2013) as Feb_2013
  --, sum(t4.Mar_2013) as Mar_2013
  , sum(t4.Apr_2013) as Apr_2013
  , sum(t4.May_2013) as May_2013
  , sum(t4.Jun_2013) as Jun_2013
  , sum(t4.Jul_2013) as Jul_2013
  , sum(t4.Aug_2013) as Aug_2013
  , sum(t4.Sep_2013) as Sep_2013
  , sum(t4.Oct_2013) as Oct_2013
  , sum(t4.Nov_2013) as Nov_2013
  , sum(t4.Dec_2013) as Dec_2013
  , sum(t4.Jan_2014) as Jan_2014
  , sum(t4.Feb_2014) as Feb_2014
  , sum(t4.Mar_2014) as Mar_2014
  , sum(t4.Apr_2014) as Apr_2014
  , sum(t4.May_2014) as May_2014
  , sum(t4.Jun_2014) as Jun_2014
  , sum(t4.Jul_2014) as Jul_2014
  , sum(t4.Aug_2014) as Aug_2014
  , sum(t4.Sep_2014) as Sep_2014
  , sum(t4.Oct_2014) as Oct_2014
  , sum(t4.Nov_2014) as Nov_2014
  , sum(t4.Dec_2014) as Dec_2014
  , sum(t4.Jan_2015) as Jan_2015
  , sum(t4.Feb_2015) as Feb_2015
  , sum(t4.Mar_2015) as Mar_2015
  , sum(t4.Apr_2015) as Apr_2015
  , sum(t4.May_2015) as May_2015
  , sum(t4.Jun_2015) as Jun_2015
  , sum(t4.Jul_2015) as Jul_2015
  , sum(t4.Aug_2015) as Aug_2015
  , sum(t4.Sep_2015) as Sep_2015
  , sum(t4.Oct_2015) as Oct_2015
  , sum(t4.Nov_2015) as Nov_2015
  , sum(t4.Dec_2015) as Dec_2015
  , sum(t4.Jan_2016) as Jan_2016  -- Added by Coe
  , sum(t4.Feb_2016) as Feb_2016  -- Added by Coe
  , sum(t4.Mar_2016) as Mar_2016  -- Added by Coe
  , sum(t4.Apr_2016) as Apr_2016  -- Added by Coe
  , sum(t4.May_2016) as May_2016  -- Added by Coe
  , sum(t4.Jun_2016) as Jun_2016  -- Added by Coe
  , sum(t4.Jul_2016) as Jul_2016  -- Added by Coe
  , sum(t4.Aug_2016) as Aug_2016  -- Added by Coe
  , sum(t4.Sep_2016) as Sep_2016  -- Added by Coe
from t4
where t4.start_month>201303
group by 1
order by t4.start_month
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
    -- #Retained-LT
with t1 as
(
  select x.cust_id
    --, a.PRODUCT_LN_KEY 
    , x.year_month as active_month                
    , case when x.year_month between 201301 and 201312                 
     then (x.year_month-201300)                
     when x.year_month between 201401 and 201412                 
     then (x.year_month-201400+12)                 
     when x.year_month between 201501 and 201512                 
     then (x.year_month-201500+24)
     when x.year_month between 201601 and 201612                 
     then (x.year_month-201600+36)
    end as month_number                
  , sum(x.final_price) as revenue        
  from
  (
    select xx.customer_id as cust_id  
      --, a.ORDER_NBR
      --, a.INVC_ID
      -- , a.PRODUCT_LN_KEY 
      --, d.actual_date as purchase_date 
      , xx. year_month              
      , xx.order_line_payment_date as payment_date              
      , xx.order_line_begin_date as begin_use_date  
      --, d2.actual_date as cancel_date
      --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP
      --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price
      , case when xx.order_line_payment_date='-1' then 0  else sum(xx.order_line_net_price_amount_usd) end as final_price
    from 
    (                
      select *               
        , cast(yearmonth as int) as year_month            
      from dm.order_line_accumulation_fact               
    ) xx    
    where 
    --c.cust_id in (100)
    xx. product_line_id in (2,7)                
    and xx.order_line_begin_date>='2013-01-01'
    group by 1,2,3,4
  ) x
  group by 1,2,3
),

t2 as
(
  select a.cust_id
    , min(a.month_number) as Start_Month
    , max(a.month_number) as End_Month
  from
  (
    select t1.*
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap
    from t1
  ) a
  group by a.gap, a.cust_id
  -- order by min(a.month_number)
),

t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
),  

ms as
(
  select t3.cust_id
    , min(t3.start_month) as min_start_month
  from t3
  group by 1
),

rn as
(
  select x.*
    , row_number() over (partition by x.cust_id order by x.active_month) as rn
  from 
  (
    select t3.cust_id
      , t3.startmonth as start_month
      , t3.active_month
      , t3.revenue
    from t3, ms
    where t3.cust_id = ms.cust_id and t3.start_month = ms.min_start_month
  ) x
)

select start_month
  , count(case when rn=1 then cust_id end) as m0
  , count(case when rn=2 then  cust_id end) as m1
  , count(case when rn=3 then  cust_id end) as m2
  , count(case when rn=4 then  cust_id end) as m3
  , count(case when rn=5 then  cust_id end) as m4
  , count(case when rn=6 then  cust_id end) as m5
  , count(case when rn=7 then  cust_id end) as m6
  , count(case when rn=8 then  cust_id end) as m7
  , count(case when rn=9 then  cust_id end) as m8
  , count(case when rn=10 then  cust_id end) as m9
  , count(case when rn=11 then  cust_id end) as m10
  , count(case when rn=12 then  cust_id end) as m11
  , count(case when rn=13 then  cust_id end) as m12
  , count(case when rn=14 then  cust_id end) as m13
  , count(case when rn=15 then  cust_id end) as m14
  , count(case when rn=16 then  cust_id end) as m15
  , count(case when rn=17 then  cust_id end) as m16
  , count(case when rn=18 then  cust_id end) as m17
  , count(case when rn=19 then  cust_id end) as m18
  , count(case when rn=20 then  cust_id end) as m19
  , count(case when rn=21 then  cust_id end) as m20
  , count(case when rn=22 then  cust_id end) as m21
  , count(case when rn=23 then  cust_id end) as m22
  , count(case when rn=24 then  cust_id end) as m23
  , count(case when rn=25 then  cust_id end) as m24
  , count(case when rn=26 then  cust_id end) as m25
  , count(case when rn=27 then  cust_id end) as m26
  , count(case when rn=28 then  cust_id end) as m27
  , count(case when rn=29 then  cust_id end) as m28
  , count(case when rn=30 then  cust_id end) as m29
  , count(case when rn=31 then  cust_id end) as m30
  , count(case when rn=32 then  cust_id end) as m31
  , count(case when rn=33 then  cust_id end) as m32
  , count(case when rn=34 then  cust_id end) as m33  -- Added by Coe
  , count(case when rn=35 then  cust_id end) as m34  -- Added by Coe
  , count(case when rn=36 then  cust_id end) as m35  -- Added by Coe
  , count(case when rn=37 then  cust_id end) as m36  -- Added by Coe
  , count(case when rn=38 then  cust_id end) as m37  -- Added by Coe
  , count(case when rn=39 then  cust_id end) as m38  -- Added by Coe
  , count(case when rn=40 then  cust_id end) as m39  -- Added by Coe
  , count(case when rn=41 then  cust_id end) as m40  -- Added by Coe
  , count(case when rn=42 then  cust_id end) as m41  -- Added by Coe
from rn
where start_month>=201304 and start_month<=201608 and active_month<=201609  -- Changed by Coe
group by 1
order by start_month

----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
    -- #Churned-LT
with t1 as
(
  select x.cust_id
    --, a.PRODUCT_LN_KEY 
    , x.year_month as active_month                
    , case when x.year_month between 201301 and 201312                 
     then (x.year_month-201300)                
     when x.year_month between 201401 and 201412                 
     then (x.year_month-201400+12)                 
     when x.year_month between 201501 and 201512                 
     then (x.year_month-201500+24)
     when x.year_month between 201601 and 201612                 
     then (x.year_month-201600+36)
    end as month_number                
  , sum(x.final_price) as revenue        
  from
  (
    select xx.customer_id as cust_id  
      --, a.ORDER_NBR
      --, a.INVC_ID
      -- , a.PRODUCT_LN_KEY 
      --, d.actual_date as purchase_date 
      , xx. year_month              
      , xx.order_line_payment_date as payment_date              
      , xx.order_line_begin_date as begin_use_date  
      --, d2.actual_date as cancel_date
      --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP
      --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price
      , case when xx.order_line_payment_date='-1' then 0  else sum(xx.order_line_net_price_amount_usd) end as final_price
    from 
    (                
      select *               
        , cast(yearmonth as int) as year_month            
      from dm.order_line_accumulation_fact               
    ) xx    
    where 
    --c.cust_id in (100)
    xx. product_line_id in (2,7)                
    and xx.order_line_begin_date>='2013-01-01'
    group by 1,2,3,4
  ) x
  group by 1,2,3
),

t2 as
(
  select a.cust_id
    , min(a.month_number) as Start_Month
    , max(a.month_number) as End_Month
  from
  (
    select t1.*
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap
    from t1
  ) a
  group by a.gap, a.cust_id
  -- order by min(a.month_number)
),

t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
),  

ms as
(
  select t3.cust_id
    , min(t3.start_month) as min_start_month
  from t3
  group by 1
),

rn as
(
  select x.*
    , row_number() over (partition by x.cust_id order by x.active_month) as rn
  from 
  (
    select t3.cust_id
      , t3.startmonth as start_month
      , t3.active_month
      , t3.revenue
    from t3, ms
    where t3.cust_id = ms.cust_id and t3.start_month = ms.min_start_month
  ) x
)

, retained as
(
  select start_month
    , case when count(case when rn=1 then cust_id end)=0 then null else count(case when rn=1 then cust_id end) end as m0
    , case when count(case when rn=2 then  cust_id end)=0 then null else count(case when rn=2 then  cust_id end) end as m1
    , case when count(case when rn=3 then  cust_id end)=0 then null else count(case when rn=3 then  cust_id end) end as m2
    , case when count(case when rn=4 then  cust_id end)= 0 then null else count(case when rn=4 then  cust_id end) end as m3
    , case when count(case when rn=5 then cust_id end)=0 then null else count(case when rn=5 then cust_id end) end as m4
    , case when count(case when rn=6 then cust_id end)=0 then null else count(case when rn=6 then cust_id end) end as m5
    , case when count(case when rn=7 then cust_id end)=0 then null else count(case when rn=7 then cust_id end) end as m6
    , case when count(case when rn=8 then cust_id end)=0 then null else count(case when rn=8 then cust_id end) end as m7
    , case when count(case when rn=9 then cust_id end)=0 then null else count(case when rn=9 then cust_id end) end as m8
    , case when count(case when rn=10 then cust_id end)=0 then null else count(case when rn=10 then cust_id end) end as m9
    , case when count(case when rn=11 then cust_id end)=0 then null else count(case when rn=11 then cust_id end) end as m10
    , case when count(case when rn=12 then cust_id end)=0 then null else count(case when rn=12 then cust_id end) end as m11
    , case when count(case when rn=13 then cust_id end)=0 then null else count(case when rn=13 then cust_id end) end as m12
    , case when count(case when rn=14 then cust_id end)=0 then null else count(case when rn=14 then cust_id end) end as m13
    , case when count(case when rn=15 then cust_id end)=0 then null else count(case when rn=15 then cust_id end) end as m14
    , case when count(case when rn=16 then cust_id end)=0 then null else count(case when rn=16 then cust_id end) end as m15
    , case when count(case when rn=17 then cust_id end)=0 then null else count(case when rn=17 then cust_id end) end as m16
    , case when count(case when rn=18 then cust_id end)=0 then null else count(case when rn=18 then cust_id end) end as m17
    , case when count(case when rn=19 then cust_id end)=0 then null else count(case when rn=19 then cust_id end) end as m18
    , case when count(case when rn=20 then cust_id end)=0 then null else count(case when rn=20 then cust_id end) end as m19
    , case when count(case when rn=21 then cust_id end)=0 then null else count(case when rn=21 then cust_id end) end as m20
    , case when count(case when rn=22 then cust_id end)=0 then null else count(case when rn=22 then cust_id end) end as m21
    , case when count(case when rn=23 then cust_id end)=0 then null else count(case when rn=23 then cust_id end) end as m22
    , case when count(case when rn=24 then cust_id end)=0 then null else count(case when rn=24 then cust_id end) end as m23
    , case when count(case when rn=25 then cust_id end)=0 then null else count(case when rn=25 then cust_id end) end as m24
    , case when count(case when rn=26 then cust_id end)=0 then null else count(case when rn=26 then cust_id end) end as m25
    , case when count(case when rn=27 then cust_id end)=0 then null else count(case when rn=27 then cust_id end) end as m26
    , case when count(case when rn=28 then cust_id end)=0 then null else count(case when rn=28 then cust_id end) end as m27
    , case when count(case when rn=29 then cust_id end)=0 then null else count(case when rn=29 then cust_id end) end as m28
    , case when count(case when rn=30 then cust_id end)=0 then null else count(case when rn=30 then cust_id end) end as m29
    , case when count(case when rn=31 then cust_id end)=0 then null else count(case when rn=31 then cust_id end) end as m30
    , case when count(case when rn=32 then cust_id end)=0 then null else count(case when rn=32 then cust_id end) end as m31
    , case when count(case when rn=33 then cust_id end)=0 then null else count(case when rn=33 then cust_id end) end as m32
    , case when count(case when rn=34 then cust_id end)=0 then null else count(case when rn=34 then cust_id end) end as m33  -- Added by Coe
    , case when count(case when rn=35 then cust_id end)=0 then null else count(case when rn=35 then cust_id end) end as m34  -- Added by Coe
    , case when count(case when rn=36 then cust_id end)=0 then null else count(case when rn=36 then cust_id end) end as m35  -- Added by Coe
    , case when count(case when rn=37 then cust_id end)=0 then null else count(case when rn=37 then cust_id end) end as m36  -- Added by Coe
    , case when count(case when rn=38 then cust_id end)=0 then null else count(case when rn=38 then cust_id end) end as m37  -- Added by Coe
    , case when count(case when rn=39 then cust_id end)=0 then null else count(case when rn=39 then cust_id end) end as m38  -- Added by Coe
    , case when count(case when rn=40 then cust_id end)=0 then null else count(case when rn=40 then cust_id end) end as m39  -- Added by Coe
    , case when count(case when rn=41 then cust_id end)=0 then null else count(case when rn=41 then cust_id end) end as m40  -- Added by Coe
    , case when count(case when rn=42 then cust_id end)=0 then null else count(case when rn=42 then cust_id end) end as m41  -- Added by Coe
  from rn
  where start_month>=201304 and start_month<=201608 and active_month<=201609  -- Changed by Coe
  group by 1
  -- order by start_month
)
select start_month
  , m0
  , m0-m1 as m1
  , m1-m2 as m2
  , m2-m3 as m3
  , m3-m4 as m4
  , m4-m5 as m5
  , m5-m6 as m6
  , m6-m7 as m7
  , m7-m8 as m8
  , m8-m9 as m9
  , m9-m10 as m10
  , m10-m11 as m11
  , m11-m12 as m12
  , m12-m13 as m13
  , m13-m14 as m14
  , m14-m15 as m15
  , m15-m16 as m16
  , m16-m17 as m17
  , m17-m18 as m18
  , m18-m19 as m19
  , m19-m20 as m20
  , m20-m21 as m21
  , m21-m22 as m22
  , m22-m23 as m23
  , m23-m24 as m24
  , m24-m25 as m25
  , m25-m26 as m26
  , m26-m27 as m27
  , m27-m28 as m28
  , m28-m29 as m29
  , m29-m30 as m30
  , m30-m31 as m31
  , m31-m32 as m32
  , m32-m33 as m33  -- Added by Coe
  , m33-m34 as m34  -- Added by Coe
  , m34-m35 as m35  -- Added by Coe
  , m35-m36 as m36  -- Added by Coe
  , m36-m37 as m37  -- Added by Coe
  , m37-m38 as m38  -- Added by Coe
  , m38-m39 as m39  -- Added by Coe
  , m39-m40 as m40  -- Added by Coe
  , m40-m41 as m41  -- Added by Coe
from retained
order by 1

----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
    -- %Churned-LT
with t1 as
(
  select x.cust_id
    --, a.PRODUCT_LN_KEY 
    , x.year_month as active_month                
    , case when x.year_month between 201301 and 201312                 
     then (x.year_month-201300)                
     when x.year_month between 201401 and 201412                 
     then (x.year_month-201400+12)                 
     when x.year_month between 201501 and 201512                 
     then (x.year_month-201500+24)
     when x.year_month between 201601 and 201612                 
     then (x.year_month-201600+36)
    end as month_number                
  , sum(x.final_price) as revenue        
  from
  (
    select xx.customer_id as cust_id  
      --, a.ORDER_NBR
      --, a.INVC_ID
      -- , a.PRODUCT_LN_KEY 
      --, d.actual_date as purchase_date 
      , xx. year_month              
      , xx.order_line_payment_date as payment_date              
      , xx.order_line_begin_date as begin_use_date  
      --, d2.actual_date as cancel_date
      --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP
      --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price
      , case when xx.order_line_payment_date='-1' then 0  else sum(xx.order_line_net_price_amount_usd) end as final_price
    from 
    (                
      select *               
        , cast(yearmonth as int) as year_month            
      from dm.order_line_accumulation_fact               
    ) xx    
    where 
    --c.cust_id in (100)
    xx. product_line_id in (2,7)                
    and xx.order_line_begin_date>='2013-01-01'
    group by 1,2,3,4
  ) x
  group by 1,2,3
),

t2 as
(
  select a.cust_id
    , min(a.month_number) as Start_Month
    , max(a.month_number) as End_Month
  from
  (
    select t1.*
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap
    from t1
  ) a
  group by a.gap, a.cust_id
  -- order by min(a.month_number)
),

t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
),  

ms as
(
  select t3.cust_id
    , min(t3.start_month) as min_start_month
  from t3
  group by 1
),

rn as
(
  select x.*
    , row_number() over (partition by x.cust_id order by x.active_month) as rn
  from 
  (
    select t3.cust_id
      , t3.startmonth as start_month
      , t3.active_month
      , t3.revenue
    from t3, ms
    where t3.cust_id = ms.cust_id and t3.start_month = ms.min_start_month
  ) x
)

, retained as
(
  select start_month
    , case when count(case when rn=1 then cust_id end)=0 then null else count(case when rn=1 then cust_id end) end as m0
    , case when count(case when rn=2 then  cust_id end)=0 then null else count(case when rn=2 then  cust_id end) end as m1
    , case when count(case when rn=3 then  cust_id end)=0 then null else count(case when rn=3 then  cust_id end) end as m2
    , case when count(case when rn=4 then  cust_id end)= 0 then null else count(case when rn=4 then  cust_id end) end as m3
    , case when count(case when rn=5 then cust_id end)=0 then null else count(case when rn=5 then cust_id end) end as m4
    , case when count(case when rn=6 then cust_id end)=0 then null else count(case when rn=6 then cust_id end) end as m5
    , case when count(case when rn=7 then cust_id end)=0 then null else count(case when rn=7 then cust_id end) end as m6
    , case when count(case when rn=8 then cust_id end)=0 then null else count(case when rn=8 then cust_id end) end as m7
    , case when count(case when rn=9 then cust_id end)=0 then null else count(case when rn=9 then cust_id end) end as m8
    , case when count(case when rn=10 then cust_id end)=0 then null else count(case when rn=10 then cust_id end) end as m9
    , case when count(case when rn=11 then cust_id end)=0 then null else count(case when rn=11 then cust_id end) end as m10
    , case when count(case when rn=12 then cust_id end)=0 then null else count(case when rn=12 then cust_id end) end as m11
    , case when count(case when rn=13 then cust_id end)=0 then null else count(case when rn=13 then cust_id end) end as m12
    , case when count(case when rn=14 then cust_id end)=0 then null else count(case when rn=14 then cust_id end) end as m13
    , case when count(case when rn=15 then cust_id end)=0 then null else count(case when rn=15 then cust_id end) end as m14
    , case when count(case when rn=16 then cust_id end)=0 then null else count(case when rn=16 then cust_id end) end as m15
    , case when count(case when rn=17 then cust_id end)=0 then null else count(case when rn=17 then cust_id end) end as m16
    , case when count(case when rn=18 then cust_id end)=0 then null else count(case when rn=18 then cust_id end) end as m17
    , case when count(case when rn=19 then cust_id end)=0 then null else count(case when rn=19 then cust_id end) end as m18
    , case when count(case when rn=20 then cust_id end)=0 then null else count(case when rn=20 then cust_id end) end as m19
    , case when count(case when rn=21 then cust_id end)=0 then null else count(case when rn=21 then cust_id end) end as m20
    , case when count(case when rn=22 then cust_id end)=0 then null else count(case when rn=22 then cust_id end) end as m21
    , case when count(case when rn=23 then cust_id end)=0 then null else count(case when rn=23 then cust_id end) end as m22
    , case when count(case when rn=24 then cust_id end)=0 then null else count(case when rn=24 then cust_id end) end as m23
    , case when count(case when rn=25 then cust_id end)=0 then null else count(case when rn=25 then cust_id end) end as m24
    , case when count(case when rn=26 then cust_id end)=0 then null else count(case when rn=26 then cust_id end) end as m25
    , case when count(case when rn=27 then cust_id end)=0 then null else count(case when rn=27 then cust_id end) end as m26
    , case when count(case when rn=28 then cust_id end)=0 then null else count(case when rn=28 then cust_id end) end as m27
    , case when count(case when rn=29 then cust_id end)=0 then null else count(case when rn=29 then cust_id end) end as m28
    , case when count(case when rn=30 then cust_id end)=0 then null else count(case when rn=30 then cust_id end) end as m29
    , case when count(case when rn=31 then cust_id end)=0 then null else count(case when rn=31 then cust_id end) end as m30
    , case when count(case when rn=32 then cust_id end)=0 then null else count(case when rn=32 then cust_id end) end as m31
    , case when count(case when rn=33 then cust_id end)=0 then null else count(case when rn=33 then cust_id end) end as m32
    , case when count(case when rn=34 then cust_id end)=0 then null else count(case when rn=34 then cust_id end) end as m33  -- Added by Coe
    , case when count(case when rn=35 then cust_id end)=0 then null else count(case when rn=35 then cust_id end) end as m34  -- Added by Coe
    , case when count(case when rn=36 then cust_id end)=0 then null else count(case when rn=36 then cust_id end) end as m35  -- Added by Coe
    , case when count(case when rn=37 then cust_id end)=0 then null else count(case when rn=37 then cust_id end) end as m36  -- Added by Coe
    , case when count(case when rn=38 then cust_id end)=0 then null else count(case when rn=38 then cust_id end) end as m37  -- Added by Coe
    , case when count(case when rn=39 then cust_id end)=0 then null else count(case when rn=39 then cust_id end) end as m38  -- Added by Coe
    , case when count(case when rn=40 then cust_id end)=0 then null else count(case when rn=40 then cust_id end) end as m39  -- Added by Coe
    , case when count(case when rn=41 then cust_id end)=0 then null else count(case when rn=41 then cust_id end) end as m40  -- Added by Coe
    , case when count(case when rn=42 then cust_id end)=0 then null else count(case when rn=42 then cust_id end) end as m41  -- Added by Coe
  from rn
  where start_month>=201304 and start_month<=201608 and active_month<=201609  -- Changed by Coe

  group by 1
  -- order by start_month
)

, churned as
(
  select start_month
    , m0
    , m0-m1 as m1
    , m1-m2 as m2
    , m2-m3 as m3
    , m3-m4 as m4
    , m4-m5 as m5
    , m5-m6 as m6
    , m6-m7 as m7
    , m7-m8 as m8
    , m8-m9 as m9
    , m9-m10 as m10
    , m10-m11 as m11
    , m11-m12 as m12
    , m12-m13 as m13
    , m13-m14 as m14
    , m14-m15 as m15
    , m15-m16 as m16
    , m16-m17 as m17
    , m17-m18 as m18
    , m18-m19 as m19
    , m19-m20 as m20
    , m20-m21 as m21
    , m21-m22 as m22
    , m22-m23 as m23
    , m23-m24 as m24
    , m24-m25 as m25
    , m25-m26 as m26
    , m26-m27 as m27
    , m27-m28 as m28
    , m28-m29 as m29
    , m29-m30 as m30
    , m30-m31 as m31
    , m31-m32 as m32
    , m32-m33 as m33  -- Added by Coe
    , m33-m34 as m34  -- Added by Coe
    , m34-m35 as m35  -- Added by Coe
    , m35-m36 as m36  -- Added by Coe
    , m36-m37 as m37  -- Added by Coe
    , m37-m38 as m38  -- Added by Coe
    , m38-m39 as m39  -- Added by Coe
    , m39-m40 as m40  -- Added by Coe
    , m40-m41 as m41  -- Added by Coe
  from retained
  -- order by 1
)

select start_month
  , m0
  , cast(m1 as float)/cast(m0 as float) as m1
  , cast(m2 as float)/cast(m0 as float) as m2
  , cast(m3 as float)/cast(m0 as float) as m3
  , cast(m4 as float)/cast(m0 as float) as m4
  , cast(m5 as float)/cast(m0 as float) as m5
  , cast(m6 as float)/cast(m0 as float) as m6
  , cast(m7 as float)/cast(m0 as float) as m7
  , cast(m8 as float)/cast(m0 as float) as m8
  , cast(m9 as float)/cast(m0 as float) as m9
  , cast(m10 as float)/cast(m0 as float) as m10
  , cast(m11 as float)/cast(m0 as float) as m11
  , cast(m12 as float)/cast(m0 as float) as m12
  , cast(m13 as float)/cast(m0 as float) as m13
  , cast(m14 as float)/cast(m0 as float) as m14
  , cast(m15 as float)/cast(m0 as float) as m15
  , cast(m16 as float)/cast(m0 as float) as m16
  , cast(m17 as float)/cast(m0 as float) as m17
  , cast(m18 as float)/cast(m0 as float) as m18
  , cast(m19 as float)/cast(m0 as float) as m19
  , cast(m20 as float)/cast(m0 as float) as m20
  , cast(m21 as float)/cast(m0 as float) as m21
  , cast(m22 as float)/cast(m0 as float) as m22
  , cast(m23 as float)/cast(m0 as float) as m23
  , cast(m24 as float)/cast(m0 as float) as m24
  , cast(m25 as float)/cast(m0 as float) as m25
  , cast(m26 as float)/cast(m0 as float) as m26
  , cast(m27 as float)/cast(m0 as float) as m27
  , cast(m28 as float)/cast(m0 as float) as m28
  , cast(m29 as float)/cast(m0 as float) as m29
  , cast(m30 as float)/cast(m0 as float) as m30
  , cast(m31 as float)/cast(m0 as float) as m31
  , cast(m32 as float)/cast(m0 as float) as m32
  , cast(m33 as float)/cast(m0 as float) as m33  -- Added by Coe
  , cast(m34 as float)/cast(m0 as float) as m34  -- Added by Coe
  , cast(m35 as float)/cast(m0 as float) as m35  -- Added by Coe
  , cast(m36 as float)/cast(m0 as float) as m36  -- Added by Coe
  , cast(m37 as float)/cast(m0 as float) as m37  -- Added by Coe
  , cast(m38 as float)/cast(m0 as float) as m38  -- Added by Coe
  , cast(m39 as float)/cast(m0 as float) as m39  -- Added by Coe
  , cast(m40 as float)/cast(m0 as float) as m40  -- Added by Coe
  , cast(m41 as float)/cast(m0 as float) as m41  -- Added by Coe
from churned
order by 1

----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
-- CustomerMRR-LT
--     RetainedMRR-LT0
with t1 as
(
  with base as                    
  (                    
    select x.cust_id                  
    --, a.PRODUCT_LN_KEY                   
      , x.year_month as active_month                
      , case when x.year_month between 201301 and 201312                 
       then (x.year_month-201300)                
       when x.year_month between 201401 and 201412                 
       then (x.year_month-201400+12)                 
       when x.year_month between 201501 and 201512                 
       then (x.year_month-201500+24)
       when x.year_month between 201601 and 201612                 
       then (x.year_month-201600+36)
      end as month_number                
    , sum(x.final_price) as final_price                  
    from                  
    (                  
      select xx.customer_id as cust_id                
        --, a.ORDER_NBR              
        --, a.INVC_ID              
        --, a.PRODUCT_LN_KEY               
        --, d.actual_date as purchase_date               
        , xx.year_month              
        , xx.order_line_payment_date as payment_date              
        , xx.order_line_begin_date as begin_use_date              
        --, d2.actual_date as cancel_date              
        --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP              
        --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price              
        , case when xx.order_line_payment_date='-1' then 0               
          else (            
              case when day(xx.order_line_begin_date)=1 then sum(xx.order_line_net_price_amount_usd)        
              else (        
                  case when month(xx.order_line_begin_date) in (1,3,5,7,8,10,12)     
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=31 then sum(xx.order_line_net_price_amount_usd)*31
                       else sum(xx.order_line_net_price_amount_usd)*31/(31-day(xx.order_line_begin_date)) end
                    )  
                    when  month(xx.order_line_begin_date)=2  
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=28 then sum(xx.order_line_net_price_amount_usd)*28
                       else sum(xx.order_line_net_price_amount_usd)*28/(28-day(xx.order_line_begin_date)) end
                    )  
                    else   
                    (  
                      case when day(xx.order_line_begin_date)=30 then sum(xx.order_line_net_price_amount_usd)*30
                       else sum(xx.order_line_net_price_amount_usd)*30/(30-day(xx.order_line_begin_date)) end
                    )  
                    end  
                ) end      
            )           
        end as final_price              
      from                 
      (                
        select *               
          , cast(yearmonth as int) as year_month            
        from dm.order_line_accumulation_fact               
      ) xx                
      where                 
      --c.cust_id in (100)                
      xx. product_line_id in (2,7)                
      and xx.order_line_begin_date>='2013-01-01'                 
      --and p.cust_id!='-1'                              
      group by 1,2,3,4                
    ) x                  
    group by 1,2,3                  
  )                    

  select y.cust_id                  
    , y.active_month                
    , y.month_number                
    , case when y.active_month<=201407                 
      then (              
          case when y.price_lastmonth=0 then           
          (          
            case when y.price_nextmonth=0 then y.final_price         
            else y.price_nextmonth end         
          )          
           else y.final_price end          
        )            
      else y.final_price end as revenue  ---prorated adjusted to full month price:MRR              
  from                  
  (                  
    select b1.*                
      , coalesce(b2.final_price,0) as price_lastmonth              
      , coalesce(b3.final_price,0) as price_nextmonth              
    from base b1                
    left join                
    base b2 on b1.month_number=b2.month_number+1 and b1.cust_id=b2.cust_id                
    left join base b3 on b1.month_number=b3.month_number-1 and b1.cust_id=b3.cust_id                
  ) y 
),

t2 as                    
(                    
  select a.cust_id                  
    , min(a.month_number) as Start_Month                
    , max(a.month_number) as End_Month                
  from                  
  (                  
    select t1.*                
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap              
    from t1                
  ) a                  
  group by a.gap, a.cust_id                  
  -- order by min(a.month_number)                  
),                    
                    
t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
),                    

ms as
(
  select t3.cust_id
    , min(t3.start_month) as min_start_month
  from t3
  group by 1
),

t4 as
(
  select t3.cust_id
    , t3.startmonth as start_month
    --, case when t3.active_month='201301' then t3.revenue else 0 end as Jan_2013
    --, case when t3.active_month='201302' then t3.revenue else 0 end as Feb_2013
    --, case when t3.active_month='201303' then t3.revenue else 0 end as Mar_2013
    , case when t3.active_month=201304 then t3.revenue else 0 end as Apr_2013
    , case when t3.active_month=201305 then t3.revenue else 0 end as May_2013
    , case when t3.active_month=201306 then t3.revenue else 0 end as Jun_2013
    , case when t3.active_month=201307 then t3.revenue else 0 end as Jul_2013
    , case when t3.active_month=201308 then t3.revenue else 0 end as Aug_2013
    , case when t3.active_month=201309 then t3.revenue else 0 end as Sep_2013
    , case when t3.active_month=201310 then t3.revenue else 0 end as Oct_2013
    , case when t3.active_month=201311 then t3.revenue else 0 end as Nov_2013
    , case when t3.active_month=201312 then t3.revenue else 0 end as Dec_2013
    , case when t3.active_month=201401 then t3.revenue else 0 end as Jan_2014
    , case when t3.active_month=201402 then t3.revenue else 0 end as Feb_2014
    , case when t3.active_month=201403 then t3.revenue else 0 end as Mar_2014
    , case when t3.active_month=201404 then t3.revenue else 0 end as Apr_2014
    , case when t3.active_month=201405 then t3.revenue else 0 end as May_2014
    , case when t3.active_month=201406 then t3.revenue else 0 end as Jun_2014
    , case when t3.active_month=201407 then t3.revenue else 0 end as Jul_2014
    , case when t3.active_month=201408 then t3.revenue else 0 end as Aug_2014
    , case when t3.active_month=201409 then t3.revenue else 0 end as Sep_2014
    , case when t3.active_month=201410 then t3.revenue else 0 end as Oct_2014
    , case when t3.active_month=201411 then t3.revenue else 0 end as Nov_2014
    , case when t3.active_month=201412 then t3.revenue else 0 end as Dec_2014
    , case when t3.active_month=201501 then t3.revenue else 0 end as Jan_2015
    , case when t3.active_month=201502 then t3.revenue else 0 end as Feb_2015
    , case when t3.active_month=201503 then t3.revenue else 0 end as Mar_2015
    , case when t3.active_month=201504 then t3.revenue else 0 end as Apr_2015
    , case when t3.active_month=201505 then t3.revenue else 0 end as May_2015
    , case when t3.active_month=201506 then t3.revenue else 0 end as Jun_2015
    , case when t3.active_month=201507 then t3.revenue else 0 end as Jul_2015
    , case when t3.active_month=201508 then t3.revenue else 0 end as Aug_2015
    , case when t3.active_month=201509 then t3.revenue else 0 end as Sep_2015
    , case when t3.active_month=201510 then t3.revenue else 0 end as Oct_2015
    , case when t3.active_month=201511 then t3.revenue else 0 end as Nov_2015
    , case when t3.active_month=201512 then t3.revenue else 0 end as Dec_2015
    , case when t3.active_month=201601 then t3.revenue else 0 end as Jan_2016  -- Added by Coe
    , case when t3.active_month=201602 then t3.revenue else 0 end as Feb_2016  -- Added by Coe
    , case when t3.active_month=201603 then t3.revenue else 0 end as Mar_2016  -- Added by Coe
    , case when t3.active_month=201604 then t3.revenue else 0 end as Apr_2016  -- Added by Coe
    , case when t3.active_month=201605 then t3.revenue else 0 end as May_2016  -- Added by Coe
    , case when t3.active_month=201606 then t3.revenue else 0 end as Jun_2016  -- Added by Coe
    , case when t3.active_month=201607 then t3.revenue else 0 end as Jul_2016  -- Added by Coe
    , case when t3.active_month=201608 then t3.revenue else 0 end as Aug_2016  -- Added by Coe
    , case when t3.active_month=201609 then t3.revenue else 0 end as Sep_2016  -- Added by Coe
  from t3, ms
  where t3.cust_id = ms.cust_id and t3.start_month = ms.min_start_month
)

select t4.start_month
  --, sum(t4.Jan_2013) as Jan_2013
  --, sum(t4.Feb_2013) as Feb_2013
  --, sum(t4.Mar_2013) as Mar_2013
  , sum(t4.Apr_2013) as Apr_2013
  , sum(t4.May_2013) as May_2013
  , sum(t4.Jun_2013) as Jun_2013
  , sum(t4.Jul_2013) as Jul_2013
  , sum(t4.Aug_2013) as Aug_2013
  , sum(t4.Sep_2013) as Sep_2013
  , sum(t4.Oct_2013) as Oct_2013
  , sum(t4.Nov_2013) as Nov_2013
  , sum(t4.Dec_2013) as Dec_2013
  , sum(t4.Jan_2014) as Jan_2014
  , sum(t4.Feb_2014) as Feb_2014
  , sum(t4.Mar_2014) as Mar_2014
  , sum(t4.Apr_2014) as Apr_2014
  , sum(t4.May_2014) as May_2014
  , sum(t4.Jun_2014) as Jun_2014
  , sum(t4.Jul_2014) as Jul_2014
  , sum(t4.Aug_2014) as Aug_2014
  , sum(t4.Sep_2014) as Sep_2014
  , sum(t4.Oct_2014) as Oct_2014
  , sum(t4.Nov_2014) as Nov_2014
  , sum(t4.Dec_2014) as Dec_2014
  , sum(t4.Jan_2015) as Jan_2015
  , sum(t4.Feb_2015) as Feb_2015
  , sum(t4.Mar_2015) as Mar_2015
  , sum(t4.Apr_2015) as Apr_2015
  , sum(t4.May_2015) as May_2015
  , sum(t4.Jun_2015) as Jun_2015
  , sum(t4.Jul_2015) as Jul_2015
  , sum(t4.Aug_2015) as Aug_2015
  , sum(t4.Sep_2015) as Sep_2015
  , sum(t4.Oct_2015) as Oct_2015
  , sum(t4.Nov_2015) as Nov_2015
  , sum(t4.Dec_2015) as Dec_2015
  , sum(t4.Jan_2016) as Jan_2016  -- Added by Coe
  , sum(t4.Feb_2016) as Feb_2016  -- Added by Coe
  , sum(t4.Mar_2016) as Mar_2016  -- Added by Coe
  , sum(t4.Apr_2016) as Apr_2016  -- Added by Coe
  , sum(t4.May_2016) as May_2016  -- Added by Coe
  , sum(t4.Jun_2016) as Jun_2016  -- Added by Coe
  , sum(t4.Jul_2016) as Jul_2016  -- Added by Coe
  , sum(t4.Aug_2016) as Aug_2016  -- Added by Coe
  , sum(t4.Sep_2016) as Sep_2016  -- Added by Coe
from t4
where t4.start_month>201303
group by 1
order by t4.start_month

----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
    -- RetainedMRR-LT
with t1 as
(
  with base as                    
  (                    
    select x.cust_id                  
    --, a.PRODUCT_LN_KEY                   
      , x.year_month as active_month                
      , case when x.year_month between 201301 and 201312                 
       then (x.year_month-201300)                
       when x.year_month between 201401 and 201412                 
       then (x.year_month-201400+12)                 
       when x.year_month between 201501 and 201512                 
       then (x.year_month-201500+24)
       when x.year_month between 201601 and 201612                 
       then (x.year_month-201600+36)
      end as month_number                
    , sum(x.final_price) as final_price                  
    from                  
    (                  
      select xx.customer_id as cust_id                
        --, a.ORDER_NBR              
        --, a.INVC_ID              
        --, a.PRODUCT_LN_KEY               
        --, d.actual_date as purchase_date               
        , xx. year_month              
        , xx.order_line_payment_date as payment_date              
        , xx.order_line_begin_date as begin_use_date              
        --, d2.actual_date as cancel_date              
        --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP              
        --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price              
        , case when xx.order_line_payment_date='-1' then 0               
          else (            
              case when day(xx.order_line_begin_date)=1 then sum(xx.order_line_net_price_amount_usd)        
              else (        
                  case when month(xx.order_line_begin_date) in (1,3,5,7,8,10,12)     
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=31 then sum(xx.order_line_net_price_amount_usd)*31
                       else sum(xx.order_line_net_price_amount_usd)*31/(31-day(xx.order_line_begin_date)) end
                    )  
                    when  month(xx.order_line_begin_date)=2  
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=28 then sum(xx.order_line_net_price_amount_usd)*28
                       else sum(xx.order_line_net_price_amount_usd)*28/(28-day(xx.order_line_begin_date)) end
                    )  
                    else   
                    (  
                      case when day(xx.order_line_begin_date)=30 then sum(xx.order_line_net_price_amount_usd)*30
                       else sum(xx.order_line_net_price_amount_usd)*30/(30-day(xx.order_line_begin_date)) end
                    )  
                    end  
                ) end      
            )           
        end as final_price              
      from                 
      (                
        select *               
          , cast(yearmonth as int) as year_month            
        from dm.order_line_accumulation_fact               
      ) xx                
      where                 
      --c.cust_id in (100)                
      xx. product_line_id in (2,7)                
      and xx.order_line_begin_date>='2013-01-01'                 
      --and p.cust_id!='-1'                              
      group by 1,2,3,4                
    ) x                  
    group by 1,2,3                  
  )                    

  select y.cust_id                  
    , y.active_month                
    , y.month_number                
    , case when y.active_month<=201407                 
      then (              
          case when y.price_lastmonth=0 then           
          (          
            case when y.price_nextmonth=0 then y.final_price         
            else y.price_nextmonth end         
          )          
           else y.final_price end          
        )            
      else y.final_price end as revenue  ---prorated adjusted to full month price:MRR              
  from                  
  (                  
    select b1.*                
      , coalesce(b2.final_price,0) as price_lastmonth              
      , coalesce(b3.final_price,0) as price_nextmonth              
    from base b1                
    left join                
    base b2 on b1.month_number=b2.month_number+1 and b1.cust_id=b2.cust_id                
    left join base b3 on b1.month_number=b3.month_number-1 and b1.cust_id=b3.cust_id                
  ) y 
),

t2 as                    
(                    
  select a.cust_id                  
    , min(a.month_number) as Start_Month                
    , max(a.month_number) as End_Month                
  from                  
  (                  
    select t1.*                
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap              
    from t1                
  ) a                  
  group by a.gap, a.cust_id                  
  -- order by min(a.month_number)                  
),                    
                    
t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
),                    

ms as
(
  select t3.cust_id
    , min(t3.start_month) as min_start_month
  from t3
  group by 1
),

rn as
(
  select x.*
    , row_number() over (partition by x.cust_id order by x.active_month) as rn
  from 
  (
    select t3.cust_id
      , t3.startmonth as start_month
      , t3.active_month
      , t3.revenue
    from t3, ms
    where t3.cust_id = ms.cust_id and t3.start_month = ms.min_start_month
  ) x
)

select start_month
  , sum(case when rn=1 then revenue end) as m0
  , sum(case when rn=2 then  revenue end) as m1
  , sum(case when rn=3 then  revenue end) as m2
  , sum(case when rn=4 then  revenue end) as m3
  , sum(case when rn=5 then  revenue end) as m4
  , sum(case when rn=6 then  revenue end) as m5
  , sum(case when rn=7 then  revenue end) as m6
  , sum(case when rn=8 then  revenue end) as m7
  , sum(case when rn=9 then  revenue end) as m8
  , sum(case when rn=10 then  revenue end) as m9
  , sum(case when rn=11 then  revenue end) as m10
  , sum(case when rn=12 then  revenue end) as m11
  , sum(case when rn=13 then  revenue end) as m12
  , sum(case when rn=14 then  revenue end) as m13
  , sum(case when rn=15 then  revenue end) as m14
  , sum(case when rn=16 then  revenue end) as m15
  , sum(case when rn=17 then  revenue end) as m16
  , sum(case when rn=18 then  revenue end) as m17
  , sum(case when rn=19 then  revenue end) as m18
  , sum(case when rn=20 then  revenue end) as m19
  , sum(case when rn=21 then  revenue end) as m20
  , sum(case when rn=22 then  revenue end) as m21
  , sum(case when rn=23 then  revenue end) as m22
  , sum(case when rn=24 then  revenue end) as m23
  , sum(case when rn=25 then  revenue end) as m24
  , sum(case when rn=26 then  revenue end) as m25
  , sum(case when rn=27 then  revenue end) as m26
  , sum(case when rn=28 then  revenue end) as m27
  , sum(case when rn=29 then  revenue end) as m28
  , sum(case when rn=30 then  revenue end) as m29
  , sum(case when rn=31 then  revenue end) as m30
  , sum(case when rn=32 then  revenue end) as m31
  , sum(case when rn=33 then  revenue end) as m32
  , sum(case when rn=34 then  revenue end) as m33  -- Added by Coe
  , sum(case when rn=35 then  revenue end) as m34  -- Added by Coe
  , sum(case when rn=36 then  revenue end) as m35  -- Added by Coe
  , sum(case when rn=37 then  revenue end) as m36  -- Added by Coe
  , sum(case when rn=38 then  revenue end) as m37  -- Added by Coe
  , sum(case when rn=39 then  revenue end) as m38  -- Added by Coe
  , sum(case when rn=40 then  revenue end) as m39  -- Added by Coe
  , sum(case when rn=41 then  revenue end) as m40  -- Added by Coe
  , sum(case when rn=42 then  revenue end) as m41  -- Added by Coe
from rn
where start_month>=201304 and start_month<=201608 and active_month<=201609  -- Changed by Coe
group by 1
order by start_month

----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
    -- ChurnedMRR-LT
with t1 as
(
  with base as                    
  (                    
    select x.cust_id                  
    --, a.PRODUCT_LN_KEY                   
      , x.year_month as active_month                
      , case when x.year_month between 201301 and 201312                 
       then (x.year_month-201300)                
       when x.year_month between 201401 and 201412                 
       then (x.year_month-201400+12)                 
       when x.year_month between 201501 and 201512                 
       then (x.year_month-201500+24)
       when x.year_month between 201601 and 201612                 
       then (x.year_month-201600+36)
      end as month_number                
    , sum(x.final_price) as final_price                  
    from                  
    (                  
      select xx.customer_id as cust_id                
        --, a.ORDER_NBR              
        --, a.INVC_ID              
        --, a.PRODUCT_LN_KEY               
        --, d.actual_date as purchase_date               
        , xx. year_month              
        , xx.order_line_payment_date as payment_date              
        , xx.order_line_begin_date as begin_use_date              
        --, d2.actual_date as cancel_date              
        --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP              
        --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price              
        , case when xx.order_line_payment_date='-1' then 0               
          else (            
              case when day(xx.order_line_begin_date)=1 then sum(xx.order_line_net_price_amount_usd)        
              else (        
                  case when month(xx.order_line_begin_date) in (1,3,5,7,8,10,12)     
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=31 then sum(xx.order_line_net_price_amount_usd)*31
                       else sum(xx.order_line_net_price_amount_usd)*31/(31-day(xx.order_line_begin_date)) end
                    )  
                    when  month(xx.order_line_begin_date)=2  
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=28 then sum(xx.order_line_net_price_amount_usd)*28
                       else sum(xx.order_line_net_price_amount_usd)*28/(28-day(xx.order_line_begin_date)) end
                    )  
                    else   
                    (  
                      case when day(xx.order_line_begin_date)=30 then sum(xx.order_line_net_price_amount_usd)*30
                       else sum(xx.order_line_net_price_amount_usd)*30/(30-day(xx.order_line_begin_date)) end
                    )  
                    end  
                ) end      
            )           
        end as final_price              
      from                 
      (                
        select *               
          , cast(yearmonth as int) as year_month            
        from dm.order_line_accumulation_fact               
      ) xx                
      where                 
      --c.cust_id in (100)                
      xx. product_line_id in (2,7)                
      and xx.order_line_begin_date>='2013-01-01'                 
      --and p.cust_id!='-1'                              
      group by 1,2,3,4                
    ) x                  
    group by 1,2,3                  
  )                    

  select y.cust_id                  
    , y.active_month                
    , y.month_number                
    , case when y.active_month<=201407                 
      then (              
          case when y.price_lastmonth=0 then           
          (          
            case when y.price_nextmonth=0 then y.final_price         
            else y.price_nextmonth end         
          )          
           else y.final_price end          
        )            
      else y.final_price end as revenue  ---prorated adjusted to full month price:MRR              
  from                  
  (                  
    select b1.*                
      , coalesce(b2.final_price,0) as price_lastmonth              
      , coalesce(b3.final_price,0) as price_nextmonth              
    from base b1                
    left join                
    base b2 on b1.month_number=b2.month_number+1 and b1.cust_id=b2.cust_id                
    left join base b3 on b1.month_number=b3.month_number-1 and b1.cust_id=b3.cust_id                
  ) y 
),

t2 as                    
(                    
  select a.cust_id                  
    , min(a.month_number) as Start_Month                
    , max(a.month_number) as End_Month                
  from                  
  (                  
    select t1.*                
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap              
    from t1                
  ) a                  
  group by a.gap, a.cust_id                  
  -- order by min(a.month_number)                  
),                    
                    
t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
),                    

ms as
(
  select t3.cust_id
    , min(t3.start_month) as min_start_month
  from t3
  group by 1
),

rn as
(
  select x.*
    , row_number() over (partition by x.cust_id order by x.active_month) as rn
  from 
  (
    select t3.cust_id
      , t3.startmonth as start_month
      , t3.active_month
      , t3.revenue
    from t3, ms
    where t3.cust_id = ms.cust_id and t3.start_month = ms.min_start_month
  ) x
)

, retained as
(
  select start_month
    , case when sum(case when rn=1 then revenue end)=0 then null else sum(case when rn=1 then revenue end) end as m0
    , case when sum(case when rn=2 then  revenue end)=0 then null else sum(case when rn=2 then  revenue end) end as m1
    , case when sum(case when rn=3 then  revenue end)=0 then null else sum(case when rn=3 then  revenue end) end as m2
    , case when sum(case when rn=4 then  revenue end)= 0 then null else sum(case when rn=4 then  revenue end) end as m3
    , case when sum(case when rn=5 then revenue end)=0 then null else sum(case when rn=5 then revenue end) end as m4
    , case when sum(case when rn=6 then revenue end)=0 then null else sum(case when rn=6 then revenue end) end as m5
    , case when sum(case when rn=7 then revenue end)=0 then null else sum(case when rn=7 then revenue end) end as m6
    , case when sum(case when rn=8 then revenue end)=0 then null else sum(case when rn=8 then revenue end) end as m7
    , case when sum(case when rn=9 then revenue end)=0 then null else sum(case when rn=9 then revenue end) end as m8
    , case when sum(case when rn=10 then revenue end)=0 then null else sum(case when rn=10 then revenue end) end as m9
    , case when sum(case when rn=11 then revenue end)=0 then null else sum(case when rn=11 then revenue end) end as m10
    , case when sum(case when rn=12 then revenue end)=0 then null else sum(case when rn=12 then revenue end) end as m11
    , case when sum(case when rn=13 then revenue end)=0 then null else sum(case when rn=13 then revenue end) end as m12
    , case when sum(case when rn=14 then revenue end)=0 then null else sum(case when rn=14 then revenue end) end as m13
    , case when sum(case when rn=15 then revenue end)=0 then null else sum(case when rn=15 then revenue end) end as m14
    , case when sum(case when rn=16 then revenue end)=0 then null else sum(case when rn=16 then revenue end) end as m15
    , case when sum(case when rn=17 then revenue end)=0 then null else sum(case when rn=17 then revenue end) end as m16
    , case when sum(case when rn=18 then revenue end)=0 then null else sum(case when rn=18 then revenue end) end as m17
    , case when sum(case when rn=19 then revenue end)=0 then null else sum(case when rn=19 then revenue end) end as m18
    , case when sum(case when rn=20 then revenue end)=0 then null else sum(case when rn=20 then revenue end) end as m19
    , case when sum(case when rn=21 then revenue end)=0 then null else sum(case when rn=21 then revenue end) end as m20
    , case when sum(case when rn=22 then revenue end)=0 then null else sum(case when rn=22 then revenue end) end as m21
    , case when sum(case when rn=23 then revenue end)=0 then null else sum(case when rn=23 then revenue end) end as m22
    , case when sum(case when rn=24 then revenue end)=0 then null else sum(case when rn=24 then revenue end) end as m23
    , case when sum(case when rn=25 then revenue end)=0 then null else sum(case when rn=25 then revenue end) end as m24
    , case when sum(case when rn=26 then revenue end)=0 then null else sum(case when rn=26 then revenue end) end as m25
    , case when sum(case when rn=27 then revenue end)=0 then null else sum(case when rn=27 then revenue end) end as m26
    , case when sum(case when rn=28 then revenue end)=0 then null else sum(case when rn=28 then revenue end) end as m27
    , case when sum(case when rn=29 then revenue end)=0 then null else sum(case when rn=29 then revenue end) end as m28
    , case when sum(case when rn=30 then revenue end)=0 then null else sum(case when rn=30 then revenue end) end as m29
    , case when sum(case when rn=31 then revenue end)=0 then null else sum(case when rn=31 then revenue end) end as m30
    , case when sum(case when rn=32 then revenue end)=0 then null else sum(case when rn=32 then revenue end) end as m31
    , case when sum(case when rn=33 then revenue end)=0 then null else sum(case when rn=33 then revenue end) end as m32
    , case when sum(case when rn=34 then revenue end)=0 then null else sum(case when rn=34 then revenue end) end as m33  -- Added by Coe
    , case when sum(case when rn=35 then revenue end)=0 then null else sum(case when rn=35 then revenue end) end as m34  -- Added by Coe
    , case when sum(case when rn=36 then revenue end)=0 then null else sum(case when rn=36 then revenue end) end as m35  -- Added by Coe
    , case when sum(case when rn=37 then revenue end)=0 then null else sum(case when rn=37 then revenue end) end as m36  -- Added by Coe
    , case when sum(case when rn=38 then revenue end)=0 then null else sum(case when rn=38 then revenue end) end as m37  -- Added by Coe
    , case when sum(case when rn=39 then revenue end)=0 then null else sum(case when rn=39 then revenue end) end as m38  -- Added by Coe
    , case when sum(case when rn=40 then revenue end)=0 then null else sum(case when rn=40 then revenue end) end as m39  -- Added by Coe
    , case when sum(case when rn=41 then revenue end)=0 then null else sum(case when rn=41 then revenue end) end as m40  -- Added by Coe
    , case when sum(case when rn=42 then revenue end)=0 then null else sum(case when rn=42 then revenue end) end as m41  -- Added by Coe
  from rn
  where start_month>=201304 and start_month<=201608 and active_month<=201609  -- Changed by Coe
  group by 1
  -- order by start_month
)
select start_month
  , m0
  , m0-m1 as m1
  , m1-m2 as m2
  , m2-m3 as m3
  , m3-m4 as m4
  , m4-m5 as m5
  , m5-m6 as m6
  , m6-m7 as m7
  , m7-m8 as m8
  , m8-m9 as m9
  , m9-m10 as m10
  , m10-m11 as m11
  , m11-m12 as m12
  , m12-m13 as m13
  , m13-m14 as m14
  , m14-m15 as m15
  , m15-m16 as m16
  , m16-m17 as m17
  , m17-m18 as m18
  , m18-m19 as m19
  , m19-m20 as m20
  , m20-m21 as m21
  , m21-m22 as m22
  , m22-m23 as m23
  , m23-m24 as m24
  , m24-m25 as m25
  , m25-m26 as m26
  , m26-m27 as m27
  , m27-m28 as m28
  , m28-m29 as m29
  , m29-m30 as m30
  , m30-m31 as m31
  , m31-m32 as m32
  , m32-m33 as m33  -- Added by Coe
  , m33-m34 as m34  -- Added by Coe
  , m34-m35 as m35  -- Added by Coe
  , m35-m36 as m36  -- Added by Coe
  , m36-m37 as m37  -- Added by Coe
  , m37-m38 as m38  -- Added by Coe
  , m38-m39 as m39  -- Added by Coe
  , m39-m40 as m40  -- Added by Coe
  , m40-m41 as m41  -- Added by Coe
from retained
order by 1

----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
----------------------------------------------------------------------
    -- %ChurnedMRR-LT
with t1 as
(
  with base as                    
  (                    
    select x.cust_id                  
    --, a.PRODUCT_LN_KEY                   
      , x.year_month as active_month                
      , case when x.year_month between 201301 and 201312                 
       then (x.year_month-201300)                
       when x.year_month between 201401 and 201412                 
       then (x.year_month-201400+12)                 
       when x.year_month between 201501 and 201512                 
       then (x.year_month-201500+24)
       when x.year_month between 201601 and 201612                 
       then (x.year_month-201600+36)
      end as month_number                
    , sum(x.final_price) as final_price                  
    from                  
    (                  
      select xx.customer_id as cust_id                
        --, a.ORDER_NBR              
        --, a.INVC_ID              
        --, a.PRODUCT_LN_KEY               
        --, d.actual_date as purchase_date               
        , xx. year_month              
        , xx.order_line_payment_date as payment_date              
        , xx.order_line_begin_date as begin_use_date              
        --, d2.actual_date as cancel_date              
        --, sum(a.ORDER_LN_PKG_PRICE_AMT_USD) as MSRP              
        --, sum(a.ORDER_LN_PURCH_PRICE_AMT_USD) as purchase_price              
        , case when xx.order_line_payment_date='-1' then 0               
          else (            
              case when day(xx.order_line_begin_date)=1 then sum(xx.order_line_net_price_amount_usd)        
              else (        
                  case when month(xx.order_line_begin_date) in (1,3,5,7,8,10,12)     
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=31 then sum(xx.order_line_net_price_amount_usd)*31
                       else sum(xx.order_line_net_price_amount_usd)*31/(31-day(xx.order_line_begin_date)) end
                    )  
                    when  month(xx.order_line_begin_date)=2  
                    then   
                    (  
                      case when day(xx.order_line_begin_date)=28 then sum(xx.order_line_net_price_amount_usd)*28
                       else sum(xx.order_line_net_price_amount_usd)*28/(28-day(xx.order_line_begin_date)) end
                    )  
                    else   
                    (  
                      case when day(xx.order_line_begin_date)=30 then sum(xx.order_line_net_price_amount_usd)*30
                       else sum(xx.order_line_net_price_amount_usd)*30/(30-day(xx.order_line_begin_date)) end
                    )  
                    end  
                ) end      
            )           
        end as final_price              
      from                 
      (                
        select *               
          , cast(yearmonth as int) as year_month            
        from dm.order_line_accumulation_fact               
      ) xx                
      where                 
      --c.cust_id in (100)                
      xx. product_line_id in (2,7)                
      and xx.order_line_begin_date>='2013-01-01'                 
      --and p.cust_id!='-1'                              
      group by 1,2,3,4                
    ) x                  
    group by 1,2,3                  
  )                    

  select y.cust_id                  
    , y.active_month                
    , y.month_number                
    , case when y.active_month<=201407                 
      then (              
          case when y.price_lastmonth=0 then           
          (          
            case when y.price_nextmonth=0 then y.final_price         
            else y.price_nextmonth end         
          )          
           else y.final_price end          
        )            
      else y.final_price end as revenue  ---prorated adjusted to full month price:MRR              
  from                  
  (                  
    select b1.*                
      , coalesce(b2.final_price,0) as price_lastmonth              
      , coalesce(b3.final_price,0) as price_nextmonth              
    from base b1                
    left join                
    base b2 on b1.month_number=b2.month_number+1 and b1.cust_id=b2.cust_id                
    left join base b3 on b1.month_number=b3.month_number-1 and b1.cust_id=b3.cust_id                
  ) y 
),

t2 as                    
(                    
  select a.cust_id                  
    , min(a.month_number) as Start_Month                
    , max(a.month_number) as End_Month                
  from                  
  (                  
    select t1.*                
      , dense_rank() over (partition by t1.cust_id order by t1.active_month) - month_number as gap              
    from t1                
  ) a                  
  group by a.gap, a.cust_id                  
  -- order by min(a.month_number)                  
),                    
                    
t3 as                    
(                    
  select a.*                  
    , b.active_month                
    , b.month_number                
    , b.revenue                
  from                  
  (                  
    select t2.cust_id                
      , case when t2.start_month<=12 then t2.start_month+201300               
        when t2.start_month between 13 and 24 then t2.start_month+201400-12            
        when t2.start_month between 25 and 36 then t2.start_month+201500-24 
        when t2.start_month between 37 and 48 then t2.start_month+201600-36
        end as startmonth            
      , case when t2.end_month<=12 then t2.end_month+201300               
        when t2.end_month between 13 and 24 then t2.end_month+201400-12            
        when t2.end_month between 25 and 36 then t2.end_month+201500-24 
        when t2.end_month between 37 and 48 then t2.end_month+201600-36          
        end as endmonth            
      , t2.start_month              
      , t2.end_month              
    from t2                
  ) a                  
  join                   
  (                  
    select t1.cust_id                
      , t1.active_month              
      , t1.month_number              
      , sum(t1.revenue) as revenue              
    from t1                
    group by 1,2,3                
  ) b on b.cust_id=a.cust_id                   
  where a.startmonth<=b.active_month                  
  and a.endmonth>=b.active_month                  
),                    

ms as
(
  select t3.cust_id
    , min(t3.start_month) as min_start_month
  from t3
  group by 1
),

rn as
(
  select x.*
    , row_number() over (partition by x.cust_id order by x.active_month) as rn
  from 
  (
    select t3.cust_id
      , t3.startmonth as start_month
      , t3.active_month
      , t3.revenue
    from t3, ms
    where t3.cust_id = ms.cust_id and t3.start_month = ms.min_start_month
  ) x
)

, retained as
(
  select start_month
    , case when sum(case when rn=1 then revenue end)=0 then null else sum(case when rn=1 then revenue end) end as m0
    , case when sum(case when rn=2 then  revenue end)=0 then null else sum(case when rn=2 then  revenue end) end as m1
    , case when sum(case when rn=3 then  revenue end)=0 then null else sum(case when rn=3 then  revenue end) end as m2
    , case when sum(case when rn=4 then  revenue end)= 0 then null else sum(case when rn=4 then  revenue end) end as m3
    , case when sum(case when rn=5 then revenue end)=0 then null else sum(case when rn=5 then revenue end) end as m4
    , case when sum(case when rn=6 then revenue end)=0 then null else sum(case when rn=6 then revenue end) end as m5
    , case when sum(case when rn=7 then revenue end)=0 then null else sum(case when rn=7 then revenue end) end as m6
    , case when sum(case when rn=8 then revenue end)=0 then null else sum(case when rn=8 then revenue end) end as m7
    , case when sum(case when rn=9 then revenue end)=0 then null else sum(case when rn=9 then revenue end) end as m8
    , case when sum(case when rn=10 then revenue end)=0 then null else sum(case when rn=10 then revenue end) end as m9
    , case when sum(case when rn=11 then revenue end)=0 then null else sum(case when rn=11 then revenue end) end as m10
    , case when sum(case when rn=12 then revenue end)=0 then null else sum(case when rn=12 then revenue end) end as m11
    , case when sum(case when rn=13 then revenue end)=0 then null else sum(case when rn=13 then revenue end) end as m12
    , case when sum(case when rn=14 then revenue end)=0 then null else sum(case when rn=14 then revenue end) end as m13
    , case when sum(case when rn=15 then revenue end)=0 then null else sum(case when rn=15 then revenue end) end as m14
    , case when sum(case when rn=16 then revenue end)=0 then null else sum(case when rn=16 then revenue end) end as m15
    , case when sum(case when rn=17 then revenue end)=0 then null else sum(case when rn=17 then revenue end) end as m16
    , case when sum(case when rn=18 then revenue end)=0 then null else sum(case when rn=18 then revenue end) end as m17
    , case when sum(case when rn=19 then revenue end)=0 then null else sum(case when rn=19 then revenue end) end as m18
    , case when sum(case when rn=20 then revenue end)=0 then null else sum(case when rn=20 then revenue end) end as m19
    , case when sum(case when rn=21 then revenue end)=0 then null else sum(case when rn=21 then revenue end) end as m20
    , case when sum(case when rn=22 then revenue end)=0 then null else sum(case when rn=22 then revenue end) end as m21
    , case when sum(case when rn=23 then revenue end)=0 then null else sum(case when rn=23 then revenue end) end as m22
    , case when sum(case when rn=24 then revenue end)=0 then null else sum(case when rn=24 then revenue end) end as m23
    , case when sum(case when rn=25 then revenue end)=0 then null else sum(case when rn=25 then revenue end) end as m24
    , case when sum(case when rn=26 then revenue end)=0 then null else sum(case when rn=26 then revenue end) end as m25
    , case when sum(case when rn=27 then revenue end)=0 then null else sum(case when rn=27 then revenue end) end as m26
    , case when sum(case when rn=28 then revenue end)=0 then null else sum(case when rn=28 then revenue end) end as m27
    , case when sum(case when rn=29 then revenue end)=0 then null else sum(case when rn=29 then revenue end) end as m28
    , case when sum(case when rn=30 then revenue end)=0 then null else sum(case when rn=30 then revenue end) end as m29
    , case when sum(case when rn=31 then revenue end)=0 then null else sum(case when rn=31 then revenue end) end as m30
    , case when sum(case when rn=32 then revenue end)=0 then null else sum(case when rn=32 then revenue end) end as m31
    , case when sum(case when rn=33 then revenue end)=0 then null else sum(case when rn=33 then revenue end) end as m32
    , case when sum(case when rn=34 then revenue end)=0 then null else sum(case when rn=34 then revenue end) end as m33  -- Added by Coe
    , case when sum(case when rn=35 then revenue end)=0 then null else sum(case when rn=35 then revenue end) end as m34  -- Added by Coe
    , case when sum(case when rn=36 then revenue end)=0 then null else sum(case when rn=36 then revenue end) end as m35  -- Added by Coe
    , case when sum(case when rn=37 then revenue end)=0 then null else sum(case when rn=37 then revenue end) end as m36  -- Added by Coe
    , case when sum(case when rn=38 then revenue end)=0 then null else sum(case when rn=38 then revenue end) end as m37  -- Added by Coe
    , case when sum(case when rn=39 then revenue end)=0 then null else sum(case when rn=39 then revenue end) end as m38  -- Added by Coe
    , case when sum(case when rn=40 then revenue end)=0 then null else sum(case when rn=40 then revenue end) end as m39  -- Added by Coe
    , case when sum(case when rn=41 then revenue end)=0 then null else sum(case when rn=41 then revenue end) end as m40  -- Added by Coe
    , case when sum(case when rn=42 then revenue end)=0 then null else sum(case when rn=42 then revenue end) end as m41  -- Added by Coe
  from rn
  where start_month>=201304 and start_month<=201608 and active_month<=201609  -- Changed by Coe
  group by 1
  -- order by start_month
)

, churned as
(
  select start_month
    , m0
    , m0-m1 as m1
    , m1-m2 as m2
    , m2-m3 as m3
    , m3-m4 as m4
    , m4-m5 as m5
    , m5-m6 as m6
    , m6-m7 as m7
    , m7-m8 as m8
    , m8-m9 as m9
    , m9-m10 as m10
    , m10-m11 as m11
    , m11-m12 as m12
    , m12-m13 as m13
    , m13-m14 as m14
    , m14-m15 as m15
    , m15-m16 as m16
    , m16-m17 as m17
    , m17-m18 as m18
    , m18-m19 as m19
    , m19-m20 as m20
    , m20-m21 as m21
    , m21-m22 as m22
    , m22-m23 as m23
    , m23-m24 as m24
    , m24-m25 as m25
    , m25-m26 as m26
    , m26-m27 as m27
    , m27-m28 as m28
    , m28-m29 as m29
    , m29-m30 as m30
    , m30-m31 as m31
    , m31-m32 as m32
    , m32-m33 as m33  -- Added by Coe
    , m33-m34 as m34  -- Added by Coe
    , m34-m35 as m35  -- Added by Coe
    , m35-m36 as m36  -- Added by Coe
    , m36-m37 as m37  -- Added by Coe
    , m37-m38 as m38  -- Added by Coe
    , m38-m39 as m39  -- Added by Coe
    , m39-m40 as m40  -- Added by Coe
    , m40-m41 as m41  -- Added by Coe
  from retained
  -- order by 1
)
select start_month
  , m0
  , cast(m1 as float)/cast(m0 as float) as m1
  , cast(m2 as float)/cast(m0 as float) as m2
  , cast(m3 as float)/cast(m0 as float) as m3
  , cast(m4 as float)/cast(m0 as float) as m4
  , cast(m5 as float)/cast(m0 as float) as m5
  , cast(m6 as float)/cast(m0 as float) as m6
  , cast(m7 as float)/cast(m0 as float) as m7
  , cast(m8 as float)/cast(m0 as float) as m8
  , cast(m9 as float)/cast(m0 as float) as m9
  , cast(m10 as float)/cast(m0 as float) as m10
  , cast(m11 as float)/cast(m0 as float) as m11
  , cast(m12 as float)/cast(m0 as float) as m12
  , cast(m13 as float)/cast(m0 as float) as m13
  , cast(m14 as float)/cast(m0 as float) as m14
  , cast(m15 as float)/cast(m0 as float) as m15
  , cast(m16 as float)/cast(m0 as float) as m16
  , cast(m17 as float)/cast(m0 as float) as m17
  , cast(m18 as float)/cast(m0 as float) as m18
  , cast(m19 as float)/cast(m0 as float) as m19
  , cast(m20 as float)/cast(m0 as float) as m20
  , cast(m21 as float)/cast(m0 as float) as m21
  , cast(m22 as float)/cast(m0 as float) as m22
  , cast(m23 as float)/cast(m0 as float) as m23
  , cast(m24 as float)/cast(m0 as float) as m24
  , cast(m25 as float)/cast(m0 as float) as m25
  , cast(m26 as float)/cast(m0 as float) as m26
  , cast(m27 as float)/cast(m0 as float) as m27
  , cast(m28 as float)/cast(m0 as float) as m28
  , cast(m29 as float)/cast(m0 as float) as m29
  , cast(m30 as float)/cast(m0 as float) as m30
  , cast(m31 as float)/cast(m0 as float) as m31
  , cast(m32 as float)/cast(m0 as float) as m32
  , cast(m33 as float)/cast(m0 as float) as m33  -- Added by Coe
  , cast(m34 as float)/cast(m0 as float) as m34  -- Added by Coe
  , cast(m35 as float)/cast(m0 as float) as m35  -- Added by Coe
  , cast(m36 as float)/cast(m0 as float) as m36  -- Added by Coe
  , cast(m37 as float)/cast(m0 as float) as m37  -- Added by Coe
  , cast(m38 as float)/cast(m0 as float) as m38  -- Added by Coe
  , cast(m39 as float)/cast(m0 as float) as m39  -- Added by Coe
  , cast(m40 as float)/cast(m0 as float) as m40  -- Added by Coe
  , cast(m41 as float)/cast(m0 as float) as m41  -- Added by Coe
from churned
order by 1

-- 1. Retained customers in month #Retained-LT0 has extra columns.  Fixed.
-- 2. Churned customers in lifetime month #Churned-LT might not have enough rows - why no March?  Fixed.
-- 3. MRR from churned customers in lifetime month ChurnedMRR-LT looks totally wrong.  Fixed,  Can''t have comment at start.

-- Wait extra colums on last tab too.  Need to recreate table.  Done.

-- Want cohorts by quarter as well; want month too.

-- Sayle also does % each month compared to month 1.
-- She sent me her version of the report.
