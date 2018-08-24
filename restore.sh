#!/bin/bash
#This script use to restore KernelCI databases and storages
#set -e
DB_DUMP_FILE=$1
STORAGE_DUMP_FILE=$2

mkdir -p ./tmp/databases ./tmp/storages

if [ ! "$DB_DUMP_FILE" ] && [ ! "$STORAGE_DUMP_FILE" ];then
    echo "Error: Missing parameter!!"
    echo "Usage: ./restore.sh -d DATABASE_BACKUP.tar.gz -s STORAGE_BACKUP.tar.gz"
    exit 1
fi

if [ ! -z "$DB_DUMP_FILE" ];then
    echo "-->Restoring Mongo database from $DB_DUMP_FILE"
    ## Get db container
    #ID=$(docker ps -q --filter "name=phat_kernelci" 2>/dev/null)

	ID=$(docker ps -q --filter "name=mongo" 2>/dev/null)
    if [ "$ID" = "" ];then
      echo "--Container for service kernelci_mongo not found --"
      exit 1
    fi

    ## Copy database to container
    tar xvf $DB_DUMP_FILE -C ./tmp/databases
    if [ $? -eq 0 ];then
      echo "--Database backup extracted correctly--"
    else
      echo "--Something went wrong wile extracting the database from $DB_DUMP_FILE--"
      exit 1
    fi

    DUMP_FOLDER=$(sed -e 's/.tar.gz//' <<<$(basename $DB_DUMP_FILE ))

    docker cp ./tmp/databases $ID:/tmp/ | exit 1

    ## Restore database
    docker exec $ID /bin/bash -c "mongorestore -d kernel-ci /tmp/databases/$DUMP_FOLDER/kernel-ci" | exit 1
fi

if [ ! -z "$STORAGE_DUMP_FILE" ];then
    echo "-->Restoring storage from $STORAGE_DUMP_FILE"
    ## Restore storage
    VOLUMES=$(docker volume ls -q --filter "name=kci")

	if [ "$VOLUMES" = "" ]; then
		echo "Can't find kci volume"
		exit 1
	fi
	echo "Choose a storage volume which you want to restore: "
	select vol in $VOLUMES;do
		STORAGE_VOLUME=$vol
		break
	done
    tar xvf $STORAGE_DUMP_FILE -C ./tmp/storages
    docker run --rm -v `pwd`/tmp/storages/:/tmp/storages/ -v $STORAGE_VOLUME:/storages busybox cp -r /tmp/storages/. /storages
fi
# Clear temp data
rm -rf ./tmp 
 
echo "-------------------------------------------------------------------------------------"
echo "               Database and Storage have restored successfully"
echo "-------------------------------------------------------------------------------------"
 
exit 0
