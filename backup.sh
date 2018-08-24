#/bin/sh
# This script use to back up KernelCI database and storage
set -e

DUMP_FOLDER=${1:-/tmp}

if [ ! -d $DUMP_FOLDER ];then
 mkdir $DUMP_FOLDER
fi

# Dump timestamp
ts=$(date -u "+%Y%m%dT%H%M%S")

## Backup DB

# Name of the database to dump
DB="kernel-ci"

# Get db container
db=$(docker ps | grep mongo | awk '{print $1}')

if [ "$db" = "" ];then
  echo "No mongo container running => exiting"
  exit 1
fi

# Dump database
echo "=> Start to backup database"
docker exec $db mongodump -d $DB -o /tmp/kernelci-database-$ts 
docker exec $db tar czf /tmp/kernelci-database-$ts.tar.gz -C /tmp/ kernelci-database-$ts

# Save on host
docker cp $db:/tmp/kernelci-database-$ts.tar.gz $DUMP_FOLDER
docker exec $db rm -rf /tmp/kernelci-database-$ts.tar.gz /tmp/kernelci-database-$ts 

## Backup storage
echo "=> Start to backup storage"

VOLUMES=$(docker volume ls -q --filter "name=kci")

if [ "$VOLUMES" = "" ]; then
	echo "Can't find kci volume"
	exit 1
fi
echo "Choose a storage volume which you want to backup: "
select vol in $VOLUMES;do
	STORAGE_VOLUME=$vol
    break
done
docker run \
  --rm \
  -v $STORAGE_VOLUME:/tmp/storages \
  -v $DUMP_FOLDER:/tmp/dump/ \
  alpine tar -czvf /tmp/dump/kernelci-storage-$ts.tar.gz -C /tmp/storages/ .

echo "--------------------------------------------------------------------------"
echo "=> Database and storage files will be saved in folder $DUMP_FOLDER"
echo "--------------------------------------------------------------------------"
ls $DUMP_FOLDER
