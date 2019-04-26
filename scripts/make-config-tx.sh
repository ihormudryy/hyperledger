#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

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
    mkdir -p $1
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

  ${ORG_ORDERER_GENESIS}:
    Orderer:
      # Orderer Type: The orderer implementation to start
      # Available types are \"solo\" and \"kafka\"
      OrdererType: ${ORDERER_TYPE}
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
  ${ORGS_PROFILE}:
    Consortium: SampleConsortium
    Application:
      <<: *ApplicationDefaults
      Organizations:"

   for ORG in $PEER_ORGS; do
      initOrgVars $ORG
      echo "        - *${ORG_CONTAINER_NAME}"
   done

   } > $1/configtx.yaml
   cp $1/configtx.yaml /etc/hyperledger/fabric/
}

export -f makeConfigTxYaml