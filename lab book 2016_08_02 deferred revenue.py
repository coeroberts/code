
# coding: utf-8

# In[1]:

import sys
import os
from datetime import datetime as dt
import impala
import numpy
import pandas as pd


# In[2]:

# To change every month: input filename here and output filename at end.

print '{:%Y-%m-%d %H:%M:%S}: {}'.format(dt.now(), "Reading.")
# df = pd.read_csv("C:\Users\croberts\Documents\projects\deferred revenue\deferred_revenue_dataset_sample.csv") 
df = pd.read_csv("C:\Users\croberts\Documents\projects\deferred revenue\deferred_revenue_dataset_2016_12_on_2017_01_03a.csv")
print '{:%Y-%m-%d %H:%M:%S}: {}'.format(dt.now(), "Done reading.")


# In[3]:

my_list = []
loop_counter = 0
print '{:%Y-%m-%d %H:%M:%S}: {}'.format(dt.now(), "Processing...")
for pid in df["processing_id"].unique():
    loop_counter = loop_counter + 1
    if loop_counter % 500 == 0: print '{:%Y-%m-%d %H:%M:%S}: {:7,}'.format(dt.now(), loop_counter)
    df1 = df[df['processing_id']==pid]
    prev_month_eff_target = 0  #?
    prev_month_liability_impressions = 0
    for month in df1["year_month_num"].sort_values():
        # print ".",
        ad_impressions = df1[df1['year_month_num']==month]["ad_impressions"].values[0]
        contract_target = df1[df1['year_month_num']==month]["target_impressions"].values[0]
        ad_sold_price = df1[df1['year_month_num']==month]["ad_sold_price"].values[0]
        over_under = df1[df1['year_month_num']==month]["over_under"].values[0]
        prev_month_over_under = df1[df1['year_month_num']==month]["prev_month_over_under"].values[0]
        trailing_3mo_over_under = df1[df1['year_month_num']==month]["trailing_3mo_over_under"].values[0]

        if prev_month_liability_impressions > 0:  # Carrying forward a deferral need
            curr_month_eff_target = max(contract_target, contract_target + prev_month_liability_impressions + -1 * over_under)
        else:
            if trailing_3mo_over_under < 0:  # Underdelivered in trailing 3mo
                curr_month_eff_target = contract_target + -1 * trailing_3mo_over_under
            else:
                curr_month_eff_target = contract_target

        if curr_month_eff_target > contract_target:
            liability_impressions = curr_month_eff_target - contract_target
        else:
            liability_impressions = 0

        if liability_impressions == 0 or contract_target == 0 or ad_sold_price < 0:
            liability_amount = 0.0
        else:
            liability_amount = (1.0 * liability_impressions / contract_target) * ad_sold_price

        my_list.append({
            "processing_id": pid,
            "ad_market_id": df1[df1['year_month_num']==month]["ad_market_id"].values[0],
            "professional_id": df1[df1['year_month_num']==month]["professional_id"].values[0],
            "customer_id": df1[df1['year_month_num']==month]["customer_id"].values[0],
            "ad_mkt_key": df1[df1['year_month_num']==month]["ad_mkt_key"].values[0],
            "ad_type": df1[df1['year_month_num']==month]["ad_type"].values[0],
            "latest_month_with_data": df1[df1['year_month_num']==month]["latest_month_with_data"].values[0],
            "active_in_latest_month": df1[df1['year_month_num']==month]["active_in_latest_month"].values[0],
            "cancelled_in_current_month": df1[df1['year_month_num']==month]["cancelled_in_current_month"].values[0],
            "cancelled_in_latest_month": df1[df1['year_month_num']==month]["cancelled_in_latest_month"].values[0],
            "include_in_latest_month_data": df1[df1['year_month_num']==month]["include_in_latest_month_data"].values[0],
            "ad_impressions": ad_impressions,
            "year_month_num": month,
            "ad_impressions": ad_impressions,
            "contract_target": contract_target,
            "ad_sold_price": ad_sold_price,
            "over_under": over_under,
            "prev_month_over_under": prev_month_over_under,
            "trailing_3mo_over_under": trailing_3mo_over_under,
            "prev_month_eff_target": prev_month_eff_target,
            "curr_month_eff_target": curr_month_eff_target,
            "liability_impressions": liability_impressions,
            "prev_month_liability_impressions": prev_month_liability_impressions,
            "liability_amount": liability_amount,
            })
        prev_month_eff_target = curr_month_eff_target  # Get set for next loop
        prev_month_liability_impressions = liability_impressions
print '{:%Y-%m-%d %H:%M:%S}: {}'.format(dt.now(), "Done processing.")


# In[4]:

print '{:%Y-%m-%d %H:%M:%S}: {}'.format(dt.now(), "Writing file.")
output_df = pd.DataFrame(my_list)
output_df.to_csv("C:\Users\croberts\Documents\projects\deferred revenue\deferred_revenue_dataset_2016_12_on_2017_01_03a_output.csv")
print '{:%Y-%m-%d %H:%M:%S}: {}'.format(dt.now(), "Done writing file.")

