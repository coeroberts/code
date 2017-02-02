#!/bin/bash

SCRIPT_PATH=$(dirname $0)
pushd $SCRIPT_PATH

clean_exit() {
    popd
    exit $1
}

usage() {
    echo ""
    echo "Usage: deployer.sh"
    echo ""
    echo "Example: deploy2gateway.sh -e test -w web-logs/web-logs-hourly-oozie"
    echo ""
    echo "     -e, --env, --environment: specify the environment to run in, e.g. test, prod"
    echo "     -w, --wf, --workflow: path to workflow (from repo root) that needs to be re-run"
    echo "     -u, --user: user that will be submitting the workflow - typically 'jobrunner' or 'jobrunner2'"
    echo "     -s, --start-time: if specified, Oozie coordinator start time will be replaced: 'now' (default) - current day and time overwrites previous value, 'today' - current day is set"
    echo "     -r, --rs, --runningSchedule: use this runningSchedule: e.g. '35 08' "
    echo "     -k: only kinit and exit"
    echo ""
}

KINIT_REQUEST=false
CUR_USER=$(whoami)
ENV=NONE
START_TIME=now
GATEWAY=NONE
WORKFLOW=NONE
RUNNING_USER=NONE
RUNNING_SCHED=NONE

COMMON_PATH=$(dirname $0)

while true; do
  case "$1" in
    -h | --help ) usage; clean_exit 0 ;;
    -k ) KINIT_REQUEST=true ; shift 1 ;;
    -e | --env | --environment ) 
        ENV="$2" ; shift 2 ;;
    -w | --wf | --workflow ) 
        WORKFLOW="$2" ; shift 2 ;;
    -u | --user ) 
        RUNNING_USER="$2" ; shift 2 ;;
    -s | --start-time ) 
        START_TIME="$2" ; shift 2 ;;
    -r | --rs | --runningSchedule ) 
        RUNNING_SCHED="$2" ; shift 2 ;;
    * ) break ;;
  esac
done


# set gateway host name
case "$ENV" in
    "prod" ) GATEWAY="cg1wow"; ;;
    "test" ) GATEWAY="cg1test"; ;;
    "NONE" ) 
        echo "-e is a required parameter"
        clean_exit 2
        ;;
    *) 
        echo $ENV '- is not a valid environment. It has to be "test" or "prod".'
        clean_exit 2
esac

# check the running user
case "$RUNNING_USER" in
    "jobrunner" ) echo "will submit as jobrunner"; ;;
    "jobrunner2" ) echo "will submit as jobrunner2"; ;;
    "NONE" ) 
        echo "-u is a required parameter"
        clean_exit 2
        ;;
    *) 
        echo $RUNNING_USER '- is not a valid user to deploy with.'
        clean_exit 2
esac

# set gateway host name
case "$START_TIME" in
    "now" ) START_TIME="now"; ;;
    "today" ) START_TIME="today"; ;;
    *) 
        echo $START_TIME '- is not a valid start_time value. It has to be "now" or "today", or not set.'
        clean_exit 2
esac

# only kinit and exit
if [ "$KINIT_REQUEST" == "true" ]; then
    echo "kinit"
    ssh $GATEWAY.prod.avvo.com "sudo su -c 'cd; ./predeploy.sh' $RUNNING_USER"
    clean_exit 0
fi

# make sure workflow is specified
case "$WORKFLOW" in
    "NONE" ) 
        echo "-w is a required parameter"
        clean_exit 2 ;;
    *) 
        echo "Deploying from $WORKFLOW"
esac

# Deploy to gateway
echo "switching to working directory: ../../$WORKFLOW"
pushd ../../$WORKFLOW
echo "deploying coordinator to gateway..."

RUNNING_SCHED_ARG="-r $RUNNING_SCHED"
if [ "$RUNNING_SCHED" == "NONE" ]; then
    RUNNING_SCHED_ARG=""
fi

./deploy2gateway.sh -e $ENV -n final -s $START_TIME $RUNNING_SCHED_ARG --skip-host-key-check
popd

# On the gateway, re-deploy as jobrunner
SSH_EXTRA_OPTIONS="-t -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o GlobalKnownHostsFile=/dev/null"

echo ""
echo "obtaining USER_HOME,  OOZIE_URL and DEPLOY_DIR"
USER_HOME=$(ssh $SSH_EXTRA_OPTIONS $GATEWAY.prod.avvo.com 'cd; pwd' | tr -d '\n' | tr -d '\r')
OOZIE_URL=$(ssh $SSH_EXTRA_OPTIONS $GATEWAY.prod.avvo.com 'echo $OOZIE_URL' | tr -d '\n' | tr -d '\r')
DEPLOY_DIR="$USER_HOME/deploy-${WORKFLOW##*/}"

echo ""
echo "USER_HOME=$USER_HOME"
echo "OOZIE_URL=$OOZIE_URL"
echo "DEPLOY_DIR=$DEPLOY_DIR"
echo ""

JOBRUNNER_COMMAND="cd $DEPLOY_DIR ; OOZIE_URL=$OOZIE_URL ./deploy2hadoop.sh -redeploy"
echo "Deploying user's command: $JOBRUNNER_COMMAND"

USER_COMMAND='sudo su - '$RUNNING_USER' -c "'"$JOBRUNNER_COMMAND"'"'
echo "Will be running the following command: $USER_COMMAND"

ssh $SSH_EXTRA_OPTIONS $GATEWAY.prod.avvo.com $USER_COMMAND

clean_exit 0

