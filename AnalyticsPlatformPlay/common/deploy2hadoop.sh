if [ -z "${OOZIE_URL}" ]; then
  echo OOZIE_URL is not defined
  exit 1
fi

ADDITIONAL_EXT="%ADDITIONAL_EXT%" # This can be replaced by caller, otherwise will be replaced with empty string below
if [[ $ADDITIONAL_EXT == *"ADDITIONAL_EXT"* ]]
then
  ADDITIONAL_EXT=""
fi

# Take application path from the properties file (DRY)
APP_PATH=`grep "^applicationPath" job.properties | grep -o "hdfs.*"`
APP_PATH="${APP_PATH/\$\{user.name\}/$USER}"

# Automatically kill a running coordinator if running with option "-redeploy"
COORD_NAME=`grep "^scheduleName" job.properties | grep -o "coord_.*"`
COORD_ID=`oozie jobs -jobtype coordinator -filter name=$COORD_NAME\;status=RUNNING | grep -o "[0-9][^ ]*-C"`
if [ $# -ge 1 ]; then
    if [ $1 == "-redeploy" ]; then
        if [ -z "$COORD_ID" ]; then
            echo "No coordinator is running, proceeding to deployment."
        else
            echo "Coordinator found, killing it: $COORD_ID"
            oozie job -kill $COORD_ID
        fi
    else
        echo "Unknown option"
        exit 1
    fi
else
    # Prompt to kill existing job
    if ! [ -z "$COORD_ID" ]; then
        echo "Existing coordinator found, it will need to be killed for deployment to continue."
        while true; do
            read -p "Do you want to continue [y/n]? " yn
            case $yn in
                [Yy]* ) break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done

        oozie job -kill $COORD_ID
        echo "Existing coordinator [$COORD_ID] killed"
    fi
fi

# re-deploy
EXTENSIONS=xml,conf,hql,py,sh,csv,R,json$ADDITIONAL_EXT
echo Copying files to HDFS [$EXTENSIONS]
hdfs dfs -rm -f -R $APP_PATH
hdfs dfs -mkdir $APP_PATH
hdfs dfs -mkdir $APP_PATH/lib
eval hdfs dfs -put *.{$EXTENSIONS} $APP_PATH/
hdfs dfs -put job.properties $APP_PATH/
hdfs dfs -put ./lib/*.jar $APP_PATH/lib/
hdfs dfs -ls -R $APP_PATH

oozie job -run -config job.properties -DoozieUrl=$OOZIE_URL
