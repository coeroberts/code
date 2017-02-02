
# coding: utf-8

# In[1]:

import sys
import os
import impala
import numpy
import pandas as pd


# In[ ]:

sys.version_info


# In[ ]:

sys.executable


# In[ ]:

# # This is the version that should work but has library problems.
# from impala.dbapi import connect
# from impala.util import as_pandas

# def get_data_from_impala(query_string):
#     if not isinstance(query_string, str):
#         raise TypeError('query_string must be a string!')
#     conn = connect(host='dn1wow.prod.avvo.com', port=21050, database='dm', use_kerberos=True,
#                    kerberos_service_name='impala')
#     cur = conn.cursor()
#     cur.execute(query_string)
#     output_df = as_pandas(cur)
#     conn.close()
#     return output_df


# In[3]:

# This is the hack to read from a csv instead.
def get_data_from_impala(query_string):
    if not isinstance(query_string, str):
        raise TypeError('query_string must be a string!')
    output_df = pd.read_csv("C:\Users\croberts\Documents\projects\deferred revenue\deferred_revenue_dataset_sample.csv")
    return output_df


# In[6]:

query = "select * from tmp_data_dm.coe_deferred_revenue_dataset_1"
df = get_data_from_impala(query)


# In[6]:

df


# In[7]:

groups = df.groupby("processing_id")
groups.groups


# In[ ]:

# print(df[ df['processing_id'] == '5241-820246' ])
# keys = groups.groups.keys()
# for key in keys:
#     print key
#     print(df[df['processing_id']==key])
#     print(df[df['processing_id']==key,'year_month_num'])


# In[ ]:

df2 = df[df['processing_id']=='5241-820246']
# df2[:,'year_month_num']
df2


# In[ ]:

# This takes a single customer's rows and loops through them in order of month (ascending).
# There's likely a more idiomatic way to do this, but f*ck stackoverflow.
for month in df2["year_month_num"].sort_values():
    print("Month: {}".format(month))
#     print("Row: {}".format(df2[df2['year_month_num']==month,c("ad_type","ad_sold_price")]))


# In[ ]:

# df2[df2['year_month_num']==month].info()
print("Row filter: {}\n".format(df2[df2['year_month_num']==month]))
print("Column Filter: {}\n".format(df2[["ad_mkt_key","year_month_num"]]))
print("Both: {}".format(df2[df2['year_month_num']==month][["ad_mkt_key","year_month_num"]]))


# In[ ]:

# Seems a convoluted way to get to the single scalar value.
df1["over_under"][df1['year_month_num']==month].values[0]


# In[ ]:

print("pid, ad_market_id, professional_id, month, over_under")
for pid in df["processing_id"].unique():
    df1 = df[df['processing_id']==pid]
#     print df1
    for month in df1["year_month_num"].sort_values():
        print("{},{},{},{},{}".format(pid
                               ,df1[df1['year_month_num']==month]["ad_market_id"].values[0]
                               ,df1[df1['year_month_num']==month]["professional_id"].values[0]
                               ,month
                               ,df1[df1['year_month_num']==month]["over_under"].values[0]))


# In[1]:

print "\n", loop_counter++


# 
