#!/usr/bin/env python2.7

import os
import sys
import shutil
import glob
import json
import pwd
import re
import argparse
import fileinput
from datetime import datetime

project_dir = os.getcwd()
common_dir = os.path.dirname(os.path.realpath(__file__))
project_name = os.path.basename(project_dir)
dest_dir = str.format("{}/deploy-{}", project_dir, project_name)

# command-line arguments
parser = argparse.ArgumentParser()
parser.add_argument("-e", "--env", help="specify the environment (i.e. cluster) to run in, e.g. test, prod. (required field)", default=None, required=True, choices=['test', 'prod'])
parser.add_argument("-n", "--namespace", help="namespace to run in. Reserved keys: user, final. (required field)", default=None, required=True)
parser.add_argument("-s", "--start-time", help="if specified, Oozie coordinator start time will be replaced: 'now' - current day and time overwrites previous value, 'today' - current day is set (time remains unchanged)", default=None)
parser.add_argument("-r", "--running-frequency", nargs='+', help="if specified, Oozie coordinator running frequency will be overwritten to the provided one. e.g.  '05 9 * * *' ", default=None)
parser.add_argument("-x", "--additional-ext", nargs='+', help="if specified, we will copy all files with specified extensions", default=None)
parser.add_argument("--skip-host-key-check", help="if specified, host key verification will be skipped", action='store_true', default=False)
args = parser.parse_args()

environment = args.env
namespace = args.namespace
start_time = args.start_time
skip_host_key_check = args.skip_host_key_check

if args.running_frequency:
    running_frequency = ' '.join(args.running_frequency)
else:
    running_frequency = None

if os.path.exists(dest_dir):
    shutil.rmtree(dest_dir, ignore_errors=True)

os.mkdir(dest_dir)

print ("Created the deployment directory:", dest_dir)
print


def add_properties(source_dir, output_file):
    prop_file = open(source_dir + "/job.properties.json")
    prop_json = json.load(prop_file)

    for segment in prop_json:
        if (segment["environment"] == environment or segment["environment"] == "*") and \
                (segment["namespace"] == namespace or segment["namespace"] == "*"):
            properties = segment["properties"]
            output_file.write(
                str.format("# Environment: {}, Namespace: {}\n", segment["environment"], segment["namespace"]))
            for prop in properties:
                output_file.write(str.format("{}={}\n", prop["name"], prop["value"]))
            output_file.write("\n")

output = open(dest_dir + "/job.properties", "w")

output.write("# Common properties:\n\n")
add_properties(common_dir, output)
output.write("# Project properties:\n\n")
add_properties(project_dir, output)

output.close()

if start_time:
    print ("Adjusting coordinator start time")
    start_time_pattern = ''
    new_start_time = r'\1='
    if start_time == 'now':
        new_start_time = new_start_time + datetime.utcnow().strftime('%Y-%m-%dT%H:%MZ')
        start_time_pattern = r'(scheduleStartTime).*'
    elif start_time == 'today':
        new_start_time = new_start_time + datetime.now().strftime('%Y-%m-%d') + r'\2'
        start_time_pattern = r'(scheduleStartTime).*(T..:..Z)'
    else:
        raise KeyError('invalid start-time (-s) option: ' + str(start_time))

    with open(dest_dir + "/job.properties", "r") as sources:
        lines = sources.readlines()
    with open(dest_dir + "/job.properties", "w") as sources:
        for line in lines:
            sources.write(re.sub(start_time_pattern, new_start_time, line))

if running_frequency:
    print("Adjusting running frequency to: " + running_frequency + " * * *")
    new_start_time = r'\1=' + running_frequency + " * * *"
    start_time_pattern = r'(runningFrequency).*'

    with open(dest_dir + "/job.properties", "r") as sources:
        lines = sources.readlines()
    with open(dest_dir + "/job.properties", "w") as sources:
        for line in lines:
            sources.write(re.sub(start_time_pattern, new_start_time, line))


print ("Generated job.properties file.")
print

deploy2hadoopFilename = "deploy2hadoop.sh"
shutil.copy(common_dir + "/" + deploy2hadoopFilename, dest_dir)
print ("Copied deploy2hadoop.sh.")

def copy_files(src_dir, dst_dir, extension):
    for f in glob.glob(str.format('{}/*.{}', src_dir, extension)):
        if not f.endswith("deploy2gateway.sh") and not f.endswith("job.properties.json"):
            shutil.copy(f, dst_dir)
            print (f)

extensions = ["sh", "hql", "py", "xml", "conf", "csv", "R", "json"]

if args.additional_ext:
    extensions = extensions + args.additional_ext
    # Also update deploy2hadoop shell script to account for the additional extentions
    for line in fileinput.input(dest_dir + "/" + deploy2hadoopFilename, inplace=True):
        print line.replace("%ADDITIONAL_EXT%", "," + ','.join(args.additional_ext)),

print ("Copying files (" + ', '.join(extensions) + "):")
for ext in extensions:
    copy_files(project_dir, dest_dir, ext)
print


def copy_dir(src, dest, directory_name):
    src = str.format("{}/{}", src, directory_name)
    dest = str.format("{}/{}", dest, directory_name)
    if os.path.exists(src):
        shutil.copytree(src, dest)
        print (src)

print ("Copying directories:")
directories = ["lib", "setup", "updates"]
for directory in directories:
    copy_dir(project_dir, dest_dir, directory)
print

dest_setup_dir = dest_dir + "/setup"
if os.path.exists(dest_setup_dir):
    shutil.copy(common_dir + "/createHiveHBase.sh", dest_setup_dir)
    print ("Copied createHiveHBase.sh")
print

gateway = "cg1test"
if environment == "prod":
    gateway = "cg1wow"

username = pwd.getpwuid(os.getuid()).pw_name


SSH_EXTRA_OPTIONS=""
if skip_host_key_check:
    SSH_EXTRA_OPTIONS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null"

scpCommand = str.format("scp {} -r {} {}@{}.prod.avvo.com:~", SSH_EXTRA_OPTIONS, dest_dir, username, gateway)
os.system(scpCommand)

print ("Executed command:")
print (scpCommand)
print

print
print ("Done.")
