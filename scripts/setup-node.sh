#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# This script does the following:
# 1) registers orderer and peer identities with intermediate fabric-ca-servers
# 2) Builds genesis block
#
SRC=$(dirname "$0")
source $SRC/make-config-tx.sh

function setupOrderer {
   source $SRC/env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS
   log "Beginning building channel artifacts ..."
   mkdir -p /${COMMON}/crypto${RANDOM_NUMBER}
   mkdir -p $ORDERER_GENERAL_LOCALMSPDIR
   registerOrdererIdentities
   getCACerts
   genClientTLSCert $ORDERER_NAME $ORDERER_GENERAL_TLS_CERTIFICATE $ORDERER_GENERAL_TLS_PRIVATEKEY
   genClientTLSCert $ORDERER_NAME $CORE_ORDERER_TLS_CLIENTCERT_FILE $CORE_ORDERER_TLS_CLIENTKEY_FILE 
   enroll $ORDERER_GENERAL_LOCALMSPDIR
   sleep 15
   makeConfigTxYaml /${COMMON}/crypto${RANDOM_NUMBER}
   generateGenesisBlock
}

function setupPeer {
   source $SRC/env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS
   log "Setting up peer ..."
   mkdir -p $CORE_PEER_MSPCONFIGPATH
   mkdir -p /${COMMON}/tls
   registerPeerIdentities
   getCACerts
   genClientTLSCert $PEER_NAME $CORE_PEER_TLS_CERT_FILE $CORE_PEER_TLS_KEY_FILE
   genClientTLSCert $PEER_NAME /${COMMON}/tls/$PEER_NAME-client.crt /${COMMON}/tls/$PEER_NAME-client.key
   genClientTLSCert $PEER_NAME /${COMMON}/tls/$PEER_NAME-cli-client.crt /${COMMON}/tls/$PEER_NAME-cli-client.key
   enroll $CORE_PEER_MSPCONFIGPATH
}

# Enroll to get an enrollment certificate and set up the core's local MSP directory
function enroll {
   fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $1
   finishMSPSetup $1
   copyAdminCert $1
}

# Enroll the CA administrator
function enrollCAAdmin {
   waitPort "$CA_NAME to start" 90 $CA_LOGFILE $CA_HOST 7054
   log "Enrolling with $CA_NAME as bootstrap identity ..."
   fabric-ca-client enroll -d -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054
   log "Enrolling with $CA_NAME identity DONE"
}

# Register any identities associated with the orderer
function registerOrdererIdentities {
   ERROR_CODE="Error Code: 63"
   initOrdererVars $ORGANIZATION $COUNT
   enrollCAAdmin

   if [[ $(fabric-ca-client identity list --id $ORDERER_NAME 2>&1) == *"$ERROR_CODE"* ]]; then
      log "Registering $ORDERER_NAME with $CA_NAME"
      fabric-ca-client register -d --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer
   fi

   if [[ $(fabric-ca-client identity list --id $ADMIN_NAME 2>&1) == *"$ERROR_CODE"* ]]; then
      log "Registering admin identity with $CA_NAME"
      # The admin identity has the "admin" attribute which is added to ECert by default
      fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "admin=true:ecert"
   fi
}

# Register any identities associated with a peer
function registerPeerIdentities {
   ERROR_CODE="Error Code: 63"
   initPeerVars $ORGANIZATION $COUNT
   enrollCAAdmin
   set -x

   sleep $((COUNT*COUNT))
   if [[ $(fabric-ca-client identity list --id $PEER_NAME 2>&1) == *"$ERROR_CODE"* ]]; then
      log "Registering $PEER_NAME with $CA_NAME"
      fabric-ca-client register -d --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer
   fi

   # The admin identity has the "admin" attribute which is added to ECert by default
   sleep $((COUNT*COUNT))
   if [[ $(fabric-ca-client identity list --id $ADMIN_NAME 2>&1) == *"$ERROR_CODE"* ]]; then
      log "Registering admin identity with $ADMIN_NAME"
      ATTRS="hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
      fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs $ATTRS
   fi

   sleep $((COUNT*COUNT))
   if [[ $(fabric-ca-client identity list --id $USER_NAME 2>&1) == *"$ERROR_CODE"* ]]; then
      log "Registering user identity with $USER_NAME"
      fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS
   fi
   set +x
}

function getCACerts {
   log "Getting CA certificates ..."
   initOrgVars $ORGANIZATION
   log "Getting CA certs for organization $ORGANIZATION and storing in $ORG_MSP_DIR"
   export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
   fabric-ca-client getcacert -d -u https://$CA_HOST:7054 -M $ORG_MSP_DIR
   finishMSPSetup $ORG_MSP_DIR
   # If ADMINCERTS is true, we need to enroll the admin now to populate the admincerts directory
   if [ $ADMINCERTS ]; then
      set -x
      switchToAdminIdentity
      set +x
   fi
}

function generateGenesisBlock {
   which configtxgen
   if [ "$?" -ne 0 ]; then
      fatal "configtxgen tool not found. exiting"
   fi

   log "Generating orderer genesis block at $GENESIS_BLOCK_FILE"
   # Note: For some unknown reason (at least for now) the block file can't be
   # named orderer.genesis.block or the orderer will fail to launch!
   set -x
   configtxgen -profile ${ORG_ORDERER_GENESIS} -outputBlock $GENESIS_BLOCK_FILE
   set +x
   if [ "$?" -ne 0 ]; then
      fatal "Failed to generate orderer genesis block"
   fi
}

$1
