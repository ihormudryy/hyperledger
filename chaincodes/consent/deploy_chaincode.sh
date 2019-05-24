#!/bin/bash
export ORDERER_ORGS="blockchain-technology"
export PEER_ORGS="org1 org2"
export NUM_PEERS=1
export CHAINCODE_NAME="consent_managament"
export CHAINCODE_PATH="consent/chaincode/node"
export CHAINCODE_TYPE="node"
export CHAINCODE_PREFIX="github.com/hyperledger/fabric-samples"

function deploy {
    cd /scripts
    export RANDOM_NUMBER=$(cat random.txt)
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    export CHAINCODE_VERSION=$(cat $GOPATH/src/$CHAINCODE_PREFIX/consent/chaincode/version.txt)
    for ORG in $PEER_ORGS; do
      ./run-fabric.sh installChaincode $ORG 1
    done
    ./run-fabric.sh instantiateChaincode ${PORGS[0]} 1 '{"Args":[]}'
    echo $((CHAINCODE_VERSION+1)) > $GOPATH/src/$CHAINCODE_PREFIX/consent/chaincode/version.txt
}

function upgrade {
    cd /scripts
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
    export RANDOM_NUMBER=$(cat random.txt)
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    export CHAINCODE_VERSION=$(cat $GOPATH/src/$CHAINCODE_PREFIX/consent/chaincode/version.txt)
    set -x
    for ORG in $PEER_ORGS; do
      ./run-fabric.sh installChaincode $ORG 1
    done
    ./run-fabric.sh upgradeChaincode ${PORGS[0]} 1 '{"Args":[]}'
    set +x
    echo $((CHAINCODE_VERSION+1)) > $GOPATH/src/$CHAINCODE_PREFIX/consent/chaincode/version.txt
}

function main {
  docker exec -it setup bash /opt/gopath/src/$CHAINCODE_PREFIX/consent/deploy_chaincode.sh $1
}

$1 $2