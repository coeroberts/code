import pandas as pd
import bigquery_requests as bqr
from os import path
from datetime import datetime, date, timedelta


#
#  We are writing SQL queries to our BigQuery database to capture all user activity related to ALS
#  We then parse the results to count the ALS landing pages, and the conversions associated with them
#
#

"""
Session data 4: has date, filtered out user groups, no cross_sells within funnel
Session data 5: sample with two cross sell events
"""
# session_logs = pd.read_csv('resources/session_data_4.csv')
# session_logs = pd.read_csv('resources/als_sample_funnel_data.csv')
# session_logs = pd.read_csv('resources/session_data_5.csv')

# These dates will be run! Please make sure these are date objects, otherwise there will be errors
funnel_begin_date = date(2016, 04, 28)
funnel_end_date = date(2016, 04, 28)


def _generate_output_frame(data_frame):
    """
    Used inside of funnel method. Aggregates to date/landing_page and lists landings+conversions
    :param data_frame: DF passed through a funnel method
    :rtype pd.DataFrame
    :return DF with index ('date', 'user_action') and columns 'view_attribution', 'conversion_attribution'
    """
    if not isinstance(data_frame, pd.DataFrame):
        raise TypeError('Expected pandas DataFrame, got %s' % type(data_frame))

    required_columns = {'date', 'VisitorID', 'visitID', 'user_action', 'page_category', 'view_attribution',
                        'conversion_attribution'}
    if not required_columns.issubset(set(data_frame.columns)):
        raise ValueError('Expected %s columns' % str(required_columns))

    print 'Output frame:'
    output_frame = data_frame[['date', 'user_action', 'view_attribution', 'conversion_attribution']].groupby(
        ['date', 'user_action']).sum()
    output_frame = output_frame[output_frame['view_attribution'] > 0]
    print output_frame

    assert isinstance(output_frame, pd.DataFrame)
    return output_frame


def _find_conversion_events(data_frame):
    """
    Used inside of funnel method. Outputs all events with conversions
    :param data_frame: DF passed through a funnel method
    :rtype pd.DataFrame
    :return DF with columns 'date', 'user_action', 'view_attribution', 'conversion_attribution'
    """
    if not isinstance(data_frame, pd.DataFrame):
        raise TypeError('Expected pandas DataFrame, got %s' % type(data_frame))

    required_columns = {'date', 'VisitorID', 'visitID', 'user_action', 'page_category', 'view_attribution',
                        'conversion_attribution'}
    if not required_columns.issubset(set(data_frame.columns)):
        raise ValueError('Expected %s columns' % str(required_columns))

    print 'Conversion sessions:'
    conversion_sessions = data_frame.loc[
        data_frame['conversion_attribution'] > 0, ['date', 'user_action', 'VisitorID', 'visitID']].sort_values(
        'user_action', ascending=False)
    print conversion_sessions

    assert isinstance(conversion_sessions, pd.DataFrame)
    return conversion_sessions


def create_als_landing_funnel(data_frame):
    """
    Creates a funnel table from a df containing fullVisitorId, visitId, user action, page category, date, & medium
    Note this will add two columns to the data_frame passed
    :return tuple of funnel table and debug logs
    """
    if not isinstance(data_frame, pd.DataFrame):
        raise TypeError('Expected pandas DataFrame, got %s' % type(data_frame))

    required_columns = {'date', 'medium', 'VisitorID', 'visitID', 'user_action', 'page_category'}
    if not required_columns.issubset(set(data_frame.columns)):
        raise ValueError('Expected %s columns' % str(required_columns))

    # new plan is to just create columns and then groupby/agg those columns correctly
    data_frame['view_attribution'] = 0
    data_frame['conversion_attribution'] = 0

    # iterate through each session
    each_session = data_frame.groupby(['date', 'medium', 'VisitorID', 'visitID'])
    for name, session in each_session:
        # find the last item in the session for sanity checks later.
        max_row_index = session.tail(1).index[0]
        # find the first ALS landing page
        if not session[session['page_category'] == 'ALS Store'].head(1).empty:
            als_landing = session[session['page_category'] == 'ALS Store'].head(1).index[0]
        else:
            als_landing = -1
        # find first purchase event
        if not session[session['user_action'] == 'ecommerce'].head(1).empty:
            thank_you_page = session[session['user_action'] == 'ecommerce'].head(1).index[0]
        else:
            thank_you_page = -1

        # TODO: more clarity in this section 
        # iterate through each session's events/pageviews
        for row_index, row_series in session.iterrows():
            # filter out events not of interest
            if row_series['user_action'] == 'Click on cross-sell advertising'\
                    or row_series['page_category'] == 'ALS Store':
                # if cross sell event then find the next ALS landing page. we'll attribute to that one.
                if row_series['user_action'] == 'Click on cross-sell advertising':
                    als_landing = row_index+1
                    # find next ALS landing page in the current session
                    while data_frame.loc[als_landing, 'page_category'] != 'ALS Store':
                        # insurance to make sure we don't accidentally attribute to a different session
                        if als_landing > max_row_index:
                            break
                        als_landing += 1
            if als_landing:
                if row_index == als_landing:
                    # put attributed view into output table
                    data_frame.loc[row_index, 'view_attribution'] += 1

            if thank_you_page:
                if row_index == thank_you_page:
                    # put attributed conversion into output table
                    data_frame.loc[als_landing, 'conversion_attribution'] += 1

    # Select columns of interest and aggregate data
    output_frame = _generate_output_frame(data_frame)
    conversion_sessions = _find_conversion_events(data_frame)

    return output_frame, conversion_sessions


def per_delta(start, end, delta):
    """
     Creates an iterable of all dates in between start and end at every delta interval
    :param date start: Start date
    :param date end: End date. Will be included in list if needed.
    :param timedelta delta: interval to increment by
    :return: an iterable containing date objects
    """
    curr = start
    while curr <= end:
        yield curr
        curr += delta


def create_funnel_query(date_string):
    """
     Generates a query string for obtaining BigQuery weblog data
    :param str date_string: of the form 'YYYYDDmm' e.g. '20160504'
    :rtype: str
    :return: a valid BigQuery query that will be used for obtaining session data
    """
    query = """
    select table_a.date as date,
           STRING(table_a.fullVisitorId) as VisitorID,
           STRING(table_a.visitId) as visitID,
           table_a.medium as medium,
           table_a.visit_seconds as event_seconds,
           ifnull(table_c.content_group, table_a.content_group) as content_group,
           case when table_a.url like '%%programs.avvo.com%%' then 'ALS Store'
                else ifnull(table_c.page_category, 'Not ALS Store')
            end as page_category,
           case when table_a.ad_click is not null then "Click on cross-sell advertising"
              when table_a.event_category = 'ecommerce' then 'ecommerce'
              when table_a.url like '%%programs.avvo.com%%' then 'ALS SEM'
              when table_c.page_type is null then 'other'
              else table_c.page_type
            end as user_action,
          table_a.url as url,
          table_a.ad_click,
          table_a.visitStartTime as visitStartTime


    from ( SELECT date(date) as date,
            fullVisitorId,
            visitId,
            visitStartTime,
            integer(hits.time/1000) AS visit_seconds,
            MAX(IF(hits.customDimensions.index=19,hits.customDimensions.value, NULL)) WITHIN hits as content_group,
            trafficSource.medium as medium,
            hits.eventInfo.eventLabel as ad_click,
            hits.eventInfo.eventCategory as event_category,
            CONCAT("http://", hits.page.hostname,  hits.page.pagePath) as url
         FROM [75615261.ga_sessions_%s]
         where
         (
          (hits.eventInfo.eventCategory = "cross sell advertising"
           and  hits.eventInfo.eventAction = "click ad"
           and hits.type = "EVENT" and hits.page.pagePath not like '%%legal-services%%')
           or
          (hits.type  = "PAGE")
           or
          (hits.eventInfo.eventCategory = 'ecommerce' and
           hits.eventInfo.eventAction = "purchase avvo legal service")
          )
         order by fullVisitorId, visitId, visit_seconds ) as table_a

    join (select fullVisitorId, visitId, user_type
          from
          (SELECT fullVisitorId,
                  visitId,
                MAX(IF(hits.customDimensions.index=19,hits.customDimensions.value, NULL)) WITHIN hits as content_group,
                  MAX(IF(hits.customDimensions.index=2,hits.customDimensions.value, NULL)) WITHIN hits as user_type,
                  hits.page.hostname as hostname
         FROM [75615261.ga_sessions_%s]
               where hits.type  = "PAGE") pf
          where
               (content_group in (
                       "advisor/thank_you",
                       "checkout/new",
                       "checkout/create",
                       "advisor/index",
                       "advisor/specialties",
                       "packages/lawyers",
                       "packages/landing",
                       "packages/show",
                       "packages/index",
                       "packages/category")
               or hostname = 'programs.avvo.com')
               and user_type not like '%%professional%%'
          group by fullVisitorId, visitId, user_type) as table_b
    on table_a.fullVisitorId = table_b.fullVisitorId
    and table_a.visitId = table_b.visitId
    left join [75615261_dimensions.content_group_dim] table_c on table_a.content_group = table_c.content_group
    order by visitorID, visitStartTime ASC, event_seconds ASC
        """ % (date_string, date_string)
    return query


def distance_from_typ(user_action):
    """
    Ordered list of pages based on distance from thank you page.
    :param str user_action: the 'user action' field value in output df
    :rtype int
    :return distance from thank-you
    """
    if not isinstance(user_action, str):
        raise TypeError('Error, please make sure user action field is a str, found %s' % type(user_action))

    ordered_pages = [
        'ALS Home',
        'PA Storefront',
        'SubCat packages',
        'Product Details Page',
        'Attorney Selection',
        'Advisor Home',
        'Advisor Specialty Selection',
        'ALS SEM',
        'Check Out',
        'Check Out - Step 2',
        'Thank You'
    ]
    try:
        return ordered_pages.index(user_action)
    except ValueError:
        raise ValueError('Error, unrankable user action found: %s!' % user_action)


def run_als_landing_funnel(fbd, fed, write_output=True):
    """
    Runs the ALS Landing funnel. Loops through each day and gets data from bigquery and outputs a funnel
    :param date fbd: funnel begin date
    :param date fed: funnel end date
    :param bool write_output: True will write to files
    :return None
    """
    if not isinstance(fbd, date):
        raise TypeError("Error, must pass date object for funnel begin date")
    if not isinstance(fed, date):
        raise TypeError("Error, must pass date object for funnel end date")
    if not isinstance(write_output, bool):
        raise TypeError("Error, must pass bool for 'write_output' input")
    
    # in order to extract the data from BigQuery, we need to iterate over each day (otherwise too large)
    for result in per_delta(fbd, fed, timedelta(days=1)):
        funnel_date_str = str(result).replace('-', '')
        # create query string, pass to big query, get a dataframe back
        query = create_funnel_query(funnel_date_str)
        session_logs_df = bqr.bq_to_pandas(query=query)
        # get tuple of main output plus debug info (which sessions are converting)
        (als_landing_funnel, conversion_visitors) = create_als_landing_funnel(session_logs_df)

        # Sort output based on dist from thank you page
        als_landing_funnel['distance_from_thank_you'] = als_landing_funnel.index.get_level_values(1)
        als_landing_funnel['distance_from_thank_you'] = als_landing_funnel['distance_from_thank_you'].astype(str).apply(
            distance_from_typ)
        als_landing_funnel.sort_values(by='distance_from_thank_you', ascending=True, inplace=True)

        if write_output:
            # Write first 5000 rows to logfile for extra sanity checking
            session_logs_df.head(5000).to_csv('output/logs/session_logs_' + funnel_date_str + '.csv', index=False,
                                              mode='w', encoding='utf-8')

            print 'Writing output to file...'
            # If it's the first day, write with header, otherwise skip header and append same file
            if funnel_date_str == str(fbd).replace('-', ''):
                als_landing_funnel.to_csv(
                    'output/als_landing_funnel_' + str(fbd) + '_' + str(fed) + '.csv',
                    index=True)
                conversion_visitors.to_csv(
                    'output/error_checking/ec_summary_' + str(fbd) + '_' + str(fed) + '.csv',
                    index=False)

            else:
                als_landing_funnel.to_csv(
                    'output/als_landing_funnel_' + str(fbd) + '_' + str(fed) + '.csv',
                    index=True, header=False, mode='a')
                conversion_visitors.to_csv(
                    'output/error_checking/ec_summary_' + str(fbd) + '_' + str(fed) + '.csv',
                    index=False, header=False, mode='a')

            if path.exists('output/error_checking/ec_sessions_' + funnel_date_str + '.csv'):
                raise IOError('error checking path already exists for %s' + funnel_date_str)

            # Make sure 0 values in view/conv attribution show up as empty in csv
            session_logs_df.loc[session_logs_df.view_attribution == 0, 'view_attribution'] = None
            session_logs_df.loc[session_logs_df.conversion_attribution == 0, 'view_attribution'] = None
            # Write error checking data to daily output files
            for row_index, row_series in conversion_visitors.iterrows():
                criterion_one = session_logs_df['VisitorID'] == row_series['VisitorID']
                session_logs_df[criterion_one].to_csv('output/error_checking/ec_sessions_' + funnel_date_str + '.csv',
                                                      index=False, mode='a', encoding='utf-8')
                with open('output/error_checking/ec_sessions_' + funnel_date_str + '.csv', 'a') as f:
                    f.write('\n\n')


def main():
    run_als_landing_funnel(funnel_begin_date, funnel_end_date, write_output=True)


if __name__ == '__main__':
    main()
