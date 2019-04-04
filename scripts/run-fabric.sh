#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

SRC=$(dirname "$0")
source $SRC/env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS
source $SRC/make-config-tx.sh
LOG_FILE_NAME=${LOGDIR}/chaincode-${CHAINCODE_NAME}-install.log

function testABAC {
   createChannel
   for ORG in $PEER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         joinChannel $ORG $COUNT
         installChaincode $ORG $COUNT
         instantiateChaincode $ORG $COUNT '{"Args":["init","a","100","b","200"]}'
         chaincodeQuery $ORG $COUNT '{"Args":["query","a"]}' 100
         #invokeChaincode $ORG $COUNT '{"Args":["invoke","a","b","10"]}'
         #chaincodeQuery $ORG $COUNT '{"Args":["query","a"]}' 90
         COUNT=$((COUNT+1))
      done
   done
   
   # Query chaincode from the 1st peer of the 1st org
   #updateChannel ${PORGS[0]} 1
   logr "Congratulations! The tests ran successfully."
}

function addAffiliation {
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   initOrgVars $ORDERER_ORGS

   initPeerVars ${PORGS[0]} 1
   switchToAdminIdentity
   set -x
   #export CORE_PEER_MSPCONFIGPATH=/${COMMON}/orgs/${1}/msp
   #export ORG_ADMIN_HOME=/${COMMON}/orgs/${1}
   #export FABRIC_CA_CLIENT_HOME=$ORG_ADMIN_HOME
   fabric-ca-client enroll -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054 -M /${COMMON}/orgs/${1}/admin/msp
   fabric-ca-client affiliation add $1 -d \
      -M /${COMMON}/orgs/${1}/admin/msp \
      -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054 \
      --tls.client.certfile $CORE_ORDERER_TLS_CLIENTCERT_FILE \
      --tls.client.keyfile $CORE_ORDERER_TLS_CLIENTKEY_FILE \
      --tls.certfiles $INT_CA_CHAINFILE
   set +x
}

function updateChannelConfig {
   set -x
   fetchConfigBlock $1 $2
   createConfigUpdatePayload $3 $2
   updateConfigBlock $1 $2
}

# Enroll as a peer admin and create the channel
function createChannel {
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   initPeerVars ${PORGS[0]} 1
   switchToAdminIdentity
   makeConfigTxYaml /${COMMON}
   generateChannelTx ${PORGS[0]}
   export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
   logr "Creating channel '$CHANNEL_NAME' on $ORDERER_HOST ..."
   peer channel create -c $CHANNEL_NAME -f $CHANNEL_TX_FILE $ORDERER_CONN_ARGS --outputBlock $BLOCK_FILE
}

# Enroll as a fabric admin and join the channel
function joinChannel {
   if [ $# -ne 2 ]; then
      fatalr "Usage: joinChannel <ORG> <NUM>"
   fi

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
      peer channel list
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

   ORG=$1

   log "Generating channel configuration transaction at $CHANNEL_TX_FILE"
   configtxgen -profile ${ORGS_PROFILE} \
      -outputCreateChannelTx $CHANNEL_TX_FILE \
      -channelID $CHANNEL_NAME

   if [ "$?" -ne 0 ]; then
      fatal "Failed to generate channel configuration transaction"
   fi

   for ORG in $PEER_ORGS; do
      initOrgVars $ORG
      log "Generating anchor peer update transaction for $ORG at $ANCHOR_TX_FILE"
      configtxgen -profile ${ORGS_PROFILE} \
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
   peer channel fetch config $CONFIG_BLOCK_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}

function updateConfigBlock {
   logr "Updating the configuration block of the channel '$CHANNEL_NAME'"
   logr "Fetching the configuration block of the channel '$CHANNEL_NAME'"
   IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
   initOrdererVars ${OORGS[0]} 1
   IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
   initPeerVars $1 $2
   switchToUserIdentity $1
   peer channel update -f $CONFIG_UPDATE_ENVELOPE_FILE -c $CHANNEL_NAME $ORDERER_CONN_ARGS
}

function createConfigUpdatePayload {
   ORG=$1
   PATH_PREFIX=/tmp
   
   configtxgen -printOrg $ORG > $PATH_PREFIX/$ORG.json

   configtxlator proto_decode \
      --input $CONFIG_BLOCK_FILE \
      --type common.Block | jq .data.data[0].payload.data.config > $PATH_PREFIX/config.json

   # Update crl in the config json
   initPeerVars $1 $2
   switchToAdminIdentity
   makeConfigTxYaml /${COMMON}
   generateChannelTx $1
   
   jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {'$ORG':.[1]}}}}}' \
   $PATH_PREFIX/config.json $PATH_PREFIX/$ORG.json > $PATH_PREFIX/updated_config.json

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
      export CORE_PEER_MSPCONFIGPATH=/${COMMON}/orgs/${ORGAN}/admin/msp
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
   log $* >> $RUN_SUMPATH
}

function fatalr {
   logr "FATAL: $*"
   exit 1
}

$1 $2 $3 $4