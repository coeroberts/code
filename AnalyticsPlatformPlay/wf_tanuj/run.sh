#!/bin/bash
echo "$PWD"
echo "running python"

filepath="/analytic/workflow/wf_tanuj"
filepath1="/analytic/datafile/aa"


hadoop fs -get "$filepath/tanuj_py.py" "$PWD"
echo "running python"
/usr/local/bin/python2.7 "tanuj_py.py" "$PWD"
echo "python ran"
ls "$PWD"
if [[ -e "$PWD/dummy.csv" ]]
    then echo "file exists"
    else echo " file doesn't exists"
fi
hadoop fs -rm "$filepath1/dummy/dummy.csv"
hadoop fs -put "$PWD/dummy.csv" "$filepath1/dummy"
