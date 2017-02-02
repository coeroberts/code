with answertime as
(
  SELECT Q.ID as question_id
    , to_date(q.created_at) as question_date
    -- , D.YEAR||' Q'||D.QTR_NBR_IN_YEAR AS YEAR_QTR
        , round((min(unix_timestamp(A.created_at)-unix_timestamp(Q.created_at)))/60,0) as answertime_mins
  FROM src.content_question q
  -- JOIN DM.DATE_DIM D ON to_date(Q.created_at) = D.ACTUAL_DATE
  LEFT JOIN 
  (
    select distinct id as answer_id
      , created_at
      , question_id
    from src.content_answer 
    where approval_status_id in (1,2)
  ) A ON Q.id=A.question_id
  WHERE to_date(q.created_at) >= '2013-01-01'
      and q.approval_status_id in (1,2)
  group by 1,2
)

, questions as
(
  select distinct q.id as question_id
    , sd.specialty_name as specialty
    , sd.parent_specialty_name as parent_specialty
    , a.id as answer_id
    , q.created_by as asker
    , p.professional_id
    , to_date(a.created_at) as answer_date
    , dd.year_month as answer_year_month
    , to_date(q.created_at) as question_date
    , dd1.year_month as question_year_month
  from src.content_question q
  left join dm.specialty_dimension sd on sd.specialty_id = q.specialty_id
  LEFT JOIN 
  (
    select distinct id 
      , created_at
      , created_by
      , question_id
    from src.content_answer 
    where approval_status_id in (1,2)
  ) A ON Q.id=A.question_id
  left join dm.professional_dimension p on p.professional_user_account_id = cast(a.created_by as string)
  left join dm.date_dim dd on to_date(dd.actual_date)=to_date(a.created_at)
  left join dm.date_dim dd1 on to_date(dd1.actual_date)=to_date(q.created_at)
  where to_date(q.created_at) >= '2013-01-01' 
       and q.approval_status_id in (1,2)
)

, returned_asker as
(
  select x1.asker
  from
  (
    select distinct x.asker
    from questions x
    join
    (
       select distinct d.year_month     
       from DM.DATE_DIM d
       where d.actual_date = to_date(now()- interval 1 month)
    ) dt on dt.year_month = x.question_year_month
  ) x1
  left join
  (
    select distinct x.asker
    from questions x
    join
    (
       select distinct d.year_month     
       from DM.DATE_DIM d
       where d.actual_date <= to_date(now()- interval 2 month)
      and d.actual_date >= to_date(now()- interval 4 month)
    ) dt on dt.year_month = x.question_year_month
  ) x2 on x1.asker = x2.asker
  left join
  (
    select distinct x.asker
    from questions x
    join
    (
       select distinct d.year_month     
       from DM.DATE_DIM d
       where d.actual_date < to_date(now()- interval 4 month)
    ) dt on dt.year_month = x.question_year_month
  ) x3 on x1.asker = x3.asker
  where x2.asker is null and x3.asker is not null
)

select qs.question_id
  , qs.specialty as question_specialty
  , qs.parent_specialty as question_parent_specialty
  , qs.answer_id
  , qs.professional_id
  , qs.asker
  , case when ra.asker is null then "N" else "Y" end as asker_returned_3month_later
  , qs.answer_date
  , qs.question_date
  , qs.answer_year_month
  , qs.question_year_month
  , ast.answertime_mins
        , to_date(uad.user_account_register_datetime) as user_account_register_datetime
        , dt.year_month as registration_year_month
from questions qs 
left join answertime ast on ast.question_id = qs.question_id
left join returned_asker ra on qs.asker = ra.asker
left join dm.user_account_dimension uad on uad.user_account_id = qs.asker
join dm.date_dim dt on to_date(dt.actual_date)=to_date(uad.user_account_register_datetime)
