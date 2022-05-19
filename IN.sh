#!/bin/bash

set +x

echo "APP NAME : $APPLICATION_NAME"
echo "APP VERSION: $PACKAGE_VERSION"
JAR_FILE="${APPLICATION_NAME}-$PACKAGE_VERSION.jar"

function SETUP_VARIABLES(){

    
	if [ "$APPLICATION_NAME" = "paco" ]; then
		export DIRECTORY_NAME="PACO"
		export APPLICATION_PID_NAME="NINA_PACO_2_ULM"
        
	elif [ "$APPLICATION_NAME" = "ulm-step-service" ]; then
		export DIRECTORY_NAME="ulm-step-service"
        export APPLICATION_PID_NAME="ULM_STEP_SERVICE"

	elif [ "$APPLICATION_NAME" = "ulmexpireservice" ]; then
		export DIRECTORY_NAME="ulm_expire_service"
        export APPLICATION_PID_NAME="ULM_EXPIRE_SERVICE_CLOUD_NATIVE"
        
	elif [ "$APPLICATION_NAME" = "ulmtriggerservice" ]; then
		export DIRECTORY_NAME="ulm_trigger_service"
        export APPLICATION_PID_NAME="ULM_TRIGGER_SERVICE_CLOUD_NATIVE"

	elif [ "$APPLICATION_NAME" = "ulmusagefee" ]; then
		export DIRECTORY_NAME="ulm_usagefee"
        export APPLICATION_PID_NAME="ULMUSAGEFEE"
        
	elif [ "$APPLICATION_NAME" = "ulm-deactivate-service" ]; then
		export DIRECTORY_NAME="ulm_deactivate_service"
        
	elif [ "$APPLICATION_NAME" = "ProcedureAdapter" ]; then
		export DIRECTORY_NAME="procedureAdapter"
        
	elif [ "$APPLICATION_NAME" = "inquiryservice" ]; then
		export DIRECTORY_NAME="inquiry-service"
        export APPLICATION_PID_NAME="INQUIRY_SERVICE_CONFIGSERVER"
        
	elif [ "$APPLICATION_NAME" = "dbthread" ]; then
		export DIRECTORY_NAME="dbthread"
        export APPLICATION_PID_NAME="NINA_DBTHREAD1A"
        
	elif [ "$APPLICATION_NAME" = "SmsAdapter" ]; then
		export DIRECTORY_NAME="smsAdapter_2_ulm"
	
	else
		printf '%s\n' "Script error. Can not identify server name!"
	fi
    
    TARGET_DIR="/global/scalable/services/ULM25/$DIRECTORY_NAME/lib"
	BACKUP_DIR="/global/scalable/services/ULM25/$DIRECTORY_NAME/lib/old"
    echo "DIR NAME : $DIRECTORY_NAME"
    
}

function DOWNLAOD_FROM_NEXUS(){

echo "========================= Downloading Packages from Nexus  ================================="

echo ""
Nexus_URL="http://nexus.vodafone.local/repository/releases/com/oksijen/inox/nina"
NEXUS_USER="test.auto.sat"
#NEXUS_PWD=""

curl -LJO -u $NEXUS_USER:'I#n6uvtvhybnikultakafyhoi' "$Nexus_URL"/"${APPLICATION_NAME}"/"$PACKAGE_VERSION"/"$JAR_FILE"

ls -l $JAR_FILE

echo ""

}

function BACKUP_PACKAGE(){

echo "========================= Backup Packages============================"
echo ""
ssh inapp@10.177.194.16 "/global/scalable/services/ULM25/jenkins_data/backup_script2.sh $APPLICATION_NAME $DIRECTORY_NAME"
if [ $? -ne 0 ]; then
	echo ""
	echo "ERROR! Backup Failed"
fi

}

function DEPLOY_PACKAGE(){

echo "========================= Deploy New Packages================================="
echo ""
echo "Copy $JAR_FILE package from workspace to target"
cd $WORKSPACE
scp -r "$JAR_FILE" inapp@10.177.194.16:$TARGET_DIR
if [ $? -eq 0 ]; then
	echo "INFO: $JAR_FILE deployed to $TARGET_DIR successfully!"
else
	echo "ERROR: $JAR_FILE deployment failed!!"
	echo ""
	echo "Redeploy jar from backup directory and start application processes"
	exit 1
fi

}

function RESTART_APPLICATION(){

echo "========================= Restart Application================================="
echo "D-Application name : $APPLICATION_PID_NAME"

ssh inapp@10.177.194.16 <<-EOF
	
	/global/scalable/services/ULM25/jenkins_data/PID.sh $DIRECTORY_NAME $APPLICATION_PID_NAME
    #awk '{ print $1}'
	#cd /global/scalable/services/ULM25/$DIRECTORY_NAME/bin
	#ps -ef | grep -v grep | grep -iE APPLICATION_NAME  | awk ‘{print $2}’  | xargs kill -9
	#ps -ef | grep $APPLICATION_PID_NAME | awk '{ print $2 }'
    #ps -ef | grep $APPLICATION_PID_NAME
	#echo "PID: $PID"
    #echo $PID | awk '{ print $1}'
	#echo "***********Starting Application $APPLICATION_PID_NAME************"
    #./run.sh
	
EOF
}

echo "================================================================================="
echo ""
if [ -z ${PACKAGE_VERSION} ]; then
	echo "ERROR: Deployment Package Version Not Provided"
	exit 1;
else
	echo "APPLICATION_NAME: "$APPLICATION_NAME
	echo "PACKAGE_VERSION: "$PACKAGE_VERSION

	echo ""
	SETUP_VARIABLES
	DOWNLAOD_FROM_NEXUS
	BACKUP_PACKAGE
	DEPLOY_PACKAGE
	RESTART_APPLICATION
fi
