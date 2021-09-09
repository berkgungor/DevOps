set +x

###PCC_WEB_IP=IP1;IP2;IP3 > PCC_WEB_IP.txt -- for prod
###PCC_DB_IP=IP1;IP2;IP3 > PCC_DB_IP.txt
###PCC_APP_IP=IP1;IP2;IP3 > PCC_APP_IP.txt


function DEPLOY_FILE_CHECKS() {
	
	echo "===================================Deploy Checks================================="
	echo ""
	echo "Checking if $PACKAGE_FOLDER folder & Deployment files exists..."
	echo ""
    cd $WORKSPACE/release_notes
    if [[ (-d "$PACKAGE_FOLDER") && (-f "$PACKAGE_FOLDER/Deployment.txt") && (-s "$PACKAGE_FOLDER/Deployment.txt") && (-f  "$PACKAGE_FOLDER/Rollback.txt") && (-s "$PACKAGE_FOLDER/Rollback.txt") ]]; then  
        echo "INFO: $PACKAGE_FOLDER folder and Files exists"
		cd $WORKSPACE/release_notes/$PACKAGE_FOLDER
		echo "$PACKAGE_FOLDER/Deployment.txt"
		echo "$PACKAGE_FOLDER/Rollback.txt"
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
	echo "Checking if Deployment.txt deployment packages exists in repository..."
	echo ""
	for package_files in `cat $WORKSPACE/release_notes/$PACKAGE_FOLDER/Deployment.txt`;
	do
		FILE_TYPE=`echo $package_files | awk -F"|" '{ print $1 }'`
		case $FILE_TYPE in
			"SQL")
				FILE_NAME=`echo $package_files | awk -F"|" '{ print $3 }'`
				cd $WORKSPACE/
				if [[ -f "$FILE_NAME" && -s "$FILE_NAME" ]]; then
					echo "$FILE_NAME exits in Bitbucket"
					echo ""
				else
					echo "$FILE_NAME does not exits in Bitbucket"
					exit 1;
				fi
				;;
			"JAR"|"UNIX")
				FILE_NAME=`echo $package_files | awk -F"|" '{ print $2 }'`
				cd $WORKSPACE/
				if [[ -f "$FILE_NAME" && -s "$FILE_NAME" ]]; then
					echo "$FILE_NAME exits in Bitbucket"
					echo ""
				else
					echo "$FILE_NAME does not exits in Bitbucket"
					exit 1;
				fi
				;;
		esac
	done
	
}

function START_SQL_DEPLOYMENT(){

	echo ""
	cd $WORKSPACE
	echo "Starting Deployment -- "$SOURCE_FILE
	echo ""
	#sed -i '1s/^/SET DEFINE OFF;/' $SOURCE_FILE
	if [[ "$USERNAME" -eq "TURECOMP" ]]; then
		DB_Password="$TC_DB_PASS"
        echo "INFO: DB USERNAME : TURECOMP"
		
	elif [ "$USERNAME" == "COLLECTIONS" ]; then
    	DB_Password="$CO_DB_PASS"
        echo "INFO: DB USERNAME : COLLECTIONS"
		
	fi
	echo ""
    DB_SID="srv_edun"    
	DB_HostName="172.31.60.134"
	DB_Port="1521"
	#SQL_STR="sqlplus "${USERNAME}"/"${DB_Password}"@${DB_HostName}:${DB_Port}/${DB_SID}"
	#SQL_OUTPUT="$SQL_STR"@"$SOURCE_FILE"

    SQL_OUTPUT=`sqlplus -s ${USERNAME}/${DB_Password}@${DB_HostName}:${DB_Port}/${DB_SID} @"$WORKSPACE/$SOURCE_FILE"`
	
	echo "SQL_OUTPUT: $SQL_OUTPUT"
	echo ""
	if [ `echo "$SQL_OUTPUT" | grep -Ei "ERROR|ORA-[0-9]|SP2-[0-9]|O/S Message|unable to open file" | wc -l` -eq 0 ]; then
		echo "INFO: Deployment Completed -- "$SOURCE_FILE
		echo ""
		
	else
		echo "ERROR: Deployment Failed -- "$SOURCE_FILE
		START_ROLL_BACK
		echo ""
		exit 1;
	fi

}

function START_SQL_ROLLBACK(){

	echo ""
	cd $WORKSPACE
	echo "Starting Deployment -- "$SOURCE_FILE
	echo ""
	#sed -i '1s/^/SET DEFINE OFF;/' $SOURCE_FILE
	if [[ "$USERNAME" -eq "TURECOMP" ]]; then
		DB_Password="$TC_DB_PASS"
        echo "INFO: DB USERNAME : TURECOMP"
		
	elif [ "$USERNAME" == "COLLECTIONS" ]; then
    	DB_Password="$CO_DB_PASS"
        echo "INFO: DB USERNAME : COLLECTIONS"
		
	fi
	echo ""
    DB_SID="srv_edun"    
	DB_HostName="172.31.60.134"
	DB_Port="1521"
	echo ""
    SQL_OUTPUT=`sqlplus -s ${USERNAME}/${DB_Password}@${DB_HostName}:${DB_Port}/${DB_SID} @"$WORKSPACE/$SOURCE_FILE"`
	
	echo "SQL_OUTPUT: $SQL_OUTPUT"
	echo ""
	if [ `echo "$SQL_OUTPUT" | grep -Ei "ERROR|ORA-[0-9]|SP2-[0-9]|O/S Message|unable to open file" | wc -l` -eq 0 ]; then
		echo "INFO: Rollback Completed -- "$SOURCE_FILE
		echo ""
		
	else
		echo "ERROR: Rollback Failed -- "$SOURCE_FILE
		echo ""
		exit 1;
	fi

}


function START_UNIX_JAR_DEPLOYMENT(){

	cd $WORKSPACE
	ssh userpcc@172.31.60.99 "ls -l $TARGET_DIR && [ -d $TARGET_DIR ] && echo "$TARGET_DIR directory exists""
	if [ $? -eq 0 ]; then
		echo "INFO: $TARGET_DIR exist on remote server!"
	else
		echo "ERROR: $TARGET_DIR does not exist!!"
		START_ROLL_BACK
		exit 1
	fi

	echo "Copy unix file from workspace to target"
	scp -r $SOURCE_FILE userpcc@172.31.60.99:$TARGET_DIR    
	if [ $? -eq 0 ]; then
		echo "INFO: $SOURCE_FILE deployed successfully!"
	else
		echo "ERROR: $SOURCE_FILE deployment failed!!"
		START_ROLL_BACK
		exit 1
	fi

}

function START_OPERATION_DEPLOYMENT(){

	ssh userpcc@172.31.60.99 "$OPERATION_COMMAND"
	if [ $? -eq 0 ]; then
		echo "INFO: Operation is successful"
		echo ""
	else
		echo "ERROR: Operation is failed"
		START_ROLL_BACK
		exit 1
	fi

}


function START_DEPLOYMENT() {

	IFS=$'\n'
	for LINES in `cat $WORKSPACE/release_notes/$PACKAGE_FOLDER/Deployment.txt`;
	do
		DEPLOYMENT_TYPE=`echo "$LINES" | awk -F"|" '{print $1}'`
		case $DEPLOYMENT_TYPE in
			"SQL")
				echo "================================SQL Deploy Start====================================="
				echo "DEPLOYMENT_TYPE: $DEPLOYMENT_TYPE for $LINES"
				USERNAME=`echo "$LINES" | awk -F"|" '{print $2}'`
				SOURCE_FILE=`echo "$LINES" | awk -F"|" '{print $3}'`
				START_SQL_DEPLOYMENT
				;;
			"UNIX"|"JAR")
				echo "================================UNIX & JAR Deploy Start====================================="	
				echo "DEPLOYMENT_TYPE: $DEPLOYMENT_TYPE for $LINES"
				SOURCE_FILE=`echo "$LINES" | awk -F"|" '{print $2}'`
				TARGET_DIR=`echo "$LINES" | awk -F"|" '{print $3}'`
				TARGET_SYSTEM=`echo "$LINES" | awk -F"|" '{print $4}'`
				START_UNIX_JAR_DEPLOYMENT
				;;
			"OPERATIONS")
				echo "================================OPERATION Deploy Start====================================="
				echo "DEPLOYMENT_TYPE: $DEPLOYMENT_TYPE for "$LINES""
				OPERATION_COMMAND=`echo "$LINES" | awk -F"|" '{print $2}'`
				START_OPERATION_DEPLOYMENT
				;;
			*)
				echo "ERROR: Unknown deployment type : $DEPLOYMENT_TYPE"
				exit 1
				;;
		esac
	done

}

function START_ROLL_BACK(){

	echo "================================ROLLBACK Start====================================="
	IFS=$'\n'
	for RB_LINES in `cat $WORKSPACE/release_notes/$PACKAGE_FOLDER/Rollback.txt`;
	do
		ROLLBACK_TYPE=`echo "$RB_LINES" | awk -F"|" '{print $1}'`
		case $ROLLBACK_TYPE in
			"SQL")
				echo "ROLLBACK_TYPE: $ROLLBACK_TYPE for $RB_LINES"
				USERNAME=`echo "$RB_LINES" | awk -F"|" '{print $2}'`
				SOURCE_FILE=`echo "$RB_LINES" | awk -F"|" '{print $3}'`
				START_SQL_ROLLBACK
				;;
			"UNIX"|"JAR")
            	SOURCE_FILE=`echo "$RB_LINES" | awk -F"|" '{print $2}'`
				TARGET_DIR=`echo "$RB_LINES" | awk -F"|" '{print $3}' | sed 's/\/*$//g'`
				TARGET_SYSTEM=`echo "$RB_LINES" | awk -F"|" '{print $4}'`
				FILE_NAME=`basename $SOURCE_FILE` && echo "FILENAME : $FILE_NAME"
				##START_UNIX_ROLLBACK
				ssh userpcc@172.31.60.99 <<-EOF
					BACKUP_DIR=~/jenkins_backup
					cp -p ~/jenkins_backup/$FILE_NAME "$TARGET_DIR/$FILE_PATH"
					if [[ $? -eq 0 ]]; then
						echo ""
						echo "Rollback completed for $FILE_NAME"
					else
						echo " Rollback failed!!!"
						exit 1
					fi
				EOF
				;;
			"OPERATIONS")
				echo "ROLLBACK_TYPE: $ROLLBACK_TYPE for $RB_LINES"
				OPERATION_COMMAND=`echo "$RB_LINES" | awk -F"|" '{print $2}'`
				ssh userpcc@172.31.60.99 "$OPERATION_COMMAND"
				if [ $? -eq 0 ]; then
					echo "INFO: Operation rollback is successful"
					echo ""
				else
					echo "ERROR: Operation rollback is failed!"
					exit 1
				fi
				;;
			*)
				echo "ERROR: Unknown deployment type in Rollback.txt : $ROLLBACK_TYPE"
				exit 1
				;;
		esac
	done

}

function START_BACKUP(){

 	for LINES in `cat $WORKSPACE/release_notes/$PACKAGE_FOLDER/Deployment.txt`;
	do
    	DEPLOYMENT_TYPE=`echo "$LINES" | awk -F"|" '{print $1}'`
		case $DEPLOYMENT_TYPE in
			"UNIX")
				echo "================================UNIX Backup===================================="
        		echo ""
                MYFILE=`echo "$LINES" | awk -F"|" '{print $2}'`
				FILE_NAME=`basename $MYFILE` && echo "FILENAME : $FILE_NAME"
				BACKUP_SOURCE_PATH=`echo "$LINES" | awk -F"|" '{print $3}' | sed 's/\/*$//g'`
        		ssh userpcc@172.31.60.99 <<-EOF
                [[ ! -d ~/jenkins_backup/$PACKAGE_FOLDER ]] && mkdir ~/jenkins_backup/$PACKAGE_FOLDER
        		if [[ -f "$BACKUP_SOURCE_PATH/$FILE_NAME" ]]; then
					echo ""
					echo "Removing old backup files for $FILE_NAME"
					[[ -f "~/jenkins_backup/$PACKAGE_FOLDER/$FILE_NAME" ]] && rm -r ~/jenkins_backup/$PACKAGE_FOLDER/$FILE_NAME
					echo ""
					echo "Package exist, starting backup"
					cp "$BACKUP_SOURCE_PATH/$FILE_NAME" ~/jenkins_backup/$PACKAGE_FOLDER
				else
           			echo "New package, backup will be skipped"
				fi
				EOF
                ;;
            *)
            	        
		esac        
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
	echo "Bitbucket Branch -- "$GIT_BRANCH_NAME
	echo ""
	DEPLOY_FILE_CHECKS
	VERIFY_DEPLOY_PACKAGE_EXISTS
    START_BACKUP
	START_DEPLOYMENT
    
fi
