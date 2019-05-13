#!/usr/bin/env bash

SRC=$(dirname "$0")
export FABRIC_CFG_PATH=/etc/hyperledger/fabric
export ORDERER_ORGS=$1
export PEER_ORGS=$2
export RANDOM_NUMBER=$3

$SRC/run-fabric.sh getChannel