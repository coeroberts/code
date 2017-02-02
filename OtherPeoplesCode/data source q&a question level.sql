SELECT a.id as question_id
     , a.subject as question_title
     , a.specialty_id
     , b.specialty_name as speclty_name
     , b.parent_specialty_name as parnt_speclty_name
     , a.created_by as asker
     , g.geo_state_name as question_state
     , to_date(a.created_at) as question_creation_date
     , count(c.id) as number_answers
     , max(c.best_answer) as best_answer
     , round((min(unix_timestamp(c.created_at)-unix_timestamp(a.created_at)))/60,0) as answer_mins
     , max(case when to_date(a.created_at) between to_date(cast(d.rpt_wk_begin_date as timestamp)- interval 7 day) and to_date(cast(d.rpt_wk_begin_date as timestamp)- interval 1 day) then 'This Week'
                when to_date(a.created_at) between to_date(cast(d.rpt_wk_begin_date as timestamp)- interval 14 day) and to_date(cast(d.rpt_wk_begin_date as timestamp)- interval 8 day) then 'Last Week'
                when to_date(a.created_at) between to_date(cast(d.rpt_prev_year_wk_begin_date as timestamp)- interval 7 day) and to_date(cast(d.rpt_prev_year_wk_begin_date as timestamp)- interval 1 day) then 'Last Year'
           end) as Week_indicator
FROM src.content_question a
left join src.content_answer c
on a.id = c.question_id
inner join dm.specialty_dimension b
on a.specialty_id = b.specialty_id
inner join dm.geography_dimension g 
on a.location_id = g.geo_id
inner join dm.date_dim d
  on to_date(now()) = d.actual_date
where to_date(a.created_at) between to_date(cast(d.rpt_prev_year_wk_begin_date as timestamp)- interval 7 day) and to_date(cast(d.rpt_wk_begin_date as timestamp)- interval 1 day)
and a.approval_status_id in (1,2)
and (c.approval_status_id in (1,2) or c.approval_status_id is null)
group by 1,2,3,4,5,6,7,8