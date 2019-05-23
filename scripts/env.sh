#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# Requires 3 parameters:
# 1. Orderer name
# 2. List of organizations names separated by space
# 3. Number of peers

# The following variables describe the topology and may be modified to provide
# different organization names or the number of peers in each peer organization.
#

export COMPOSE_PROJECT_NAME="net"

# Name of the docker-compose network
export NETWORK="fabric-ca"
export SUBNET="172.16.0.0/24"

# Names and types of the orderer organizations
export ORDERER_ORGS="$1"
export ORDERER_TYPE="kafka"

# Names of the peer organizations
export PEER_ORGS="$2"

# Number of peers in each peer organization
export NUM_PEERS="$3"

export EXPLORER_DB_USER="hppoc"
export EXPLORER_DB_PWD="password"
export EXPLORER_DB_NAME="fabricexplorer"

#
# The remainder of this file contains variables which typically would not be changed.
#

# All org names
export ORGS="$ORDERER_ORGS $PEER_ORGS"

# Set to true to populate the "admincerts" folder of MSPs
export ADMINCERTS=true

# Number of orderer nodes
export NUM_ORDERERS=1

# The volume mount to share data between containers
export COMMON=private

# Log directory
export LOGDIR=/logs

# The path to the genesis block
export GENESIS_BLOCK_FILE=/${COMMON}/crypto${RANDOM_NUMBER}/genesis.block

# The path to a channel transaction
export CHANNEL_TX_FILE=/${COMMON}/crypto${RANDOM_NUMBER}/channel${RANDOM_NUMBER}.tx

# Name of test channel
export CHANNEL_NAME="channel${RANDOM_NUMBER}"

# Block name
export BLOCK_FILE=/${COMMON}/crypto${RANDOM_NUMBER}/${CHANNEL_NAME}.block

export ORGS_PROFILE="OrgsChannel"
export ORG_ORDERER_GENESIS="OrgsOrdererGenesis"

# Query timeout in seconds
export QUERY_TIMEOUT=30

# Setup timeout in seconds (for setup container to complete)
export SETUP_TIMEOUT=120

# Name of a the file to create when setup is successful
export SETUP_SUCCESS_FILE=${LOGDIR}/setup.successful
# The setup container's log file
export SETUP_LOGFILE=${LOGDIR}/setup.log

# The run container's log file
export RUN_LOGFILE=${LOGDIR}/run.log

# The run container's summary log file
export RUN_SUMqFILE=${LOGDIR}/run.sum
export RUN_SUMPATH="${RUN_SUMFILE}"

# Run success and failure files
export RUN_SUCCESS_FILE=${LOGDIR}/run.success
export RUN_FAIL_FILE=${LOGDIR}/run.fail

# Affiliation is not used to limit users in this sample, so just put
# all identities in the same affiliation.
export FABRIC_CA_CLIENT_ID_AFFILIATION=${ORDERER_ORGS}

# Set to true to enable use of intermediate CAs
export USE_INTERMEDIATE_CA=true

# Config block file path
export CONFIG_BLOCK_FILE=/tmp/config_block.pb

# Update config block payload file path
export CONFIG_UPDATE_ENVELOPE_FILE=/tmp/config_update_as_envelope.pb

# initOrgVars <ORG>
function initOrgVars {
   if [ $# -ne 1 ]; then
      echo "Usage: initOrgVars <ORG>"
      exit 1
   fi
   ORG=$1
   ANCHOR_TX_FILE=/${COMMON}/orgs/${ORG}/anchors.tx
   ORG_CONTAINER_NAME=${ORG//./-}
   ROOT_CA_HOST=rca.${ORG}.com
   ROOT_CA_NAME=rca.${ORG}.com
   ROOT_CA_LOGFILE=$LOGDIR/${ROOT_CA_NAME}.log
   INT_CA_HOST=ica.${ORG}.com
   INT_CA_NAME=ica.${ORG}.com
   INT_CA_LOGFILE=$LOGDIR/${INT_CA_NAME}.log

   # Root CA admin identity
   ROOT_CA_ADMIN_USER=rca-${ORG}-admin
   ROOT_CA_ADMIN_PASS=${ROOT_CA_ADMIN_USER}pw
   ROOT_CA_ADMIN_USER_PASS=${ROOT_CA_ADMIN_USER}:${ROOT_CA_ADMIN_PASS}
   # Root CA intermediate identity to bootstrap the intermediate CA
   ROOT_CA_INT_USER=ica-${ORG}
   ROOT_CA_INT_PASS=${ROOT_CA_INT_USER}pw
   ROOT_CA_INT_USER_PASS=${ROOT_CA_INT_USER}:${ROOT_CA_INT_PASS}
   # Intermediate CA admin identity
   INT_CA_ADMIN_USER=ica-${ORG}-admin
   INT_CA_ADMIN_PASS=${INT_CA_ADMIN_USER}pw
   INT_CA_ADMIN_USER_PASS=${INT_CA_ADMIN_USER}:${INT_CA_ADMIN_PASS}
   # Admin identity for the org
   ADMIN_NAME=admin
   ADMIN_PASS=${ADMIN_NAME}pw
   # Typical user identity for the org
   USER_NAME=user
   USER_PASS=${USER_NAME}pw

   ROOT_CA_CERTFILE=/${COMMON}/${ORG}-ca-cert.pem
   INT_CA_CHAINFILE=/${COMMON}/${ORG}-ca-chain.pem
   ORG_MSP_ID=${ORG}MSP
   ORG_MSP_DIR=/${COMMON}/orgs/${ORG}/msp
   ORG_ADMIN_CERT=${ORG_MSP_DIR}/admincerts/cert.pem
   ORG_ADMIN_HOME=/${COMMON}/orgs/${ORG}/${ADMIN_NAME}
   ORG_USER_HOME=/${COMMON}/orgs/${ORG}/${USER_NAME}
   if test "$USE_INTERMEDIATE_CA" = "true"; then
      CA_NAME=$INT_CA_NAME
      CA_HOST=$INT_CA_HOST
      CA_CHAINFILE=$INT_CA_CHAINFILE
      CA_ADMIN_USER_PASS=$INT_CA_ADMIN_USER_PASS
      CA_LOGFILE=$INT_CA_LOGFILE
   else
      CA_NAME=$ROOT_CA_NAME
      CA_HOST=$ROOT_CA_HOST
      CA_CHAINFILE=$ROOT_CA_CERTFILE
      CA_ADMIN_USER_PASS=$ROOT_CA_ADMIN_USER_PASS
      CA_LOGFILE=$ROOT_CA_LOGFILE
   fi
}

# initOrdererVars <NUM>
function initOrdererVars {
   if [ $# -ne 2 ]; then
      echo "Usage: initOrdererVars <ORG> <NUM>"
      exit 1
   fi
   COUNT=$2
   initOrgVars $1
   ORG=$1
   NUM=$2
   ORDERER_HOST=orderer${NUM}.${ORG}.org
   ORDERER_NAME=orderer${NUM}.${ORG}.org
   ORDERER_PASS=${ORDERER_NAME}pw
   ORDERER_NAME_PASS=${ORDERER_NAME}:${ORDERER_PASS}
   ORDERER_LOGFILE=$LOGDIR/${ORDERER_NAME}.log
   export FABRIC_CA_CLIENT=$ORDERER_HOME
   export ORDERER_GENERAL_LOGLEVEL=debug
   export ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
   export ORDERER_GENERAL_GENESISMETHOD=file
   export ORDERER_GENERAL_GENESISFILE=$GENESIS_BLOCK_FILE
   export ORDERER_GENERAL_LOCALMSPID=$ORG_MSP_ID
   # enabled TLS
   export ORDERER_GENERAL_TLS_ENABLED=true
   export TLSDIR=$ORDERER_HOME/tls
   export ORDERER_GENERAL_TLS_PRIVATEKEY=$TLSDIR/server.key
   export ORDERER_GENERAL_TLS_CERTIFICATE=$TLSDIR/server.crt
   export ORDERER_GENERAL_TLS_ROOTCAS=$CA_CHAINFILE
   export CORE_ORDERER_TLS_CERT_FILE=/${COMMON}/tls/$ORDERER_NAME-client.crt
   export CORE_ORDERER_TLS_KEY_FILE=/${COMMON}/tls/$ORDERER_NAME-client.key
   export CORE_ORDERER_TLS_CLIENTCERT_FILE=/${COMMON}/tls/$ORDERER_NAME-cli-client.crt
   export CORE_ORDERER_TLS_CLIENTKEY_FILE=/${COMMON}/tls/$ORDERER_NAME-cli-client.key
   export ORDERER_PORT_ARGS="-o $ORDERER_HOST:7050 \
   --tls --cafile $CA_CHAINFILE \
   --clientauth"
   export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS \
   --keyfile $CORE_ORDERER_TLS_CLIENTKEY_FILE \
   --certfile $CORE_ORDERER_TLS_CLIENTCERT_FILE"
}

function genClientTLSCert {
   if [ $# -ne 3 ]; then
      echo "Usage: genClientTLSCert <host name> <cert file> <key file>: $*"
      exit 1
   fi
   HOST_NAME=$1
   CERT_FILE=$2
   KEY_FILE=$3
   # Get a client cert
   fabric-ca-client enroll -d --enrollment.profile tls -u $ENROLLMENT_URL -M /tmp/tls --csr.hosts $HOST_NAME
   # Copy the TLS key and cert to the appropriate place
   mkdir -p $TLSDIR
   mv /tmp/tls/keystore/* $KEY_FILE
   mv /tmp/tls/signcerts/* $CERT_FILE
   rm -rf /tmp/tls/*
}

# initPeerVars <ORG> <NUM>
function initPeerVars {
   if [ $# -ne 2 ]; then
      echo "Usage: initPeerVars <ORG> <NUM>: $*"
      exit 1
   fi
   COUNT=$2
   initOrgVars $1
   NUM=$2
   PEER_HOST=peer${NUM}.${ORG}.com
   PEER_NAME=peer${NUM}.${ORG}.com
   PEER_PASS=${PEER_NAME}pw
   PEER_NAME_PASS=${PEER_NAME}:${PEER_PASS}
   PEER_LOGFILE=$LOGDIR/${PEER_NAME}.log
   export TLSDIR=$PEER_HOME/tls
   export FABRIC_CA_CLIENT=$FABRIC_CA_CLIENT_HOME
   export CORE_PEER_ID=$PEER_HOST
   export CORE_PEER_ADDRESS=$PEER_HOST:7051
   export CORE_PEER_LOCALMSPID=$ORG_MSP_ID
   export CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
   # the following setting starts chaincode containers on the same
   # bridge network as the peers
   # https://docs.docker.com/compose/networking/
   export CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=net_${NETWORK}
   export FABRIC_LOGGING_SPEC=INFO
   export CORE_PEER_TLS_ENABLED=true
   export CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
   export CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE
   export CORE_PEER_TLS_CLIENTCERT_FILE=$TLSDIR/$PEER_NAME-cli-client.crt
   export CORE_PEER_TLS_CLIENTKEY_FILE=$TLSDIR/$PEER_NAME-cli-client.key
   export CORE_PEER_PROFILE_ENABLED=true
   # gossip variables
   export CORE_PEER_GOSSIP_USELEADERELECTION=true
   export CORE_PEER_GOSSIP_ORGLEADER=false
   export CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_HOST:7051
   if [ $NUM -gt 1 ]; then
      # Point the non-anchor peers to the anchor peer, which is always the 1st peer
      export CORE_PEER_GOSSIP_BOOTSTRAP=peer1.${ORG}.com:7051
   fi
   export ORDERER_CONN_ARGS="$ORDERER_PORT_ARGS \
   --keyfile $CORE_PEER_TLS_CLIENTKEY_FILE \
   --certfile $CORE_PEER_TLS_CLIENTCERT_FILE"
}

function registerNewUser {
   set -xe
   echo "CORE_PEER_TLS_CLIENTCERT_FILE is $CORE_PEER_TLS_CLIENTCERT_FILE"
   fabric-ca-client register \
      -d --id.name $2 --id.secret $3 \
      -H $1 \
      -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054 \
      --tls.certfiles $INT_CA_CHAINFILE \
      --tls.client.certfile $CORE_PEER_TLS_CLIENTCERT_FILE \
      --tls.client.keyfile $CORE_PEER_TLS_CLIENTKEY_FILE
   set +xe
}

function ennrollNewUser {
   export FABRIC_CA_CLIENT_HOME=$1
   export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
   dowait "$CA_NAME to start" 60 $CA_LOGFILE $CA_CHAINFILE
   log "Enrolling user/admin for organization $CA_HOST with home directory $FABRIC_CA_CLIENT_HOME ..."
   set -xe
   fabric-ca-client enroll \
      -H $FABRIC_CA_CLIENT_HOME \
      -d \
      -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054
   set +xe

   if [ $ADMINCERTS ]; then
      ACDIR=$CORE_PEER_MSPCONFIGPATH/admincerts
      mkdir -p $ACDIR
      mkdir -p $(dirname "${ORG_ADMIN_CERT}")
      mkdir -p $FABRIC_CA_CLIENT_HOME/msp/admincerts
      mkdir -p $CORE_PEER_MSPCONFIGPATH/admincerts
      cp $ORG_ADMIN_HOME/msp/signcerts/* $ORG_ADMIN_CERT
      cp $ORG_ADMIN_HOME/msp/signcerts/* $ORG_ADMIN_HOME/msp/admincerts
      cp $FABRIC_CA_CLIENT_HOME/msp/signcerts/* $CORE_PEER_MSPCONFIGPATH/admincerts
      cp $ORG_ADMIN_HOME/msp/signcerts/* $ACDIR
   fi
 
}

# Switch to the current org's admin identity. Enroll if not previously enrolled.
function switchToAdminIdentity {
   export FABRIC_CA_CLIENT_HOME=$ORG_ADMIN_HOME
   export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
   if [ ! -d $ORG_ADMIN_HOME ]; then
      ennrollNewUser $ORG_ADMIN_HOME $ADMIN_NAME $ADMIN_PASS
   fi
}

# Switch to the current org's user identity.  Enroll if not previously enrolled.
function switchToUserIdentity {
   export FABRIC_CA_CLIENT_HOME=$ORG_USER_HOME
   export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
   if [ ! -d $ORG_USER_HOME ]; then
      ennrollNewUser $ORG_USER_HOME $USER_NAME $USER_PASS
   fi
}

# Revokes the fabric user
function revokeFabricUserAndGenerateCRL {
   switchToAdminIdentity
   export  FABRIC_CA_CLIENT_HOME=$ORG_ADMIN_HOME
   logr "Revoking the user '$USER_NAME' of the organization '$ORG' with Fabric CA Client home directory set to $FABRIC_CA_CLIENT_HOME and generating CRL ..."
   export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
   fabric-ca-client revoke -d --revoke.name $USER_NAME --gencrl
}

# Generates a CRL that contains serial numbers of all revoked enrollment certificates.
# The generated CRL is placed in the crls folder of the admin's MSP
function generateCRL {
   switchToAdminIdentity
   export FABRIC_CA_CLIENT_HOME=$ORG_ADMIN_HOME
   logr "Generating CRL for the organization '$ORG' with Fabric CA Client home directory set to $FABRIC_CA_CLIENT_HOME ..."
   export FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
   fabric-ca-client gencrl -d
}

# Copy the org's admin cert into some target MSP directory
# This is only required if ADMINCERTS is enabled.
function copyAdminCert {
   if [ $# -ne 1 ]; then
      fatal "Usage: copyAdminCert <targetMSPDIR>"
   fi
   if $ADMINCERTS; then
      dowait "$ORGANIZATION administator to enroll" 60 $SETUP_LOGFILE $ORG_ADMIN_CERT
      mkdir -p $1/admincerts
      cp $ORG_ADMIN_CERT $1/admincerts
   fi
}

# Create the TLS directories of the MSP folder if they don't exist.
# The fabric-ca-client should do this.
function finishMSPSetup {
   if [ $# -ne 1 ]; then
      fatal "Usage: finishMSPSetup <targetMSPDIR>"
   fi

   if [ ! -d $1/tlscacerts ]; then
      mkdir -p $1/tlscacerts
      cp $1/cacerts/* $1/tlscacerts
      if [ -d $1/intermediatecerts ]; then
         mkdir -p $1/tlsintermediatecerts
         cp $1/intermediatecerts/* $1/tlsintermediatecerts
      fi
   fi
}

function awaitSetup {
   dowait "the 'setup' container to finish registering identities, creating the genesis block and other artifacts" $SETUP_TIMEOUT $SETUP_LOGFILE /$SETUP_SUCCESS_FILE
}

# Wait for one or more files to exist
# Usage: dowait <what> <timeoutInSecs> <errorLogFile> <file> [<file> ...]
function dowait {
   if [ $# -lt 4 ]; then
      fatal "Usage: dowait: $*"
   fi
   local what=$1
   local secs=$2
   local logFile=$3
   shift 3
   local logit=true
   local starttime=$(date +%s)
   for file in $*; do
      until [ -f $file ]; do
         if [ "$logit" = true ]; then
            log -n "Waiting for $what ..."
            logit=false
         fi
         sleep 1
         if [ "$(($(date +%s)-starttime))" -gt "$secs" ]; then
            echo ""
            fatal "Failed waiting for $what ($file not found); see $logFile"
         fi
         echo -n "."
      done
   done
   echo ""
}

# Wait for a process to begin to listen on a particular host and port
# Usage: waitPort <what> <timeoutInSecs> <errorLogFile> <host> <port>
function waitPort {
   set +e
   local what=$1
   local secs=$2
   local logFile=$3
   local host=$4
   local port=$5
   nc -z $host $port > /dev/null 2>&1
   if [ $? -ne 0 ]; then
      log -n "Waiting for $what ..."
      local starttime=$(date +%s)
      while true; do
         sleep 1
         nc -z $host $port > /dev/null 2>&1
         if [ $? -eq 0 ]; then
            break
         fi
         if [ "$(($(date +%s)-starttime))" -gt "$secs" ]; then
            fatal "Failed waiting for $what; see $logFile"
         fi
         echo -n "."
      done
      echo ""
   fi
   set -e
}

# log a message
function log {
   if [ "$1" = "-n" ]; then
      shift
      echo -n "##### `date '+%Y-%m-%d %H:%M:%S'` $*"
   else
      echo "##### `date '+%Y-%m-%d %H:%M:%S'` $*"
   fi
}

# fatal a message
function fatal {
   log "FATAL: $*"
   exit 1
}

export -f initOrgVars
export -f initOrdererVars
export -f genClientTLSCert
export -f initPeerVars
export -f switchToAdminIdentity
export -f switchToUserIdentity
export -f revokeFabricUserAndGenerateCRL
export -f generateCRL
export -f copyAdminCert
export -f finishMSPSetup
export -f awaitSetup
export -f dowait
export -f waitPort
export -f log
export -f fatal