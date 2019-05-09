#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#
# This script builds the docker compose file needed to run this sample.
#

# IMPORTANT: The following default FABRIC_TAG value should be updated for each
# release after the fabric-orderer and fabric-peer images have been published
# for the release.
export FABRIC_TAG=${FABRIC_TAG:-1.4.0}
export FABRIC_CA_TAG=${FABRIC_CA_TAG:-0.4.14}

export NS=${NS:-hyperledger}
#export MARCH=$(echo "$(uname -s|tr '[:upper:]' '[:lower:]'|sed 's/mingw64_nt.*/windows/')-$(uname -m | sed 's/x86_64/amd64/g')" | awk '{print tolower($0)}')
export MARCH="linux-amd64"
CA_BINARY_FILE=hyperledger-fabric-ca-${MARCH}-${FABRIC_TAG}.tar.gz
BINARY_FILE=hyperledger-fabric-${MARCH}-${FABRIC_TAG}.tar.gz
URL_CA="https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric-ca/hyperledger-fabric-ca/${MARCH}-${FABRIC_TAG}/${CA_BINARY_FILE}"
URL_FABRIC="https://nexus.hyperledger.org/content/repositories/releases/org/hyperledger/fabric/hyperledger-fabric/${MARCH}-${FABRIC_TAG}/${BINARY_FILE}"
SDIR=$(dirname "$0")
DOCKER_DIR="$SDIR/../docker"
SCRIPTS_DIR="./../scripts"
LOGS_DIR="./../logs"
COMMON_DIR="./../common"

# Set samples directory relative to this script
SAMPLES_DIR="./../chaincodes/"

function main {
   {
   createDockerFiles
   writeHeader
   writeRootFabricCA $ORGS
   if $USE_INTERMEDIATE_CA; then
      writeIntermediateFabricCA $ORGS
   fi
   writeStartFabric
   #writeBlockchainExplorer
   #writeHyperledgerComposer
   } > $DOCKER_DIR/docker-compose.yaml
   log "Created docker-compose.yaml"
}

function createFabricRunner {
   {
   createDockerFiles
   writeHeader
   writeSetupFabric
   } > $DOCKER_DIR/docker-compose-setup.yaml
   log "Created docker-compose-setup.yaml"
}

function createSingleOrganization {
   ORGANIZATION=$PEER_ORGS
   PEER_COUNT=$NUM_PEERS
   {
   createDockerFiles
   writeHeader
   initOrgVars $ORGANIZATION
   writeRootCA
   if $USE_INTERMEDIATE_CA; then
      writeIntermediateCA
   fi
   #initOrdererVars $ORDERER_ORGS 1
   #export COUNT=1
   COUNTER=1
   #writeOrderer
   while [[ "$COUNTER" -le $PEER_COUNT ]]; do
      initPeerVars $ORGANIZATION $COUNTER
      writePeer
      COUNTER=$((COUNTER+1))
   done
   } > $DOCKER_DIR/docker-compose-${ORGANIZATION}.yaml
   log "Created docker-compose-${ORGANIZATION}.yaml"
}

function createPeerDockerfile {
   createDockerFile peer "7051"
   PEER_BUILD="build:
   context: .
   dockerfile: fabric-ca-peer.dockerfile"
   createDockerFile tools "8888"
}

# Create various dockerfiles used by this sample
function createDockerFiles {
   if [ "$FABRIC_TAG" = "local" ]; then
      ORDERER_BUILD="image: hyperledger/fabric-ca-orderer"
      PEER_BUILD="image: hyperledger/fabric-ca-peer"
      TOOLS_BUILD="image: hyperledger/fabric-ca-tools"
   else
      createDockerFile orderer "7050"
      ORDERER_BUILD="build:
      context: .
      dockerfile: fabric-ca-orderer.dockerfile"
      createDockerFile peer "7051"
      PEER_BUILD="build:
      context: .
      dockerfile: fabric-ca-peer.dockerfile"
      createDockerFile tools "8888"
      TOOLS_BUILD="build:
      context: .
      dockerfile: fabric-ca-tools.dockerfile"
   fi
}

# createDockerFile
function createDockerFile {
   {
      echo "FROM ${NS}/fabric-${1}:${FABRIC_TAG}"
      echo 'RUN apt-get update && apt-get install -y netcat jq && apt-get install -y curl && rm -rf /var/cache/apt'
      echo "RUN curl -o /tmp/fabric-ca-client.tar.gz $URL_CA && tar -xzvf /tmp/fabric-ca-client.tar.gz -C /tmp && cp -r /tmp/bin/* /usr/local/bin"
      echo "RUN curl -o /tmp/fabric-client.tar.gz $URL_FABRIC && tar -xzvf /tmp/fabric-client.tar.gz -C /tmp && cp -r /tmp/bin/* /usr/local/bin"
      echo 'RUN chmod +x -R /usr/local/bin/*'
      echo 'ARG FABRIC_CA_DYNAMIC_LINK=true'
      echo "EXPOSE ${2}"
      echo 'RUN if [ "\$FABRIC_CA_DYNAMIC_LINK" = "true" ]; then apt-get install -y libltdl-dev; fi'
   } > $DOCKER_DIR/fabric-ca-${1}.dockerfile
}

# Write services for the root fabric CA servers
function writeRootFabricCA {
   for ORG in $ORGS; do
      initOrgVars $ORG
      writeRootCA
   done
}

# Write services for the intermediate fabric CA servers
function writeIntermediateFabricCA {
   for ORG in $ORGS; do
      initOrgVars $ORG
      writeIntermediateCA
   done
}

#Write a blockchain explorer service
function writeBlockchainExplorerService {
   echo "{
      \"network-configs\":{
         \"$NETWORK\": {
            \"version\": \"1.0\",
            \"clients\": {" > ${DOCKER_DIR}/config.json
   
   FIRST=true
   for ORG in $PEER_ORGS; do
      if [ $FIRST != true ]; then
         #echo "," >> ${DOCKER_DIR}/config.json
         echo "\"${ORG}\": {
            \"tlsEnable\": true,
            \"organization\": \"${ORG}\",
            \"channel\": \"${CHANNEL_NAME}\",
            \"credentialStore\": {
               \"path\": \"./tmp/fabric-client-kvs_${ORG}\",
               \"cryptoStore\": {
                  \"path\": \"./tmp/fabric-client-kvs_${ORG}\"
               }
            }
         }" >> ${DOCKER_DIR}/config.json
      else
         FIRST=false
      fi
   done
   echo "},
         \"channels\": {
         \"${CHANNEL_NAME}\": {
            \"peers\": {" >> ${DOCKER_DIR}/config.json
   FIRST=true
   for ORG in $PEER_ORGS; do
      COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         if [ $FIRST != true ]; then
            #echo "," >> ${DOCKER_DIR}/config.json
            echo
         else
            echo "\"${PEER_HOST}\": {}" >> ${DOCKER_DIR}/config.json
            FIRST=false
         fi
         COUNT=$((COUNT+1))
      done
   done
   echo "},
         \"connection\": {
            \"timeout\": {
               \"peer\": {
                  \"endorser\": \"60000\",
                  \"eventHub\": \"60000\",
                  \"eventReg\": \"60000\"
               }
            }
         }
      }},
   \"orderers\": {
      \"${ORDERER_HOST}\": {
         \"url\": \"grpcs://${ORDERER_HOST}:7050\"
      }
   },
   \"organizations\": {
      \"${ORDERER_ORGS}\": {
         \"mspid\": \"${ORDERER_ORGS}MSP\",
         \"fullpath\": false,
         \"adminPrivateKey\": {
            \"path\": \"/data/orgs/${ORDERER_ORGS}/admin/msp/keystore\"
         },
         \"signedCert\": {
            \"path\": \"/data/orgs/${ORDERER_ORGS}/admin/msp/signcerts\"
         }  
      }," >> ${DOCKER_DIR}/config.json
   FIRST=true
   for ORG in $PEER_ORGS; do
      if [ $FIRST != true ]; then
         echo "," >> ${DOCKER_DIR}/config.json
      else
         FIRST=false
      fi
      echo "\"${ORG}\": {
            \"name\": \"${ORG}\",
            \"mspid\": \"${ORG}MSP\",
            \"fullpath\": false,
            \"tlsEnable\": true," >> ${DOCKER_DIR}/config.json
      echo "\"adminPrivateKey\": {
               \"path\": \"/data/orgs/${ORG}/admin/msp/keystore\"
            },
            \"signedCert\": {
               \"path\": \"/data/orgs/${ORG}/admin/msp/signcerts\"
            }
         }" >> ${DOCKER_DIR}/config.json
   done

   echo "},
   \"peers\": {" >> ${DOCKER_DIR}/config.json
   FIRST=true
   for ORG in $PEER_ORGS; do
      COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         if [ $FIRST != true ]; then
            echo "," >> ${DOCKER_DIR}/config.json
         else
            FIRST=false
         fi
         echo "\"${PEER_HOST}\": {
                  \"url\": \"grpcs://${PEER_HOST}:7051\",
                  \"eventUrl\": \"grpcs://${PEER_HOST}:7053\",
                  \"grpcOptions\": {
                     \"ssl-target-name-override\": \"${PEER_HOST}\"
                  },
                  \"tlsCACerts\": {
                     \"path\": \"/data/${ORG}-ca-chain.pem\"
                  }
         }" >> ${DOCKER_DIR}/config.json
        COUNT=$((COUNT+1))
      done
   done
   echo "}}}}" >> ${DOCKER_DIR}/config.json
   log "Created config.json for blockchain browser"
}

# Write a service to setup the fabric artifacts (e.g. genesis block, etc)
function writeSetupFabric {
   export MYHOME="/private"
   echo "  setup:
    container_name: setup
    $TOOLS_BUILD
    stdin_open: true
    tty: true
    volumes:
      - ${SCRIPTS_DIR}:/scripts
      - ${LOGS_DIR}:/logs
      - ${SAMPLES_DIR}:/opt/gopath/src/github.com/hyperledger/fabric-samples
      - ${COMMON}:/${COMMON}
    environment:
      - PEER_HOME=$MYHOME
      - ORDERER_HOME=$MYHOME
    networks:
      - $NETWORK"
}

# Write services for fabric orderer and peer containers
function writeStartFabric {
   for ORG in $ORDERER_ORGS; do
      COUNT=1
      while [[ "$COUNT" -le $NUM_ORDERERS ]]; do
         initOrdererVars $ORG $COUNT
         writeOrderer
         COUNT=$((COUNT+1))
      done
   done
   for ORG in $PEER_ORGS; do
      COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         writePeer
         COUNT=$((COUNT+1))
      done
   done
}

function writeHyperledgerComposer {
   echo "  
  hyperledger-composer:
    container_name: blockchain-composer
    image: hyperledger/composer-playground
    ports:
      - 8080:8080
    networks:
      - $NETWORK"
} 

function writeBlockchainExplorer {
   writeBlockchainExplorerService
   echo "
  blockchain-explorer:
    container_name: blockchain-explorer
    image: hyperledger/local-explorer
    environment:
      - DATABASE_HOST=172.16.0.250
      - DATABASE_USERNAME=$EXPLORER_DB_USER
      - DATABASE_PASSWORD=$EXPLORER_DB_PWD
    volumes:
      - ./config.json:/opt/explorer/app/platform/fabric/config.json
      - ${COMMON}:/${COMMON}
    ports:
      - 8000:8080
    networks:
      - $NETWORK
    depends_on:
      - blockchain-explorer-db
    
  blockchain-explorer-db:
    container_name: blockchain-explorer-db
    image: hyperledger/local-explorer-db
    working_dir: /opt
    environment:
      - DATABASE_HOST=blockchain-explorer-db
      - DATABASE_PORT=5432
      - DATABASE_DATABASE=$EXPLORER_DB_NAME
      - DATABASE_USERNAME=$EXPLORER_DB_USER
      - DATABASE_PASSWORD=$EXPLORER_DB_PWD
    command: >
      bash -c \"cp /opt/createdb.sh /docker-entrypoint-initdb.d/
      && postgres\"
    volumes:
      - ${SCRIPTS_DIR}:/scripts
    networks:
      $NETWORK:
         ipv4_address: 172.16.0.250"
}

function writeRootCA {
   echo "  $ROOT_CA_NAME:
    container_name: $ROOT_CA_NAME
    image: hyperledger/fabric-ca:$FABRIC_TAG
    command: /bin/bash -c '/scripts/start-root-ca.sh 2>&1 | tee /$ROOT_CA_LOGFILE'
    environment:
      - ORDERER_ORGS="$ORDERER_ORGS"
      - PEER_ORGS="$PEER_ORGS"
      - NUM_PEERS="$NUM_PEERS"
      - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_CSR_CN=$ROOT_CA_NAME
      - FABRIC_CA_SERVER_CSR_HOSTS=$ROOT_CA_HOST
      - FABRIC_CA_SERVER_DEBUG=false
      - BOOTSTRAP_USER_PASS=$ROOT_CA_ADMIN_USER_PASS
      - TARGET_CERTFILE=$ROOT_CA_CERTFILE
      - FABRIC_ORGS="$ORGS"
      - RANDOM_NUMBER="$RANDOM_NUMBER"
    volumes:
      - ${SCRIPTS_DIR}:/scripts
      - ${LOGS_DIR}:/logs
      - ${COMMON}:/${COMMON}
    networks:
      - $NETWORK
"
}

function writeIntermediateCA {
   echo "  $INT_CA_NAME:
    container_name: $INT_CA_NAME
    image: hyperledger/fabric-ca:$FABRIC_TAG
    command: /bin/bash -c '/scripts/start-intermediate-ca.sh $ORG 2>&1 | tee /$INT_CA_LOGFILE'
    environment:
      - ORDERER_ORGS="$ORDERER_ORGS"
      - PEER_ORGS="$PEER_ORGS"
      - NUM_PEERS="$NUM_PEERS"
      - FABRIC_CA_SERVER_HOME=/etc/hyperledger/fabric-ca
      - FABRIC_CA_SERVER_CA_NAME=$INT_CA_NAME
      - FABRIC_CA_SERVER_INTERMEDIATE_TLS_CERTFILES=$ROOT_CA_CERTFILE
      - FABRIC_CA_SERVER_CSR_HOSTS=$INT_CA_HOST
      - FABRIC_CA_SERVER_TLS_ENABLED=true
      - FABRIC_CA_SERVER_DEBUG=false
      - BOOTSTRAP_USER_PASS=$INT_CA_ADMIN_USER_PASS
      - PARENT_URL=https://$ROOT_CA_ADMIN_USER_PASS@$ROOT_CA_HOST:7054
      - TARGET_CHAINFILE=$INT_CA_CHAINFILE
      - ORGANIZATION=$ORG
      - FABRIC_ORGS="$ORGS"
      - RANDOM_NUMBER="$RANDOM_NUMBER"
    volumes:
      - ${SCRIPTS_DIR}:/scripts
      - ${LOGS_DIR}:/logs
      - ${COMMON}:/${COMMON}
    networks:
      - $NETWORK
    depends_on:
      - $ROOT_CA_NAME
"
}

function writeOrderer {
   export MYHOME=/etc/hyperledger/orderer
   echo "  $ORDERER_NAME:
    container_name: $ORDERER_NAME
    $ORDERER_BUILD
    environment:
      - ORDERER_ORGS="$ORDERER_ORGS"
      - PEER_ORGS="$PEER_ORGS"
      - NUM_PEERS="$NUM_PEERS"
      - FABRIC_CA_CLIENT_HOME=$MYHOME
      - FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
      - ENROLLMENT_URL=https://$ORDERER_NAME_PASS@$CA_HOST:7054
      - ORDERER_HOME=$MYHOME
      - ORDERER_HOST=$ORDERER_HOST
      - ORDERER_GENERAL_LISTENADDRESS=0.0.0.0
      - ORDERER_GENERAL_GENESISMETHOD=file
      - ORDERER_GENERAL_GENESISFILE=$GENESIS_BLOCK_FILE
      - ORDERER_GENERAL_LOCALMSPID=$ORG_MSP_ID
      - ORDERER_GENERAL_LOCALMSPDIR=$MYHOME/msp
      - ORDERER_GENERAL_TLS_ENABLED=true
      - ORDERER_GENERAL_TLS_PRIVATEKEY=$MYHOME/tls/server.key
      - ORDERER_GENERAL_TLS_CERTIFICATE=$MYHOME/tls/server.crt
      - ORDERER_GENERAL_TLS_ROOTCAS=$CA_CHAINFILE
      - ORDERER_GENERAL_TLS_CLIENTAUTHREQUIRED=true
      - ORDERER_GENERAL_TLS_CLIENTROOTCAS=$CA_CHAINFILE
      - ORDERER_GENERAL_LOGLEVEL=ERROR
      - ORDERER_DEBUG_BROADCASTTRACEDIR=$LOGDIR
      - FABRIC_LOGGING_SPEC=ERROR
      - ORGANIZATION=$ORG
      - COUNT=$COUNT
      - ORG_ADMIN_CERT=$ORG_ADMIN_CERT
      - ORDERER_KAFKA_TOPIC_REPLICATIONFACTOR=1
      - ORDERER_KAFKA_VERBOSE=true
      - RANDOM_NUMBER="$RANDOM_NUMBER"
    command: /bin/bash -c '/scripts/start-orderer.sh 2>&1 | tee /$ORDERER_LOGFILE'
    volumes:
      - ${SCRIPTS_DIR}:/scripts
      - ${LOGS_DIR}:/logs
      - ${COMMON}:/${COMMON}
    networks:
      - $NETWORK
    depends_on:
      - zookeeper.${ORDERER_NAME}
      - kafka.${ORDERER_NAME}"
   for ORG in $PEER_ORGS; do
      COUNT=1
      while [[ "$COUNT" -le $NUM_PEERS ]]; do
         initPeerVars $ORG $COUNT
         echo "      - $PEER_NAME"
         COUNT=$((COUNT+1))
      done
   done
writeKafka
}

function writePeer {
   export MYHOME=/opt/gopath/src/github.com/hyperledger/fabric/peer
   echo "  $PEER_NAME:
    container_name: $PEER_NAME
    $PEER_BUILD
    environment:
      - ORDERER_ORGS="$ORDERER_ORGS"
      - PEER_ORGS="$PEER_ORGS"
      - NUM_PEERS="$NUM_PEERS"
      - FABRIC_CA_CLIENT_HOME=$MYHOME
      - FABRIC_CA_CLIENT_TLS_CERTFILES=$CA_CHAINFILE
      - ENROLLMENT_URL=https://$PEER_NAME_PASS@$CA_HOST:7054
      - PEER_NAME=$PEER_NAME
      - PEER_HOME=$MYHOME
      - PEER_HOST=$PEER_HOST
      - PEER_NAME_PASS=$PEER_NAME_PASS
      - CORE_PEER_ID=$PEER_HOST
      - CORE_PEER_ADDRESS=$PEER_HOST:7051
      - CORE_PEER_LOCALMSPID=$ORG_MSP_ID
      - CORE_PEER_MSPCONFIGPATH=$MYHOME/msp
      - CORE_VM_ENDPOINT=unix:///host/var/run/docker.sock
      - CORE_VM_DOCKER_HOSTCONFIG_NETWORKMODE=net_${NETWORK}
      - FABRIC_LOGGING_SPEC=ERROR
      - CORE_PEER_TLS_ENABLED=true
      - CORE_PEER_TLS_CERT_FILE=$MYHOME/tls/server.crt
      - CORE_PEER_TLS_KEY_FILE=$MYHOME/tls/server.key
      - CORE_PEER_TLS_ROOTCERT_FILE=$CA_CHAINFILE
      - CORE_PEER_TLS_CLIENTAUTHREQUIRED=true
      - CORE_PEER_TLS_CLIENTROOTCAS_FILES=$CA_CHAINFILE
      - CORE_PEER_GOSSIP_USELEADERELECTION=true
      - CORE_PEER_GOSSIP_ORGLEADER=false
      - CORE_PEER_GOSSIP_EXTERNALENDPOINT=$PEER_HOST:7051
      - CORE_PEER_GOSSIP_SKIPHANDSHAKE=true
      - ORGANIZATION=$ORG
      - COUNT=$COUNT
      - ORG_ADMIN_CERT=$ORG_ADMIN_CERT
      - RANDOM_NUMBER="$RANDOM_NUMBER""
   if [ $NUM -gt 1 ]; then
      echo "      - CORE_PEER_GOSSIP_BOOTSTRAP=$PEER_HOST:7051"
   fi
   echo "    working_dir: $MYHOME
    command: /bin/bash -c '/scripts/start-peer.sh 2>&1 | tee /$PEER_LOGFILE'
    volumes:
      - ${SCRIPTS_DIR}:/scripts
      - ${LOGS_DIR}:/logs
      - /var/run:/host/var/run
      - ${COMMON}:/${COMMON}
    networks:
      - $NETWORK
"
}

function writeKafka {
echo "
  zookeeper.${ORDERER_NAME}:
    container_name: zookeeper.${ORDERER_NAME}
    image: hyperledger/fabric-zookeeper:$FABRIC_CA_TAG
    environment:
      ZOOKEEPER_CLIENT_PORT: 32181
      ZOOKEEPER_TICK_TIME: 2000
    networks:
    - $NETWORK

  kafka.${ORDERER_NAME}:
    container_name: kafka.${ORDERER_NAME}
    image: hyperledger/fabric-kafka:$FABRIC_CA_TAG
    depends_on:
    - zookeeper.${ORDERER_NAME}
    environment:
      - KAFKA_BROKER_ID=1
      - KAFKA_ZOOKEEPER_CONNECT=zookeeper.${ORDERER_NAME}:2181
      - KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka.${ORDERER_NAME}:9092
      - KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR=1
      - KAFKA_MESSAGE_MAX_BYTES=1048576 # 1 * 1024 * 1024 B
      - KAFKA_REPLICA_FETCH_MAX_BYTES=1048576 # 1 * 1024 * 1024 B
      - KAFKA_UNCLEAN_LEADER_ELECTION_ENABLE=false
      - KAFKA_LOG_RETENTION_MS=-1
      - KAFKA_MIN_INSYNC_REPLICAS=1
      - KAFKA_DEFAULT_REPLICATION_FACTOR=1
    networks:
      - $NETWORK
"
}

function writeHeader {
echo "#File was generated automatically on $(date) by makeDocker.sh. Do not edit.
version: '3.4'
   
networks:
  $NETWORK:
    ipam:
      driver: default
      config:
        - subnet: ${SUBNET}

volumes:
  ${COMMON}:

services:
"
}

#Execute function from parameters
$1 $2 $3