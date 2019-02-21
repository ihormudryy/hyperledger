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
export RANDOM_NUMBER=${RANDOM}

SDIR=$(dirname "$0")
cd ${SDIR}
source ${SDIR}/scripts/env.sh "here" "consumer provider" 2

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
DDIR=${SDIR}/${DATA}
CDIR=${SDIR}/${COMMON}
if [ -d ${DDIR} ]; then
   log "Cleaning up the data directory from previous run at $DDIR"
   rm -rf ${SDIR}/data
   rm -rf ${SDIR}/common
   rm -rf ${SDIR}/docker
fi
mkdir -p ${CDIR}/logs
mkdir -p ${SDIR}/docker
# Create the docker-compose file

${SDIR}/scripts/makeDocker.sh main
source ${SDIR}/scripts/env.sh "mega" "sharaga" 3
${SDIR}/scripts/makeDocker.sh createSingleOrganization

# Create the docker containers
log "Creating docker containers ..."
docker-compose -f ${SDIR}/docker/docker-compose.yaml up -d
 
# Wait for the setup container to complete
dowait "the 'setup' to finish registering identities, creating the genesis block and other artifacts" 90 $SDIR/$SETUP_LOGFILE $SDIR/$SETUP_SUCCESS_FILE

# Wait for the run container to start and then tails it's summary log
#dowait "'run' to start fabric" 60 ${SDIR}/${SETUP_LOGFILE} ${SDIR}/${RUN_SUMFILE}

tail -f ${SDIR}/${RUN_SUMFILE}&
TAIL_PID=$!

# Wait for the run container to complete
while true; do
   if [ -f ${SDIR}/${RUN_SUCCESS_FILE} ]; then
      kill -9 $TAIL_PID
      docker ps -a
      exit 0
   elif [ -f ${SDIR}/${RUN_FAIL_FILE} ]; then
      kill -9 $TAIL_PID
      exit 1
   else
      sleep 1
   fi
done
