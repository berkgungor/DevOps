set +x

function update_variable() {
		
	if [ "$TARGET_SERVER" = "DTMF_Gokhan_Mobile" ]; then
		export TARGET_FOLDER="deployment_dtmf_gokhan"
		export APPLICATION_NAME="IVR_EngelliNeredeyim_Solution_Gokhan"

	
	elif [ "$TARGET_SERVER" = "DTMF_Oguz_Mobile" ]; then
		export TARGET_FOLDER="deployment_dtmf_oguz"
		export APPLICATION_NAME="IVR_EngelliNeredeyim_Solution"

	
	else
		printf '%s\n' "Script error. Can not identify server name!"
	fi

}

function backup_server_package() {

	# Backup

	DATE=$(date +%Y%m%d_%H%M%S)

	ssh oracle@172.31.60.239 /bin/bash <<-EOF

	echo "*******Backup Started for EngelliNeredeyim.war file ***********"

	cp -r /Products/deployments/$TARGET_FOLDER/EngelliNeredeyim.war /Products/deployments/$TARGET_FOLDER/packages_backup/EngelliNeredeyim.war_"$DATE"
	if [ $? -eq 0 ]; then
		echo "*****************Backup Completed**************"
	else
		echo "*****************Backup Failed**************"
		exit 1;
	fi;
	exit;
	EOF

}

function deploy_new_package() {

	# Deploy war files

	cd $WORKSPACE
	echo "Copy war file from workspace to target"

	scp -r $WORKSPACE/export/EngelliNeredeyim.war oracle@172.31.60.239:/Products/deployments/$TARGET_FOLDER
	if [ $? -eq 0 ]; then
		echo "War uploaded successfully!!"
	else
		echo "War upload failed!!!"
		exit 1;
	fi;

	echo ""
	echo "Starting Deployment..."

	ssh oracle@172.31.60.239 /bin/bash <<-EOF
	echo "TO2F CLASSPATH setting"

	###cd /Products/app/oracle/middleware/wlserver/server/lib/

	# update below classpath and setWLSEnv.sh

	#./setWLSEnv.sh
	####webl0gic0987123*!

	export CLASSPATH=/Products/setup_files/jdk1.8.0_181/lib/tools.jar:/Products/app/oracle/middleware/wlserver/modules/features/wlst.wls.classpath.jar:/Products/app/oracle/middleware/wlserver/server/lib/weblogic.jar

	java weblogic.Deployer -adminurl t3://172.31.60.239:7001 -username weblogic -password $IVR_PASS -source /Products/deployments/$TARGET_FOLDER/EngelliNeredeyim.war -name $APPLICATION_NAME -targets $TARGET_SERVER -$DEPLOYMENT_METHOD -usenonexclusivelock

	exit
	EOF

}

function restart_servers() {

	#Restart script for  managed server

	echo ""

	ssh oracle@172.31.60.239 /bin/bash <<-EOF

	. ~/.bash_profile

	cd /Products/app/oracle/middleware/user_projects/domains/ADDEV_IVR/bin

	echo "*********Stopping server1***********"

	./stopManagedWebLogic.sh $TARGET_SERVER t3://172.31.60.239:7001 weblogic $IVR_PASS

	sleep 80

	echo ""
	echo "***********Starting server1************"

	cd /Products/app/oracle/middleware/user_projects/domains/ADDEV_IVR/bin

	./setDomainEnv.sh

	./startManagedWebLogic.sh $TARGET_SERVER t3://172.31.60.239:7001 > /Products/app/oracle/middleware/user_projects/domains/ADDEV_IVR/servers/$TARGET_SERVER/logs/$TARGET_SERVER.log 2>&1 &

	echo ""

	sleep 180

	ps -ef | grep -iE "$TARGET_SERVER" | grep -v grep

	echo ""

	exit
	EOF

}


echo "================================================================================="
echo ""
if [[ -z ${TARGET_SERVER} && -z ${GIT_BRANCH_NAME} ]]; then
	echo "ERROR: Please provide all input parameters: TARGET_SERVER, GIT_BRANCH_NAME"
	exit 1;
else
	echo ""
	echo "Target Server -- "$TARGET_SERVER
	echo ""
	echo "Bitbucker Branch -- "$GIT_BRANCH_NAME
	echo ""
	update_variable
	backup_server_package
	deploy_new_package
	restart_servers
fi
