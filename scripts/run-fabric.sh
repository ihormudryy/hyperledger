#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

SRC=$(dirname "$0")
source $SRC/env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS
source $SRC/make-config-tx.sh
LOG_FILE_NAME=/${COMMON}/chaincode-${CHAINCODE_NAME}-install.log

function testABAC {
   makeConfigTxYaml /${COMMON}
   generateChannelTx 
   createChannel
   # All peers join, update the channel and install chainncode
   for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         joinChannel $ORG $COUNT
         installChaincode $ORG $COUNT
         instantiateChaincode $ORG $COUNT '{"Args":["init","a","100","b","200"]}'
         chaincodeQuery $ORG $COUNT '{"Args":["query","a"]}' 100
         invokeChaincode $ORG $COUNT '{"Args":["invoke","a","b","10"]}'
         chaincodeQuery $ORG $COUNT '{"Args":["query","a"]}' 90
         COUNT=$((COUNT+1))
      done
   done
   
   # Query chaincode from the 1st peer of the 1st org
   updateChannel ${PORGS[0]} 1 
   fetchConfigBlock
   createConfigUpdatePayloadWithCRL
   #updateConfigBlock
   logr "Congratulations! The tests ran successfully."
}

# Enroll as a peer admin and create the channel
function createChannel {
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   initPeerVars ${PORGS[0]} 1
   switchToAdminIdentity
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   logr "Creating channel '$CHANNEL_NAME' on $ORDERER_HOST ..."
   peer channel create -c $CHANNEL_NAME -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS --outputBlock $BLOCK_FILE
}

# Enroll as a fabric admin and join the channel
function joinChannel {
   if [ $# -ne 2 ]; then
      fatalr "Usage: joinChannel <ORG> <NUM>"
   fi
   set +e
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

      peer chaincode query \
         -C $CHANNEL_NAME \
         -n ${CHAINCODE_NAME} \
         -c $ARGS >& ${LOG_FILE_NAME}

      VALUE=$(cat ${LOG_FILE_NAME} | awk '/Query Result/ {print $NF}')
      if [ $? -eq 0 -a "$VALUE" = "$EXPECTED" ]; then
         logr "Query of channel '$CHANNEL_NAME' on peer '$PEER_HOST' was successful"
         set -e
         return 0
      else
         # removed the string "Query Result" from peer chaincode query command result, as a result, have to support both options until the change is merged.
         VALUE=$(cat ${LOG_FILE_NAME} | egrep '^[0-9]+$')
         if [ $? -eq 0 -a "$VALUE" = "$EXPECTED" ]; then
            logr "Query of channel '$CHANNEL_NAME' on peer '$PEER_HOST' was successful"
            set -e
            return 0
         fi
      fi
      echo -n "."
   done
   cat ${LOG_FILE_NAME}
   cat ${LOG_FILE_NAME} >> $RUN_SUMFILE
   fatalr "Failed to query channel '$CHANNEL_NAME' on peer '$PEER_HOST'; expected value was $EXPECTED and found $VALUE"
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
   if [ $# -ne 2 ]; then
      fatalr "Usage: updateChannel <ORG> <NUM>"
   fi
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
   peer chaincode install \
      -n ${CHAINCODE_NAME} \
      -v ${CHAINCODE_VERSION} \
      -p github.com/hyperledger/fabric-samples/${CHAINCODE_PATH}
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
   logr "Instantiating chaincode on $PEER_HOST ..."
   peer chaincode instantiate \
      -C $CHANNEL_NAME \
      -n ${CHAINCODE_NAME} \
      -v ${CHAINCODE_VERSION} \
      -c $3 \
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
   logr "Sending invoke transaction to $PEER_HOST ..."
   peer chaincode invoke \
      -C $CHANNEL_NAME \
      -n ${CHAINCODE_NAME} \
      -c $3 \
      $ORDERER_CONN_ARGS
}

function generateChannelTx {
   which configtxgen
   if [ "$?" -ne 0 ]; then
      fatal "configtxgen tool not found. exiting"
   fi

   log "Generating channel configuration transaction at $CHANNEL_TX_FILE"
   configtxgen -profile OrgsChannel -outputCreateChannelTx $CHANNEL_TX_FILE -channelID $CHANNEL_NAME
   if [ "$?" -ne 0 ]; then
      fatal "Failed to generate channel configuration transaction"
   fi

   for ORG in $PEER_ORGS; do
      initOrgVars $ORG
      log "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
      configtxgen -profile OrgsChannel -outputAnchorPeersUpdate $ANCHOR_TX_FILE \
                  -channelID $CHANNEL_NAME -asOrg $ORG
      if [ "$?" -ne 0 ]; then
         fatal "Failed to generate anchor peer update for $ORG"
      fi
   done
}

function fetchConfigBlock {
   logr "Fetching the configuration block of the channel '$CHANNEL_NAME'"
   peer channel fetch config $CONFIG_BLOCK_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}

function updateConfigBlock {
   logr "Updating the configuration block of the channel '$CHANNEL_NAME'"
   peer channel update -f $CONFIG_UPDATE_ENVELOPE_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}

function createConfigUpdatePayloadWithCRL {
   logr "Creating config update payload with the generated CRL for the organization '$ORG'"
   # Start the configtxlator
   configtxlator start &
   configtxlator_pid=$!
   log "configtxlator_pid:$configtxlator_pid"
   logr "Sleeping 5 seconds for configtxlator to start..."
   sleep 5

   pushd /tmp

   CTLURL=http://127.0.0.1:7059
   # Convert the config block protobuf to JSON
   curl -X POST --data-binary @$CONFIG_BLOCK_FILE $CTLURL/protolator/decode/common.Block > config_block.json
   # Extract the config from the config block
   jq .data.data[0].payload.data.config config_block.json > config.json

   # Update crl in the config json
   CRL=$(cat $CORE_PEER_MSPCONFIGPATH/crls/crl*.pem | base64 | tr -d '\n')
   cat config.json | jq --arg org "$ORG" --arg crl "$CRL" '.channel_group.groups.Application.groups[$org].values.MSP.value.config.revocation_list = [$crl]' > updated_config.json

   # Create the config diff protobuf
   curl -X POST --data-binary @config.json $CTLURL/protolator/encode/common.Config > config.pb
   curl -X POST --data-binary @updated_config.json $CTLURL/protolator/encode/common.Config > updated_config.pb
   curl -X POST -F original=@config.pb -F updated=@updated_config.pb $CTLURL/configtxlator/compute/update-from-configs -F channel=$CHANNEL_NAME > config_update.pb

   # Convert the config diff protobuf to JSON
   curl -X POST --data-binary @config_update.pb $CTLURL/protolator/decode/common.ConfigUpdate > config_update.json

   # Create envelope protobuf container config diff to be used in the "peer channel update" command to update the channel configuration block
   echo '{"payload":{"header":{"channel_header":{"channel_id":"'"${CHANNEL_NAME}"'", "type":2}},"data":{"config_update":'$(cat config_update.json)'}}}' > config_update_as_envelope.json
   curl -X POST --data-binary @config_update_as_envelope.json $CTLURL/protolator/encode/common.Envelope > $CONFIG_UPDATE_ENVELOPE_FILE

   # Stop configtxlator
   kill $configtxlator_pid
   popd
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
   log $* >> $RUN_SUMPATH
}

function fatalr {
   logr "FATAL: $*"
   exit 1
}

$1