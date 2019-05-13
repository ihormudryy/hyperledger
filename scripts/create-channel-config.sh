#!/usr/bin/env bash

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