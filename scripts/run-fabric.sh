#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

export SRC=$(dirname "$0")
source $SRC/env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS
source $SRC/make-config-tx.sh

function getChannel {
  initPeerVars "$PEER_ORGS" 1
  switchToAdminIdentity
  export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
  # peer channel list | grep "channel$RANDOM_NUMBER"
  peer channel getinfo -c "channel$RANDOM_NUMBER"
}

function testChannel {
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   export PROFILE=$ORGS_PROFILE
   createChannel ${PORGS[0]}
   for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         joinChannel $ORG $COUNT
         COUNT=$((COUNT+1))
      done
   done
   logr "Congratulations! The testChannel  has been successfully created."
}

function testMarblesChaincode {
   set -e
   
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   export CHAINCODE_NAME="marbles${RANDOM}"
   export CHAINCODE_PATH="marbles/node"
   export CHAINCODE_TYPE="node"
   export CHAINCODE_VERSION="1.3"
   export LOG_FILE_NAME=${LOGDIR}/chaincode-${CHAINCODE_NAME}-install.log

   for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         installChaincode $ORG $COUNT
         instantiateChaincode $ORG $COUNT '{"Args":[]}'
         COUNT=$((COUNT+1))
      done
   done
}

function testABACChaincode {
   set -e
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   export CHAINCODE_NAME="abac${RANDOM}"
   export CHAINCODE_PATH="abac/go"
   export CHAINCODE_TYPE="golang"
   export CHAINCODE_VERSION="3.3"
   export LOG_FILE_NAME=${LOGDIR}/chaincode-${CHAINCODE_NAME}-install.log

   for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         installChaincode $ORG $COUNT
         COUNT=$((COUNT+1))
      done
   done
   
   instantiateChaincode ${PORGS[0]} 1 '{"Args":["init","a","100","b","200"]}'
   chaincodeQuery ${PORGS[0]} 1 '{"Args":["query","a"]}' 100
   invokeChaincode ${PORGS[0]} 1 '{"Args":["invoke","a","b","10"]}'
   chaincodeQuery ${PORGS[0]} 1 '{"Args":["query","a"]}' 90

   export CHAINCODE_VERSION="3.4"
   for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         installChaincode $ORG $COUNT
         COUNT=$((COUNT+1))
      done
   done
   upgradeChaincode ${PORGS[0]} 1 '{"Args":["init","a","100","b",""]}'

   chaincodeQuery ${PORGS[0]} 1 '{"Args":["query","a"]}' 100
   invokeChaincode ${PORGS[0]} 1 '{"Args":["invoke","a","b","10"]}'
   chaincodeQuery ${PORGS[0]} 1 '{"Args":["query","a"]}' 90

   logr "Congratulations! The testABACChaincode tests ran successfully."
}

function testHighThroughputChaincode {
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   export CHAINCODE_NAME="high_throughput${RANDOM}"
   export CHAINCODE_PATH="high_throughput"
   export CHAINCODE_TYPE="golang"
   export CHAINCODE_VERSION="1.3"
   export LOG_FILE_NAME=${LOGDIR}/chaincode-${CHAINCODE_NAME}-install.log

   for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         installChaincode $ORG $COUNT
         COUNT=$((COUNT+1))
      done
   done
   MAX_ORGS=1
   MAX_PEERS=1
   ORG_NUM=$(($RANDOM%$MAX_ORGS))
   PEER_NUM=$(($(($RANDOM%$MAX_PEERS))+1))
   instantiateChaincode ${PORGS[$ORG_NUM]} $PEER_NUM '{"Args":[]}'
   
   sleep 5 #Done to awoit time related errors

   export COUNTER=0
   export VARIABLE="myvar${RANDOM}"
   START=$(date +%s)
   for (( i = 0; i < 100; ++i ))
   do
      VALUE=${RANDOM}
      SIGN="+"
      COUNTER=$((COUNTER+$VALUE))
      ORG_NUM=$(($RANDOM%$MAX_ORGS))
      PEER_NUM=$(($(($RANDOM%$MAX_PEERS))+1))
      invokeChaincode ${PORGS[$ORG_NUM]} $PEER_NUM '{"Args":["update","'$VARIABLE'","'$VALUE'","'$SIGN'"]}'
   done
   echo "testHighThroughput UPDATE took $DIFF seconds"

   END=$(date +%s)
   DIFF=$(( $END - $START ))
   for (( i = 0; i < 100; ++i ))
   do
      ORG_NUM=$(($RANDOM%$MAX_ORGS))
      PEER_NUM=$(($(($RANDOM%$MAX_PEERS))+1))
      chaincodeQuery ${PORGS[$ORG_NUM]} $PEER_NUM '{"Args":["get","'$VARIABLE'"]}' $COUNTER
   done
   START=$(date +%s)
   END=$(date +%s)
   DIFF=$(( $END - $START ))
   echo "testHighThroughput QUERY took $DIFF seconds"
   logr "Congratulations! The testHighThroughput tests ran successfully."
}

function addAffiliation {
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   initPeerVars ${PORGS[0]} 1
   switchToAdminIdentity
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   set -x
   fabric-ca-client enroll -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054 -M $ORG_ADMIN_HOME/msp
   fabric-ca-client affiliation add $1 -d \
      -M $ORG_ADMIN_HOME/msp \
      -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054 \
      --tls.client.certfile $CORE_ORDERER_TLS_CLIENTCERT_FILE \
      --tls.client.keyfile $CORE_ORDERER_TLS_CLIENTKEY_FILE \
      --tls.certfiles $INT_CA_CHAINFILE
}

function updateSytemChannelConfig {
   rm -rf /tmp/*
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   PEERS=$1
   export RANDOM_NUMBER="testchainid"
   mkdir -p /private/crypto${RANDOM_NUMBER}

   export PROFILE=$ORGS_PROFILE
   export CHANNEL_NAME="testchainid"

   for ORG in $PEERS; do
      echo $ORG
      fetchSystemChannelConfig
      createConfigUpdatePayload $ORG 1 'Consortiums'
      updateSystemConfigBlock ${OORGS[0]} 1
      #joinChannel $ORG 1
   done
}

function updateChannelConfig {
   rm -rf /tmp/*
   fetchConfigBlock $1 $2
   createConfigUpdatePayload $3 $2 'Application'
   updateConfigBlock $1 $2
   local COUNT=1
   while [[ "$COUNT" -le $NUM_PEERS ]]; do
      joinChannel $3 $COUNT
      COUNT=$((COUNT+1))
   done
   # apply anchor update
   updateChannel $1 $2
}

# Enroll as a peer admin and create the channel
function createChannel {
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   initPeerVars $1 1
   switchToAdminIdentity
   makeConfigTxYaml /${COMMON}
   generateChannelTx ${1}
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   logr "Creating channel '$CHANNEL_NAME' on $ORDERER_HOST ... $BLOCK_FILE"
   peer channel create \
      -c $CHANNEL_NAME \
      -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS \
      --outputBlock $BLOCK_FILE
}

# Enroll as a fabric admin and join the channel
function joinChannel {
   #if [ $# -ne 2 ]; then
   #   fatalr "Usage: joinChannel <ORG> <NUM>"
   #fi

   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initPeerVars $1 $2
   switchToAdminIdentity
   local COUNT=1
   MAX_RETRY=10
   while true; do
      logr "Peer $PEER_HOST is attempting to join channel '$CHANNEL_NAME' (attempt #${COUNT}) ..."
      export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
      peer channel join -b ${BLOCK_FILE}
      if [ $? -eq 0 ]; then
         set -e
         logr "Peer $PEER_HOST successfully joined channel '$CHANNEL_NAME'"
         return
      fi
      if [ $COUNT -gt $MAX_RETRY ]; then
         fatalr "Peer $PEER_HOST failed to join channel '$CHANNEL_NAME' in $MAX_RETRY retries"
      fi
      COUNT=$((COUNT+1))
      sleep 1
   done
}

function chaincodeQuery {
   if [ $# -ne 4 ]; then
      fatalr "Usage: chaincodeQuery <ORG> <NUM> <Constructor message> <expected-value>"
   fi
   set +e
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initPeerVars $1 $2
   switchToUserIdentity $1
   local ARGS=$3
   local EXPECTED=$4
   logr "Querying chaincode in the channel '$CHANNEL_NAME' on the peer '$PEER_HOST' ..."
   local rc=1
   local starttime=$(date +%s)
   # Continue to poll until we get a successful response or reach QUERY_TIMEOUT
   while test "$(($(date +%s)-starttime))" -lt "$QUERY_TIMEOUT"; do
      sleep 1
      export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
      peer chaincode query \
         -C $CHANNEL_NAME \
         -n ${CHAINCODE_NAME} \
         -c $ARGS >& ${LOG_FILE_NAME}

      export VAL=$(cat ${LOG_FILE_NAME} | awk '/Query Result/ {print $NF}')
      if [ $? -eq 0 -a "$VALUE" = "$EXPECTED" ]; then
         logr "Query of channel '$CHANNEL_NAME' on peer '$PEER_HOST' was successful"
         set -e
         return 0
      else
         # removed the string "Query Result" from peer chaincode query command result, as a result, have to support both options until the change is merged.
         VAL=$(cat ${LOG_FILE_NAME} | egrep '^[0-9]+$')
         if [ $? -eq 0 -a "$VAL" = "$EXPECTED" ]; then
            logr "Query of channel '$CHANNEL_NAME' on peer '$PEER_HOST' was successful"
            set -e
            return 0
         fi
      fi
      echo -n "."
   done
   cat ${LOG_FILE_NAME}
   cat ${LOG_FILE_NAME} >> $RUN_SUMFILE
   fatalr "Failed to query channel '$CHANNEL_NAME' on peer '$PEER_HOST'; expected value was $EXPECTED and found $VAL"
}

function queryAsRevokedUser {
   if [ $# -ne 2 ]; then
      fatalr "Usage: queryAsRevokedUser <ORG> <NUM>"
   fi
   set +e
   logr "Querying the chaincode in the channel '$CHANNEL_NAME' on the peer '$PEER_HOST' as revoked user '$USER_NAME' ..."
   local starttime=$(date +%s)
   # Continue to poll until we get an expected response or reach QUERY_TIMEOUT
   while test "$(($(date +%s)-starttime))" -lt "$QUERY_TIMEOUT"; do
      sleep 1
      peer chaincode query -C $CHANNEL_NAME -n ${CHAINCODE_NAME} -c '{"Args":["query","a"]}' >& ${LOG_FILE_NAME}
      if [ $? -ne 0 ]; then
        err=$(cat ${LOG_FILE_NAME} | grep "access denied")
        if [ "$err" != "" ]; then
           logr "Expected error occurred when the revoked user '$USER_NAME' queried the chaincode in the channel '$CHANNEL_NAME'"
           set -e
           return 0
        fi
      fi
      echo -n "."
   done
   set -e 
   cat ${LOG_FILE_NAME}
   cat ${LOG_FILE_NAME} >> $RUN_SUMFILE
   return 1
}

function makePolicy  {
   POLICY="OR("
   local COUNT=0
   for ORG in $PEER_ORGS; do
      if [ $COUNT -ne 0 ]; then
         POLICY="${POLICY},"
      fi
      initOrgVars $ORG
      POLICY="${POLICY}'${ORG_MSP_ID}.member'"
      COUNT=$((COUNT+1))
   done
   POLICY="${POLICY})"
   log "policy: $POLICY"
}

function updateChannel {
   #if [ $# -ne 2 ]; then
   #   fatalr "Usage: updateChannel <ORG> <NUM>"
   #fi
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initPeerVars $1 $2
   switchToAdminIdentity
   logr "Updating anchor peers for $PEER_HOST ..."
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   peer channel update \
      -c $CHANNEL_NAME \
      -f $ANCHOR_TX_FILE \
      $ORDERER_CONN_ARGS
}

function installChaincode {
   if [ $# -ne 2 ]; then
      fatalr "Usage: installChaincode <ORG> <NUM>"
   fi
   FS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initPeerVars $1 $2
   switchToAdminIdentity
   logr "Installing chaincode on $PEER_HOST ..."
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   CHAINCODE_PREFIX="github.com/hyperledger/fabric-samples"
   if [ $CHAINCODE_TYPE = "node" ]; then
      CHAINCODE_PREFIX="$GOPATH/src/$CHAINCODE_PREFIX"
   fi
   set -x
   peer chaincode install \
      -n ${CHAINCODE_NAME} \
      -v ${CHAINCODE_VERSION} \
      -l ${CHAINCODE_TYPE} \
      -p $CHAINCODE_PREFIX/${CHAINCODE_PATH}
   set +x
}

function upgradeChaincode {
   if [ $# -ne 3 ]; then
      fatalr "Usage: instantiateChaincode <ORG> <NUM> <Constructor message> "
   fi
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   makePolicy
   initPeerVars $1 $2
   switchToAdminIdentity
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   logr "Upgrading chaincode on $PEER_HOST ..."
   peer chaincode upgrade \
      -C ${CHANNEL_NAME} \
      -n ${CHAINCODE_NAME} \
      -v ${CHAINCODE_VERSION} \
      -c $3 \
      -l ${CHAINCODE_TYPE} \
      -P ${POLICY} \
      $ORDERER_CONN_ARGS
}

function instantiateChaincode {
   if [ $# -ne 3 ]; then
      fatalr "Usage: instantiateChaincode <ORG> <NUM> <Constructor message> "
   fi
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   makePolicy
   initPeerVars $1 $2
   switchToAdminIdentity
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   logr "Instantiating chaincode on $PEER_HOST ..."
   peer chaincode instantiate \
      -C ${CHANNEL_NAME} \
      -n ${CHAINCODE_NAME} \
      -v ${CHAINCODE_VERSION} \
      -c $3 \
      -l ${CHAINCODE_TYPE} \
      -P "$POLICY" \
      $ORDERER_CONN_ARGS
}

function invokeChaincode {
   if [ $# -ne 3 ]; then
      fatalr "Usage: invokeChaincode <ORG> <NUM> <Constructor message> "
   fi
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initPeerVars $1 $2
   switchToUserIdentity $1
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   logr "Sending invoke transaction to $PEER_HOST ..."
   mkdir -p /tmp/logs
   peer chaincode invoke \
      -C $CHANNEL_NAME \
      -n ${CHAINCODE_NAME} \
      -c $3 \
      $ORDERER_CONN_ARGS > /tmp/logs/${CHAINCODE_NAME}.txt
}

function generateChannelTx {
   which configtxgen
   if [ "$?" -ne 0 ]; then
      fatal "configtxgen tool not found. exiting"
   fi

   ORG=$1
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp

   if [ -z "$PROFILE" ]; then
    PROFILE=$ORGS_PROFILE
   fi

   log "Generating channel configuration transaction $PROFILE at $CHANNEL_TX_FILE"
   configtxgen -profile ${PROFILE} \
      -outputCreateChannelTx $CHANNEL_TX_FILE \
      -channelID $CHANNEL_NAME

   if [ "$?" -ne 0 ]; then
      fatal "Failed to generate channel configuration transaction"
   fi

   for ORG in $PEER_ORGS; do
      initOrgVars $ORG
      log "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
      configtxgen -profile ${PROFILE} \
         -outputAnchorPeersUpdate $ANCHOR_TX_FILE \
         -channelID $CHANNEL_NAME -asOrg $ORG

      if [ "$?" -ne 0 ]; then
         fatal "Failed to generate anchor peer update for $ORG"
      fi
   done
}

function fetchConfigBlock {
   logr "Fetching the configuration block of the channel '$CHANNEL_NAME'"
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initPeerVars $1 $2
   switchToUserIdentity $1
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   peer channel fetch config $CONFIG_BLOCK_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}

function fetchSystemChannelConfig {
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"

   PATH_PREFIX=/tmp

   initOrdererVars ${OORGS[0]} 1
   export CORE_PEER_LOCALMSPID=$ORDERER_GENERAL_LOCALMSPID
   export ORDERER_CA=$CA_CHAINFILE
   export CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   set -x
   peer channel fetch config $CONFIG_BLOCK_FILE -c testchainid $ORDERER_CONN_ARGS
   set +x
   #configtxlator proto_decode \
   #   --input $PATH_PREFIX/system_config_block.pb \
   #   --type common.Block > $PATH_PREFIX/system_config_block.json
}

function updateSystemConfigBlock {
   logr "Updating the configuration block of the channel '$CHANNEL_NAME'"
   logr "Fetching the configuration block of the channel '$CHANNEL_NAME'"
   initOrdererVars ${OORGS[0]} 1
   CORE_PEER_LOCALMSPID=$ORDERER_GENERAL_LOCALMSPID
   ORDERER_CA=$CA_CHAINFILE
   CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE
   CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   initOrdererVars ${OORGS[0]} 1
   switchToAdminIdentity
   peer channel update -f $CONFIG_UPDATE_ENVELOPE_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
   peer channel fetch config /tmp/config_block.pb -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}

function updateConfigBlock {
   logr "Updating the configuration block of the channel '$CHANNEL_NAME'"
   logr "Fetching the configuration block of the channel '$CHANNEL_NAME'"
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   initPeerVars $1 $2
   switchToUserIdentity $1
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   peer channel update -f $CONFIG_UPDATE_ENVELOPE_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
   peer channel fetch config /tmp/config_block.pb -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}

function createConfigUpdatePayload {
   ORG=$1
   PATH_PREFIX=/tmp
   GROUP=$3
   initPeerVars $1 $2
   switchToAdminIdentity
   makeConfigTxYaml /${COMMON}
   generateChannelTx $1
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp

   configtxgen -printOrg $ORG > $PATH_PREFIX/$ORG.json

   configtxlator proto_decode \
      --input $CONFIG_BLOCK_FILE \
      --type common.Block | jq .data.data[0].payload.data.config > $PATH_PREFIX/config.json

   set -x
   if [ $GROUP = "Consortiums" ]; then
      jq -s '.[0] * {"channel_group":{"groups":{"'$GROUP'":{"groups": {"SampleConsortium": {"groups": {'$ORG':.[1]}}}}}}}' \
      $PATH_PREFIX/config.json $PATH_PREFIX/$ORG.json > $PATH_PREFIX/updated_config.json
   elif [ $GROUP = "Application" ]; then
      jq -s '.[0] * {"channel_group":{"groups":{"'$GROUP'":{"groups": {'$ORG':.[1]}}}}}' \
      $PATH_PREFIX/config.json $PATH_PREFIX/$ORG.json > $PATH_PREFIX/updated_config.json
   fi
   set +x

   configtxlator proto_encode \
      --input $PATH_PREFIX/config.json \
      --type common.Config > $PATH_PREFIX/config.pb
   
   configtxlator proto_encode \
      --input $PATH_PREFIX/updated_config.json \
      --type common.Config > $PATH_PREFIX/updated_config.pb

   configtxlator compute_update \
      --original $PATH_PREFIX/config.pb \
      --updated $PATH_PREFIX/updated_config.pb \
      --channel_id=$CHANNEL_NAME > $PATH_PREFIX/config_update.pb

   configtxlator proto_decode \
      --input $PATH_PREFIX/config_update.pb \
      --type common.ConfigUpdate > $PATH_PREFIX/config_update.json

   echo '{"payload":{"header":{"channel_header":{"channel_id":"'"${CHANNEL_NAME}"'", "type":2}},"data":{"config_update":'$(cat "$PATH_PREFIX"/config_update.json)'}}}' > $PATH_PREFIX/config_update_as_envelope.json
   configtxlator proto_encode \
      --input $PATH_PREFIX/config_update_as_envelope.json \
      --type common.Envelope > $CONFIG_UPDATE_ENVELOPE_FILE

   # sign by majority
   for ORGAN in $PEER_ORGS; do
      initPeerVars $ORGAN 1
      export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
      peer channel signconfigtx -f $CONFIG_UPDATE_ENVELOPE_FILE
   done
}

function finish {
   if [ "$done" = true ]; then
      logr "See $RUN_LOGFILE for more details"
      touch /$RUN_SUCCESS_FILE
   else
      logr "Tests did not complete successfully; see $RUN_LOGFILE for more details"
      touch /$RUN_FAIL_FILE
      exit 1
   fi
}

function logr {
   log $*
   #log $* >> $RUN_SUMPATH
}

function fatalr {
   logr "FATAL: $*"
   exit 1
}

$1 $2 $3 $4 $5 $6