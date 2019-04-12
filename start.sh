#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# This script does everything required to run the fabric CA sample.
#
# By default, this test is run with the latest released docker images.
#
# To run against a specific fabric/fabric-ca version:
#    export FABRIC_TAG=1.4.0
#
# To run with locally built images:
#    export FABRIC_TAG=local

set -e
export FABRIC_TAG=1.4.0

SDIR=$(dirname "$0")
cd ${SDIR}
export RANDOM_NUMBER=${RANDOM}
echo "First random number: $RANDOM_NUMBER"
echo $RANDOM_NUMBER > ${SDIR}/scripts/random.txt
export TYPE="kafka"
export ORDERER="blockchain-technology"
export ORGS="governor"
source ${SDIR}/scripts/env.sh $ORDERER "$ORGS" 2 $TYPE

# Delete docker containers
dockerContainers=$(docker ps -a | awk '$2~/hyperledger/ {print $1}')
if [ "$dockerContainers" != "" ]; then
   log "Deleting existing docker containers ..."
   docker stop $(docker ps -a --format "{{.Names}}")
   docker rm -f $(docker ps -a --format "{{.Names}}")
   docker network prune
   docker volume prune
   docker network create --subnet=$subnet $NETWORK
fi

# Remove chaincode docker images
chaincodeImages=`docker images | grep "^dev-peer" | awk '{print $3}'`
if [ "$chaincodeImages" != "" ]; then
   log "Removing chaincode docker images ..."
   docker rmi -f $chaincodeImages > /dev/null
fi

# Start with a clean data directory
CDIR=${SDIR}/${COMMON}
if [ -d ${SDIR}/logs ]; then
   rm -rf ${SDIR}/logs
   rm -rf ${SDIR}/docker
fi
mkdir -p ${SDIR}/docker
mkdir -p ${SDIR}/logs

# Create the docker-compose file
${SDIR}/scripts/makeDocker.sh main
${SDIR}/scripts/makeDocker.sh createFabricRunner
docker-compose -f ${SDIR}/docker/docker-compose.yaml up -d

ORGANIZATIONS="org1 org2 org3 org4"
IFS=', ' read -r -a OORGS <<< "$ORGANIZATIONS"
MAX_PEERS=2
for ORG in $ORGANIZATIONS; do
   source ${SDIR}/scripts/env.sh $ORDERER $ORG $MAX_PEERS $TYPE
   ${SDIR}/scripts/makeDocker.sh createSingleOrganization
   docker-compose -f ${SDIR}/docker/docker-compose-$ORG.yaml up -d
done

docker-compose -f ${SDIR}/docker/docker-compose-setup.yaml up -d
docker ps -a
exit

# Wait for the setup container to complete
dowait "the 'setup' to finish registering identities, creating the genesis block and other artifacts" 90 $SDIR/$SETUP_LOGFILE $SDIR/$SETUP_SUCCESS_FILE

tail -f ${SDIR}/${RUN_SUMFILE}&
TAIL_PID=$!

# Wait for the run container to complete
while true; do
   if [ -f ${SDIR}/${RUN_SUCCESS_FILE} ]; then
      kill -9 $TAIL_PID
      exit 0
   elif [ -f ${SDIR}/${RUN_FAIL_FILE} ]; then
      kill -9 $TAIL_PID
      exit 1
   else
      sleep 1
   fi
done
