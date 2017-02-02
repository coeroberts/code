import sys
import os
from time import sleep

import pandas as pd
import numpy as np

from functions.bigquery_calls import bq_to_pandas
from functions.alerts import send_email_alert
from functions.impala_conn import get_data_from_impala
import functions.event_detection as ed

from oauth2client.client import GoogleCredentials
from googleapiclient.discovery import build

test_file = 'resources/test_data/acv_drop_20pct.csv'

# not currently in use
acceptable_drop_rate = .15

mean_threshold = 250
stakeholders = ['mkleiman@avvo.com']


# Credentials flow
os.environ['GOOGLE_APPLICATION_CREDENTIALS'] = 'resources/auth/service_account_1.json'
credentials = GoogleCredentials.get_application_default()
bq_service = build('bigquery', 'v2', credentials=credentials)


def retrieve_dataset(filename):
    dataset = pd.read_csv(filename)
    dataset.event_date = pd.to_datetime(dataset.event_date)
    dataset.index = dataset[dataset.columns[0]]
    dataset = dataset[dataset.columns[1]]
    return dataset


def main():
    # dataset = retrieve_dataset(test_file)

    # Run detection on ACV
    query = """
        select event_date
            , sum(sl_adcontact_value)+sum(da_adcontact_value) as acv
        from dm.webanalytics_ad_attribution_by_session
        where event_date between '2016-02-23' and '2016-04-21'
        group by 1
        UNION
        select '2016-04-22' as event_date
            , 369355.16*.8 as acv
        order by 1;
        """
    dataset = get_data_from_impala(query)
    dataset.event_date = pd.to_datetime(dataset.event_date)
    dataset.index = dataset[dataset.columns[0]]
    dayofweek = dataset.index.dayofweek
    dataset = pd.DataFrame({dataset.columns[1]: dataset[dataset.columns[1]], 'dayofweek': dayofweek})

    # get daily change
    if ed.get_daily_change(dataset, -0.15):
        send_email_alert(data_series=dataset[dataset.columns[0]], to=stakeholders, trigger='daily_drop')
    # get change over last few weeks (for day of week only
    if ed.day_of_week_avg(dataset, look_back=4, acceptable_change_rate=-0.15):
        send_email_alert(data_series=dataset[dataset.columns[0]], to=stakeholders, trigger='dayofweek')

    # Run detection on visits
    query = """
    select date(date) as event_date
    , sum(totals.visits) as num_visits
        from TABLE_DATE_RANGE ([75615261.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -50, 'DAY'),CURRENT_TIMESTAMP())
    group by 1
    order by 1
    """

    visits = bq_to_pandas(query)
    visits.event_date = pd.to_datetime(visits.event_date)
    visits.index = visits[visits.columns[0]]
    dayofweek = visits.index.dayofweek
    visits = pd.DataFrame({visits.columns[1]: visits[visits.columns[1]], 'dayofweek': dayofweek})
    visits = visits[['num_visits', 'dayofweek']]
    # get daily change
    if ed.get_daily_change(visits, -0.15):
        send_email_alert(data_series=visits[visits.columns[0]], to=stakeholders, trigger='daily_drop')
    # get change over last few weeks (for day of week only
    if ed.day_of_week_avg(visits, look_back=4, acceptable_change_rate=-0.15):
        send_email_alert(data_series=visits[visits.columns[0]], to=stakeholders, trigger='dayofweek')

    # Run detection on content groups
    query = """
    select date(date) as event_date
        , hits.customDimensions.value as content_group
        , count(*) as page_views
    from TABLE_DATE_RANGE ([75615261.ga_sessions_], DATE_ADD(CURRENT_TIMESTAMP(), -40, 'DAY'),CURRENT_TIMESTAMP())
    where hits.type = 'PAGE' and hits.customDimensions.index = 19
    group by 1, 2
    order by 1, 2
    """
    content_groups = bq_to_pandas(query)
    # content_groups = pd.read_csv('resources/test_data/content_groups.csv')
    date_values = pd.DataFrame(pd.unique(content_groups.event_date), columns=['event_date'])
    gbo = content_groups.groupby(['content_group'])
    for name, group in gbo:
        merged_group = group.merge(date_values, how='right', on='event_date')
        merged_group.index = pd.to_datetime(merged_group.event_date)
        data_series = merged_group[merged_group.columns[2]]
        data_series[np.isnan(data_series)] = 0
        dayofweek = data_series.index.dayofweek
        content_group_data_set = pd.DataFrame({data_series.name: data_series, 'dayofweek': dayofweek})
        content_group_data_set = content_group_data_set[['page_views', 'dayofweek']]
        test_mean = content_group_data_set[content_group_data_set.columns[0]].mean()

        if ed.get_daily_change(content_group_data_set, acceptable_change_rate=-0.15) and test_mean > mean_threshold:
            extra = 'content_group = ' + name
            print 'sending email alert for ' + extra
            send_email_alert(data_series=content_group_data_set[content_group_data_set.columns[0]], to=stakeholders,
                             trigger='daily_drop', additional_info=extra)
            sleep(1)
        if ed.get_daily_change(content_group_data_set, acceptable_change_rate=0.15) and test_mean > mean_threshold:
            extra = 'content_group = ' + name
            print 'sending email alert for ' + extra
            send_email_alert(data_series=content_group_data_set[content_group_data_set.columns[0]], to=stakeholders,
                             trigger='daily_increase', additional_info=extra)
            sleep(1)
        if ed.day_of_week_avg(dataset, look_back=4, acceptable_change_rate=-0.15):
            send_email_alert(data_series=dataset[dataset.columns[0]], to=stakeholders, trigger='dayofweek')

    # Run detection on call time
    query = """
    select call_date as event_date
        , count(distinct call_id) as num_calls
    from dm.call_detail_rec_fact cdr
    where call_date between '2016-02-26' and '2016-04-24'
    group by 1
    UNION
    select '2016-04-25' as call_date
        , 4757 as num_calls
    order by 1;
    """

    data_set = get_data_from_impala(query)
    data_set.event_date = pd.to_datetime(data_set.event_date)
    data_set.index = data_set[data_set.columns[0]]
    dayofweek = data_set.index.dayofweek
    data_set = pd.DataFrame({data_set.columns[1]: data_set[data_set.columns[1]], 'dayofweek': dayofweek})
    data_set = data_set[['num_calls', 'dayofweek']]
    # get daily change
    if ed.get_daily_change(dataset, -0.15):
        send_email_alert(data_series=data_set[data_set.columns[0]], to=stakeholders, trigger='daily_drop')
    # get change over last few weeks (for day of week only)
    if ed.day_of_week_avg(data_set, look_back=4, acceptable_change_rate=-0.15):
        send_email_alert(data_series=data_set[data_set.columns[0]], to=stakeholders, trigger='dayofweek')

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print 'Interrupted'
        try:
            sys.exit(0)
        except SystemExit:
            os._exit(0)
