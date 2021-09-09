#!/bin/bash

set +x

## preprod - 42
## username - srvc.cicd.fu
## hotname - p17edp001


function DEPLOY_FILE_CHECKS() {
	
	echo "===================================Deploy Checks================================="
	echo ""
	echo "Checking if $PACKAGE_FOLDER folder & Deployment files exists..."
	echo ""
    cd $WORKSPACE/
    ls -l
    if [[ -d "$PACKAGE_FOLDER" ]] && [[ -f "$PACKAGE_FOLDER"/p17_RN.txt && -s "$PACKAGE_FOLDER"/p17_RN.txt ]]; then
    	echo "INFO: $PACKAGE_FOLDER folder and Files exists"
		cd $WORKSPACE/$PACKAGE_FOLDER/
		sed -i '/^$/d' p17_RN.txt
		echo ""
	else
    	echo "ERROR: $PACKAGE_FOLDER folder or Deployment Files Not Found in Repository!!!"
		echo ""
        exit 1;
	fi;

}

function VERIFY_DEPLOY_PACKAGE_EXISTS() {
	
	echo "===================================Deploy Package Checks=========================="
	echo ""
	echo "Checking if RN17.txt deployment packages exists in repository..."
	echo ""
	for package_files in `cat $WORKSPACE/$PACKAGE_FOLDER/p17_RN.txt`;
	do
    package_files=`echo $package_files | awk -F"|" '{ print $1 }'`
		cd $WORKSPACE/
    	echo "$WORKSPACE/$package_files"
		if [[ -f "$package_files" && -s "$package_files" ]]; then
			echo "$package_files exits in Bitbucket"
			echo ""
		else
			echo "$package_files does not exits in Bitbucket"
			exit 1;
		fi
	done
	
}

function START_BACKUP(){

	cd $WORKSPACE/$PACKAGE_FOLDER
	for DAG in `cat $WORKSPACE/$PACKAGE_FOLDER/p17_RN.txt`;
    do 
		echo "================================Backup Start===================================="
		echo ""
		SOURCE_FILE_PATH=`echo "$DAG" | awk -F"|" '{print $1}'`
		FILE_NAME=`basename $SOURCE_FILE_PATH` && echo "FILE_NAME: $FILE_NAME"
		BACKUP_SOURCE_PATH=`echo "$DAG" | awk -F"|" '{print $2}' | sed 's/\/*$//g'` && echo "BACKUP_SOURCE_PATH: $BACKUP_SOURCE_PATH"
		ssh srvc.cicd.fu@10.86.67.22 /bin/bash <<-EOF
		. ~/.bash_profile
		[[ ! -d /home/srvc.cicd.fu/jenkins_backup/$PACKAGE_FOLDER ]] && mkdir /home/srvc.cicd.fu/jenkins_backup/$PACKAGE_FOLDER
		if [[ -f "$BACKUP_SOURCE_PATH/$FILE_NAME" ]]; then
			echo ""
			echo "Removing old backup files for $FILE_NAME"
			[ -f /home/srvc.cicd.fu/jenkins_backup/$PACKAGE_FOLDER/$FILE_NAME ] && rm -rf /home/srvc.cicd.fu/jenkins_backup/$PACKAGE_FOLDER/$FILE_NAME
			echo ""
			echo "Package exist, starting backup"
			cp -p "$BACKUP_SOURCE_PATH/$FILE_NAME" /home/srvc.cicd.fu/jenkins_backup/$PACKAGE_FOLDER
		else
			echo "New package, backup will be skipped"
			echo ""
		fi;
		EOF
	done

}

function START_ROLLBACK(){

	cd $WORKSPACE/$PACKAGE_FOLDER
	for DAG in `cat $WORKSPACE/$PACKAGE_FOLDER/p17_RN.txt`;
    do 
		echo "================================Rollback Start===================================="
        echo ""
		SOURCE_FILE_PATH=`echo "$DAG" | awk -F"|" '{print $1}'`
		FILE_NAME=`basename $SOURCE_FILE_PATH` && echo "FILE_NAME: $FILE_NAME"
        FILE_PATH=`echo "$DAG" | awk -F"|" '{print $2}'` && echo "FILE_PATH: $FILE_PATH"
        ssh srvc.cicd.fu@10.86.67.22 /bin/bash <<-EOF
		if [[ -f "/home/srvc.cicd.fu/jenkins_backup/$PACKAGE_FOLDER/$FILE_NAME" ]]; then
			echo "Start Rollback..."
			cp -p "/home/srvc.cicd.fu/jenkins_backup/$PACKAGE_FOLDER/$FILE_NAME" "$FILE_PATH"
			if [[ $? -eq 0 ]]; then
        		echo ""
        		echo "Rollback completed"
			else
				echo "Rollback failed"
				exit 1;
			fi;
		else
			echo "Rollback file is not found. Rollback Skipped"
			echo ""
		fi
		EOF
	done

}

function START_DEPLOYMENT() {
	cd $WORKSPACE/$PACKAGE_FOLDER
	for DAG in `cat $WORKSPACE/$PACKAGE_FOLDER/p17_RN.txt`;
    do 
		echo "================================Deploy Start===================================="
        echo ""
        cd $WORKSPACE
        SOURCE_FILE=`echo "$DAG" | awk -F"|" '{print $1}'` && echo "SOURCE_FILE: $SOURCE_FILE"
		TARGET_DIR=`echo "$DAG" | awk -F"|" '{print $2}'` && echo "TARGET_DIR: $TARGET_DIR"
        scp -r $SOURCE_FILE srvc.cicd.fu@10.86.67.22:$TARGET_DIR
		if [[ $? -eq 0 ]]; then
        	echo ""
        	echo "$SOURCE_FILE deployment completed"
        
		else
			echo "$SOURCE_FILE deployment failed. Starting Rollback..."
			echo ""
			START_ROLLBACK
			exit 1;
            
		fi
        
	done
}



echo "================================================================================="
echo ""
if [ -z ${PACKAGE_FOLDER} ]; then
	echo "ERROR: Deployment Package Not Provided"
	exit 1;
else
	echo ""
	echo "Deployment Package Provided -- "$PACKAGE_FOLDER
	echo ""
	DEPLOY_FILE_CHECKS
	VERIFY_DEPLOY_PACKAGE_EXISTS
	START_BACKUP
	START_DEPLOYMENT  
fi
