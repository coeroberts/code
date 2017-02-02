from impala.dbapi import connect
from impala.util import as_pandas
from pandas.io.gbq import read_gbq
import time
import os
import csv
from urllib2 import urlopen, Request
import subprocess
import pandas as pd

"""Fix List
    2. need to add in read from EDW as well.
    3. fix more bull shit
"""


def create_csv_name(metric):
    output_file_location = '%s.csv' % metric
    return output_file_location


def write_data_to_imp(metric_name, metric_df):
    """
    Connects to Avvo production cluster and writes dataframe
    :param str query_string: an impala query to be run
    :rtype pd.DataFrame
    :return: dataframe with results
    Need to add in some error handling
    if not isinstance(query_string, str):
        raise TypeError('query_string must be a string!')
    """
    conn = connect(host='dn1wow.prod.avvo.com', port=21050, database='tmp_data_dm', auth_mechanism="GSSAPI",
                   kerberos_service_name='impala')
    print 'Connected to impala...Writing temp data...\n'
    cur = conn.cursor()
    drop_table = 'drop table if exists rd_%s_temp' % metric_name
    cur.execute(drop_table)
    # This opens the csv file that was written by bigquery
    csv_file = '%s.csv' % metric_name
    csv_handle = open(csv_file, 'r')
    csv_data = csv.reader(csv_handle)
    ncol = len(next(csv_data))
    # counts the number of columns to use later

    # goes to the top of the csv
    csv_handle.seek(0)
    # grabs the header data
    headers = csv_data.next()
    print 'These are the headers...'
    print headers
    print '\n'
    print 'These are the datatypes'
    # this creates the datatypes from the dataframe that is passed aka metric_df
    x = []
    # NEED TO FIX THIS.  THE LOOP IS FUCKED
    for dtypes in metric_df.dtypes:
        if str(dtypes) == 'object':
            x.append('string')
        elif str(dtypes) == 'int64':
            x.append('bigint')
        elif str(dtypes) == 'float64':
            x.append('float')
        else:
            x.append(str(dtypes))
    print x
    print '\n'
    data_type = x

    head_data = zip(headers, data_type)

    s = 'CREATE TABLE rd_%s_temp (' % metric_name
    x = ''
    # this takes the tuples from the header data and data types concats the first part of the create table statement
    for a, b in head_data:
        x += a + ' ' + b + ' , '
    s += x
    s = s.rstrip(', ') + ');'
    print s
    create_table = s
    cur.execute(create_table)

    csv_handle.seek(0)

    s = 'INSERT INTO rd_%s_temp (' % metric_name
    x = ''
    # this takes the header list and translates it into the INSERT query
    for a in headers:
        x += a + ' , '
    s += x
    s = s.rstrip(', ') + ') VALUES('
    # this code then will dynamically adjust the insert query to take more or fewer inputs.  ncol + ?
    t = ncol * '?,'
    s = s + t.rstrip(',') + ');'

    print s

    time.sleep(3)

    print metric_df.columns.values

    for i, e in enumerate(metric_df.columns.values):
            if e == 'string':
                index = i
                metric_df[index] = metric_df[index].map(str)
            elif e == 'float':
                index = i
                metric_df[index] = metric_df[index].map(float)
            elif e == 'bigint':
                index = i
                metric_df[index] = metric_df[index].map(int)

    y = metric_df

    metric_df = metric_df.where(pd.notnull(y), None)

    print metric_df

    tuples = [tuple(x) for x in metric_df.values]
    print tuples
    #
    print 'printing datatypes'
    print data_type
    index = []
    for i, e in enumerate(data_type):
        if e == 'string':
            index.append(i)
            print index

    for x, y in enumerate(tuples):
        y = list(y)
        for z, item in enumerate(y):
            if item is None:
                continue
            if z in index:
                if ':' in item:
                    g = item.replace(':', '-')
                    y[z] = g
                    y = tuple(y)
                elif '?' in item:
                    print item
                    g = item.replace('?', '')
                    y[z] = g
                    y = tuple(y)
        tuples[x] = y

    print 'printing datatype'
    print data_type

    print 'printing tuples'
    print tuples

    query = s
    cur.executemany(query, tuples)
    check_query = "select * from rd_%s_temp order by 1" % metric_name
    cur.execute(check_query)
    impala_df = as_pandas(cur)
    conn.close()
    return impala_df


def update_edw_sql(metric_name, metric_df):
    """This part is used to update the tables in EDW with updated data"""
    conn = connect(host='dn1wow.prod.avvo.com', port=21050, database='tmp_data_dm', auth_mechanism="GSSAPI",
                   kerberos_service_name='impala')
    print 'Connected to impala...Updating EDW...'
    cur = conn.cursor()

    # This opens the csv file that was written by bigquery
    csv_file = '%s.csv' % metric_name
    csv_handle = open(csv_file, 'r')
    csv_data = csv.reader(csv_handle)
    ncol = len(next(csv_data))
    # counts the number of columns to use later

    # goes to the top of the csv
    csv_handle.seek(0)
    # grabs the header data
    headers = csv_data.next()
    print 'These are the datatypes'
    x = []
    for dtypes in metric_df.dtypes:
        if str(dtypes) == 'object':
            x.append('string')
        elif str(dtypes) == 'int64':
            x.append('bigint')
        elif str(dtypes) == 'float64':
            print x
            x.append('float')
        else:
            x.append(str(dtypes))
    print x
    data_type = x
    head_data = zip(headers, data_type)
    # this initiates the create table if not exists statement
    s = 'CREATE TABLE if not exists rd_%s (' % metric_name
    x = ''
    # this takes the tuples from the header data and data types concats the first part of the create table statement
    for a, b in head_data:
        x += a + ' ' + b + ' , '
    s += x
    s = s.rstrip(', ') + ');'
    print s
    create_table = s
    cur.execute(create_table)

    # This needs to be fixed
    matching = [s for s in headers if 'date' in s]
    date_column = matching[0]

    # This needs to be fixed, this is erroring out, needs to be changed to read the data from the DF------------------
    query_string = "with new_data as (select * from rd_%s where \
                    %s not in (select %s from rd_%s_temp)) \
                    insert into rd_%s_temp select * from new_data order by %s" % (metric_name, date_column
                    , date_column, metric_name, metric_name, date_column)

    cur.execute(query_string)
    time.sleep(2)
    replace_query = "with new_data as (select * from rd_%s_temp) \
                    insert overwrite rd_%s select * from new_data order by %s" % (metric_name, metric_name,
                    date_column)
    cur.execute(replace_query)
    conn.close()
    print 'EDW table updated....'


def bq_to_pandas(query, index_col=None, col_order=None, k='auth/edw_bigdata_dlv.json'):
    """
    :param str query: SQL-Like Query to return data values
    :param int index_col: Name of result column to use for index in results DataFrame
    :param list(str) col_order: List of BigQuery column names in the desired order for results DataFrame
    :param str k: path to private_key.
    :rtype pd.DataFrame
    :return: dataframe with results
    """
    project_id = 'seventh-circle-461'
    df = read_gbq(query, project_id=project_id, index_col=index_col, col_order=col_order, reauth=False, verbose=True,
                  private_key=k)
    print df
    return df


def open_sql_file(metric_name, sep_folder, secondary_parsing):
    # this will open the bi datamart queries from their file location on the machine.
    # this can be used as a backup if git is down.
    sql_dir = os.path.dirname(os.path.realpath('__file__'))
    if metric_name in sep_folder:
        metric_sql = '../BI_DatamartQueries/Monitoring/%s.sql' % metric_name
    elif metric_name in secondary_parsing:
        metric_sql = '../BI_DatamartQueries/secondary_parsing/%s.sql' % metric_name
    else: metric_sql = '../BI_DatamartQueries/%s.sql' % metric_name
    print metric_sql
    y = os.path.join(sql_dir, metric_sql)
    f = open(y, 'r')
    query_string = f.read()
    f.close()
    return query_string


def del_csv_file(file_name):
    print '\n'
    """need to add in passing a variable so it can handle other stuff"""
    file_name_full = "%s.csv" % file_name
    if os.path.isfile(file_name_full):
        os.remove(file_name_full)
        print '%s removed' % file_name_full
    else:
        print 'Next step...\n'


def pull_from_git(metric_name, sep_folder, secondary_parsing):
    # pulls git token from local file, update this list as metrics get added
    if metric_name in sep_folder:
        r = "https://raw.githubusercontent.com/avvo/analytics/master/BI_DatamartQueries/Monitoring/"
    elif metric_name in secondary_parsing:
        r = "https://raw.githubusercontent.com/avvo/analytics/master/BI_DatamartQueries/secondary_parsing/"
    else:
        r = "https://raw.githubusercontent.com/avvo/analytics/master/BI_DatamartQueries/"
    key_path = 'auth/key.txt'
    y = open(key_path, 'r')
    token = y.read()
    # need to add the subfolder folder.  I'm thinking, if exists do this, else go to this subfolder
    d = r + '%s.sql' % metric_name
    git_url = d
    print git_url
    request = Request(git_url)
    request.add_header('Authorization', 'token %s' % token)
    # goes to git raw file and downloads it
    response = urlopen(request)
    sql_file = response.read()
    # This next part saves the sql file for record keeping purposes.  deletes the old file and replaces it.
    file_name_full = "%s.sql" % metric_name
    if os.path.isfile(file_name_full):
        os.remove(file_name_full)
        print '%s removed...saving new sql file...\n' % file_name_full
    else:
        print 'saving sql file...\n'
    f = open(file_name_full, "w")
    tofile = sql_file
    f.write(tofile)
    f.close()
    # http://stackoverflow.com/questions/7181263/kinit-using-python-subprocess
    return sql_file


def kinit_process(userid):
    realm = 'CORP.AVVO.COM'
    key_path = 'auth/kinit_pass.txt'
    y = open(key_path, 'r')
    password = y.read()
    kinit = '/usr/bin/kinit'
    kinit_args = [kinit, '%s@%s' % (userid, realm)]
    kinit = subprocess.Popen(kinit_args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    kinit.stdin.write('%s\n' % password)
    kinit.wait()


def impala_run_and_upload(query_string, metric_name):
    """
    Connects to Avvo production cluster and retrieves dataframe
    :param str query_string: an impala query to be run
    :rtype pd.DataFrame
    :return: dataframe with results
    """
    if not isinstance(query_string, str):
        raise TypeError('query_string must be a string!')
    conn = connect(host='dn1wow.prod.avvo.com', port=21050, database='tmp_data_dm', auth_mechanism="GSSAPI",
                   kerberos_service_name='impala')
    cur = conn.cursor()
    cur.execute(query_string)
    output_df = as_pandas(cur)

    drop_table = 'drop table if exists rd_%s_temp' % metric_name
    cur.execute(drop_table)

    # for finding the date column
    headers = output_df.head()
    matching = [s for s in headers if 'date' in s]
    date_column = matching[0]

    print 'creating %s temp table \n' % metric_name
    write_query_string = "create table rd_%s_temp as %s;" % (metric_name, query_string)
    cur.execute(write_query_string)

    time.sleep(2)
    # create the main table if it doesnt exist
    print 'creating %s table \n' % metric_name
    create_table = 'CREATE TABLE if not exists rd_%s as ( select * from rd_%s_temp order by 1)' \
                   % (metric_name, metric_name)
    cur.execute(create_table)

    time.sleep(2)
    print 'updating %s table \n' % metric_name
    query_string = "with new_data as (select * from rd_%s where \
                    %s not in (select %s from rd_%s_temp)) \
                    insert into rd_%s_temp select * from new_data order by %s" % (metric_name, date_column
                    , date_column, metric_name, metric_name, date_column)

    cur.execute(query_string)
    time.sleep(2)
    replace_query = "with new_data as (select * from rd_%s_temp) \
                    insert overwrite rd_%s select * from new_data order by %s" % (metric_name, metric_name,
                    date_column)
    cur.execute(replace_query)

    conn.close()
    return output_df


def main():

    start_time = time.time()

    print '\n\n'
    print 'Start time -- %s' % time.asctime(time.localtime(start_time))
    # run kinit
    userid = 'dluuvan'
    kinit_process(userid)

    # i use this one for normal job runs
    metric_list = ['core_traffic_by_org_traf','ad_clicks_per_pageviews', 'ads_shown_per_pageviews'
            , 'channel_traffic', 'service_transactions', 'messages_submitted_count'
            , 'questions_asked', 'reviews_written', 'core_traffic', 'ad_events', 'content_group_pageviews'
            , 'proxies_by_user', 'ad_events_full_join', 'messages_submitted_full_join', 'questions_asked_full_join'
            , 'reviews_submitted_full_join', 'north_star_index', 'service_transaction_full_join']

    # i use this one for adhoc runs
    # metric_list = ['north_star_index']

    for metric_name in metric_list:
        metric_start_time = time.time()
        del_csv_file(metric_name)

        # run metric
        print 'Running %s...\n' % metric_name

        # This is for the metrics in the secondary folder
        sep_folder = ['ad_clicks_per_pageviews', 'ads_shown_per_pageviews', 'core_traffic_by_org_traf']

        secondary_parsing = ['ad_events_full_join', 'messages_submitted_full_join', 'questions_asked_full_join'
            , 'reviews_submitted_full_join', 'north_star_index', 'service_transaction_full_join']

        # old way before git sql pull, can use for adhoc
        # query_string = open_sql_file(metric_name, sep_folder, secondary_parsing)

        # new way pulls directly from git
        query_string = pull_from_git(metric_name, sep_folder, secondary_parsing)

        if metric_name in secondary_parsing:
            impala_run_and_upload(query_string, metric_name)
        else:
            metric_df = bq_to_pandas(query_string)

            print metric_df.columns
            print '\n'
            print metric_df.head(3)
            print '\n'
            print metric_df.dtypes

            output_file_location = create_csv_name(metric_name)

            if os.path.exists(output_file_location):
                raise IOError('Path already exists for %s' + output_file_location)

            metric_df.to_csv(output_file_location, index=False, encoding='utf-8')

            print 'Writing to Impala...\n'
            write_data_to_imp(metric_name, metric_df)
            print 'Done...\n'

            print 'Updating EDW....\n'
            update_edw_sql(metric_name, metric_df)

            # Take a quick break
            time.sleep(2)

            print 'Deleting csv...\n'
            del_csv_file(metric_name)

        metric_end_time = time.time()
        print 'Metric end time -- %s\n' % time.asctime(time.localtime(metric_end_time))

        metric_run_time = (metric_end_time - metric_start_time) / 60

        print 'Metric run time in minutes -- %s\n' % metric_run_time

        print 'Done...\n'

    # Take a quick break
    time.sleep(2)

    end_time = time.time()

    total_time = round(((end_time - start_time) / 60), 2)

    print 'Done!!!! Total run time in minutes --- %s\n' % total_time

if __name__ == '__main__':
    main()
