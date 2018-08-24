#!/bin/bash
# This script uses to deploy KernelCI Automatically

STACK_NAME="kernelci"

if [ "$#" -ne "4" ]; then
	echo "Error: Missing parameter!!"
	echo "Usage: ./start.sh <IP_ADDR> <FRONTEND_PORT> <BACKEND_PORT> <STORAGE_PORT>"
	exit 1
fi
# Get parameter 
IP=$1
FE_PORT=$2
BE_PORT=$3
SR_PORT=$4

sed -e "s/FE_PORT/$FE_PORT/;s/BE_PORT/$BE_PORT/;s/SR_PORT/$SR_PORT/" .docker-stack.yml > docker-stack.yml

export TAG=${TAG:-latest}

## Prerequisites

#a Make sure Docker daemon is in swarm mode
NODES=$(docker node ls 2>/dev/null)

if [ $? = 1 ]; then
    echo "Docker daemon must run in swarm mode"
    echo "-> run the \"docker swarm init\" command to enable swarm mode"
    docker swarm init --advertise-addr $IP
fi

## Deploy the application

echo "-> deploying the application..."
docker stack deploy -c docker-stack.yml $STACK_NAME
echo "-> application deployed"

## Wait for the application to be available

echo "-> waiting for backend..."
while [ $(curl -s -m 3 -o /dev/null -w "%{http_code}" $IP:$BE_PORT) -ne 200 ]; do
   sleep 1
done
echo "-> waiting for frontend..."
while [ $(curl -s -m 3 -o /dev/null -w "%{http_code}" $IP:FE_PORT) -ne 200 ]; do
  sleep 1
done

## Configure the application

echo "-> configuring the application..."

### Get token from backend

echo "-> requesting token from backend..."
TOKEN=""
while [ "$TOKEN" = "" ];do
  TOKEN=$(curl -m 3 -s -X POST -H "Content-Type: application/json" -H "Authorization: MASTER_KEY" -d '{"email": "adm@kernelci.org", "admin": 1}' $IP:$BE_PORT/token | docker container run --rm -i lucj/jq -r .result[0].token 2>/dev/null)
  sleep 1
done
echo $TOKEN > .kernelci_token
echo "-> token returned: $TOKEN"

### Create configuration with token created

CONFIG=frontend-$(date "+%Y%m%dT%H%M%S")

sed -ine "s/^FILE_SERVER_URL.*$/FILE_SERVER_URL = \"http:\/\/$IP:$SR_PORT\"/" frontend/flask_settings
sed -e "s/^BACKEND_TOKEN.*$/BACKEND_TOKEN = \"$TOKEN\"/" frontend/flask_settings > config/frontend.config
docker config create $CONFIG config/frontend.config

### Update frontend with configuration

docker service update --config-add src=$CONFIG,target=/etc/linaro/kernelci-frontend.cfg kernelci_frontend
echo "-> application configured"
echo "--> frontend available on port $FE_PORT"
echo "--> backend available on port $BE_PORT"
echo "--> storage available on port $SR_PORT"
