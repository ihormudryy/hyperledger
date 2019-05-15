#!/usr/bin/env bash

function addOrgToConsortium {
  echo "add org to system channel1"
  cd /scripts
  export ORDERER_ORGS=$1
  export CENTRAL=$2
  export PEER_ORGS="$CENTRAL"
  export NUM_PEERS=$3
  export RANDOM_NUMBER=${RANDOM}
  echo $RANDOM_NUMBER > random.txt
  mkdir -p /private/crypto${RANDOM_NUMBER}

  echo "add org to system channel"
  ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
  ./run-fabric.sh updateSytemChannelConfig $CENTRAL
}

function createChannel {
  SRC=$(dirname "$0")
  export FABRIC_CFG_PATH=/etc/hyperledger/fabric
  export ORDERER_ORGS=$1
  export PEER_ORGS=$2
  export RANDOM_NUMBER=$3
  AUTOJOIN=$4
  export PEER_HOME=/private
  export ORDERER_HOME=/private

  mkdir /private/crypto$RANDOM_NUMBER
  $SRC/run-fabric.sh createChannel $PEER_ORGS

  if [ ! -z "$AUTOJOIN" ]; then
    $SRC/run-fabric.sh joinChannel $PEER_ORGS 1
  fi
}

function getChannel {
  SRC=$(dirname "$0")
  export FABRIC_CFG_PATH=/etc/hyperledger/fabric
  export ORDERER_ORGS=$1
  export PEER_ORGS=$2
  export RANDOM_NUMBER=$3

  $SRC/run-fabric.sh getChannel
}

function addOrgToChannel {
  SRC=$(dirname "$0")
  # export FABRIC_CFG_PATH=/etc/hyperledger/fabric
  export ORDERER_ORGS=$1
  export CENTRAL=$2
  export PEER_ORGS=$3
  export RANDOM_NUMBER=$4
  export NUM_PEERS=$5

  $SRC/env.sh $ORDERER_ORGS "$CENTRAL $PEER_ORGS" $NUM_PEERS
  $SRC/run-fabric.sh updateChannelConfig $CENTRAL 1 $PEER_ORGS
}

$1 $2 $3 $4 $5 $6