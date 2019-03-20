#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# This script does the following:
# 1) registers orderer and peer identities with intermediate fabric-ca-servers
# 2) Builds the channel artifacts (e.g. genesis block, etc)
#
SRC=$(dirname "$0")
source $SRC/env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS

function setupOrderer {
   log "Beginning building channel artifacts ..."
   mkdir -p /${COMMON}/crypto${RANDOM_NUMBER}
   mkdir -p $ORDERER_GENERAL_LOCALMSPDIR
   registerOrdererIdentities
   getCACerts
   genClientTLSCert $ORDERER_NAME $ORDERER_GENERAL_TLS_CERTIFICATE $ORDERER_GENERAL_TLS_PRIVATEKEY
   genClientTLSCert $ORDERER_NAME $CORE_ORDERER_TLS_CLIENTCERT_FILE $CORE_ORDERER_TLS_CLIENTKEY_FILE 
   enroll $ORDERER_GENERAL_LOCALMSPDIR
   sleep 10
   makeConfigTxYaml
   generateChannelArtifacts
}

function setupPeer {
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

function enroll {
   # Enroll to get an enrollment certificate and set up the core's local MSP directory
   fabric-ca-client enroll -d -u $ENROLLMENT_URL -M $1
   finishMSPSetup $1
   copyAdminCert $1
}

# Enroll the CA administrator
function enrollCAAdmin {
   waitPort "$CA_NAME to start" 90 $CA_LOGFILE $CA_HOST 7054
   log "Enrolling with $CA_NAME as bootstrap identity ..."
   fabric-ca-client enroll -d -u https://$CA_ADMIN_USER_PASS@$CA_HOST:7054
}

# Register any identities associated with the orderer
function registerOrdererIdentities {
   initOrdererVars $ORGANIZATION $COUNT
   enrollCAAdmin
   log "Registering $ORDERER_NAME with $CA_NAME"
   fabric-ca-client register -d --id.name $ORDERER_NAME --id.secret $ORDERER_PASS --id.type orderer
   log "Registering admin identity with $CA_NAME"
   # The admin identity has the "admin" attribute which is added to ECert by default
   fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "admin=true:ecert"
}

# Register any identities associated with a peer
function registerPeerIdentities {
   initOrgVars $ORGANIZATION
   enrollCAAdmin
   initPeerVars $ORGANIZATION $COUNT
   log "Registering $PEER_NAME with $CA_NAME"
   fabric-ca-client register -d --id.name $PEER_NAME --id.secret $PEER_PASS --id.type peer
   log "Registering admin identity with $CA_NAME"
   # The admin identity has the "admin" attribute which is added to ECert by default
   fabric-ca-client register -d --id.name $ADMIN_NAME --id.secret $ADMIN_PASS --id.attrs "hf.Registrar.Roles=client,hf.Registrar.Attributes=*,hf.Revoker=true,hf.GenCRL=true,admin=true:ecert,abac.init=true:ecert"
   log "Registering user identity with $CA_NAME"
   fabric-ca-client register -d --id.name $USER_NAME --id.secret $USER_PASS
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
      switchToAdminIdentity
   fi
}

# printOrg
function printOrg {
   echo "
  - &$ORG_CONTAINER_NAME

    Name: $ORG_CONTAINER_NAME

    # ID to load the MSP definition as
    ID: $ORG_MSP_ID

    # MSPDir is the filesystem path which contains the MSP configuration
    MSPDir: $ORG_MSP_DIR"
}

# printOrdererOrg <ORG>
function printOrdererOrg {
   initOrgVars $1
   printOrg
}

# printPeerOrg <ORG> <COUNT>
function printPeerOrg {
   initPeerVars $1 $2
   printOrg
   echo "
    AnchorPeers:
       # AnchorPeers defines the location of peers which can be used
       # for cross org gossip communication.  Note, this value is only
       # encoded in the genesis block in the Application section context
       - Host: $PEER_HOST
         Port: 7051"
}

function makeConfigTxYaml {
   {
   echo "
################################################################################
#
#   Section: Organizations
#
#   - This section defines the different organizational identities which will
#   be referenced later in the configuration.
#
################################################################################
Organizations:"

   for ORG in $ORDERER_ORGS; do
      printOrdererOrg $ORG
   done

   for ORG in $PEER_ORGS; do
      printPeerOrg $ORG 1
   done

   echo "
################################################################################
#
#   SECTION: Application
#
#   This section defines the values to encode into a config transaction or
#   genesis block for application related parameters
#
################################################################################
Application: &ApplicationDefaults

    # Organizations is the list of orgs which are defined as participants on
    # the application side of the network
    Organizations:
    
    # Policies defines the set of policies at this level of the config tree
    # For Application policies, their canonical path is
    #   /Channel/Application/<PolicyName>
    Policies:
        Readers:
            Type: ImplicitMeta
            Rule: "ANY Readers"
        Writers:
            Type: ImplicitMeta
            Rule: "ANY Writers"
        Admins:
            Type: ImplicitMeta
            Rule: "MAJORITY Admins"
"
   echo "
################################################################################
#
#   Profile
#
#   - Different configuration profiles may be encoded here to be specified
#   as parameters to the configtxgen tool
#
################################################################################
Profiles:

  OrgsOrdererGenesis:
    Orderer:
      # Orderer Type: The orderer implementation to start
      # Available types are \"solo\" and \"kafka\"
      OrdererType: $ORDERER_TYPE
      Addresses:"

   for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $COUNT
         echo "        - $ORDERER_HOST:7050"
         COUNT=$((COUNT+1))
      done
   done

   echo "
      # Batch Timeout: The amount of time to wait before creating a batch
      BatchTimeout: 2s

      # Batch Size: Controls the number of messages batched into a block
      BatchSize:

        # Max Message Count: The maximum number of messages to permit in a batch
        MaxMessageCount: 10

        # Absolute Max Bytes: The absolute maximum number of bytes allowed for
        # the serialized messages in a batch.
        AbsoluteMaxBytes: 99 MB

        # Preferred Max Bytes: The preferred maximum number of bytes allowed for
        # the serialized messages in a batch. A message larger than the preferred
        # max bytes will result in a batch larger than preferred max bytes.
        PreferredMaxBytes: 512 KB

      Kafka:
        # Brokers: A list of Kafka brokers to which the orderer connects
        # NOTE: Use IP:port notation
        Brokers:"
   for ORG in $ORDERER_ORGS; do
      local COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $COUNT
         echo "        - kafka.${ORDERER_HOST}:9092"
         echo "        - kafka.${ORDERER_HOST}:9093"
         COUNT=$((COUNT+1))
      done
   done
   echo "
      # Organizations is the list of orgs which are defined as participants on
      # the orderer side of the network
      Organizations:"

   for ORG in $ORDERER_ORGS; do
      initOrgVars $ORG
      echo "        - *${ORG_CONTAINER_NAME}"
   done

   echo "
    Consortiums:

      SampleConsortium:

        Organizations:"

   for ORG in $PEER_ORGS; do
      initOrgVars $ORG
      echo "          - *${ORG_CONTAINER_NAME}"
   done

   echo "
  OrgsChannel:
    Consortium: SampleConsortium
    Application:
      <<: *ApplicationDefaults
      Organizations:"

   for ORG in $PEER_ORGS; do
      initOrgVars $ORG
      echo "        - *${ORG_CONTAINER_NAME}"
   done

   } > /${COMMON}/crypto${RANDOM_NUMBER}/configtx.yaml
   # Copy it to the data directory to make debugging easier
   cp /${COMMON}/crypto${RANDOM_NUMBER}/configtx.yaml /etc/hyperledger/fabric/
}

function generateChannelArtifacts() {
  which configtxgen
  if [ "$?" -ne 0 ]; then
    fatal "configtxgen tool not found. exiting"
  fi

  log "Generating orderer genesis block at $GENESIS_BLOCK_FILE"
  # Note: For some unknown reason (at least for now) the block file can't be
  # named orderer.genesis.block or the orderer will fail to launch!
  configtxgen -profile OrgsOrdererGenesis -outputBlock $GENESIS_BLOCK_FILE
  if [ "$?" -ne 0 ]; then
    fatal "Failed to generate orderer genesis block"
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

set -e

$1
