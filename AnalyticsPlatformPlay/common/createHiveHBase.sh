#!/bin/bash

# base name for HBase and Hive files must be provided from environment
if [ "$SETUP_TEMPLATE_NAME" == "" ]; then
    echo "Variable SETUP_TEMPLATE_NAME must be provided in environment"
    exit
fi
TEMPLATE_NAME=$SETUP_TEMPLATE_NAME

# Figure out which space to run in. Give warning if for common (final) space
if [ $# -eq 1 ] && [ $1 == "final" ]; then
    KEY_PREFIX=""
    FILE_SUFFIX="final"
    echo -e "\n== WARNING: this will create tables in the common area ('final') ==\n"
elif [ $# -eq 1 ] && [ $1 != "user" ]; then
    KEY_PREFIX="$1_"
    FILE_SUFFIX=$1
    echo -e "\n== WARNING: this will create tables in the $1 area ==\n"
else
    if [ $USER == "" ] || [ $USER == "root" ] ; then
        echo -e "No valid USER is set, exiting...\n"
        exit
    fi
    KEY_PREFIX="${USER}_"
    FILE_SUFFIX="$USER"
fi

# HBase
HBASE_SCRIPTFILE="${TEMPLATE_NAME}-hbase-tables.$FILE_SUFFIX"
if [ -f $HBASE_SCRIPTFILE ]; then
    rm $HBASE_SCRIPTFILE
fi
cp ${TEMPLATE_NAME}.hbase $HBASE_SCRIPTFILE
sed -i.bak "s/{KEY_PREFIX}/$KEY_PREFIX/g" $HBASE_SCRIPTFILE
rm ${HBASE_SCRIPTFILE}.bak

# Hive
HIVE_SCRIPTFILE="${TEMPLATE_NAME}-hive-tables.$FILE_SUFFIX"
if [ -f $HIVE_SCRIPTFILE ]; then
    rm $HIVE_SCRIPTFILE
fi
cp ${TEMPLATE_NAME}.hql $HIVE_SCRIPTFILE
sed -i.bak "s/{KEY_PREFIX}/$KEY_PREFIX/g" $HIVE_SCRIPTFILE
rm ${HIVE_SCRIPTFILE}.bak

# Confirm with user
echo -e "\nRun following scripts?\n"
echo -e "\n -----   HBase ----\n"
cat $HBASE_SCRIPTFILE
echo -e "\n -----   Hive ----\n"
cat $HIVE_SCRIPTFILE
read -p "Press 'Y' to proceed: " -n 1 -r
if [[ $REPLY =~ ^[Y]$ ]]
then
    echo " [OK] "
else
    echo -e "\nDid not confirm by entering 'Y'. Exiting..."
    echo ""
    rm $HBASE_SCRIPTFILE
    rm $HIVE_SCRIPTFILE
    exit
fi

# Confirmation received, proceed with execution

# Run HBase script
echo -e "\nCreating HBase tables..."
cat $HBASE_SCRIPTFILE | hbase shell -n
rm $HBASE_SCRIPTFILE
echo -e "\n Done creating HBase tables.\n"

# Run Hive script
echo -e "\nCreating Hive tables..."
hive -f $HIVE_SCRIPTFILE
rm $HIVE_SCRIPTFILE
echo -e "\n Done creating Hive tables.\n"
