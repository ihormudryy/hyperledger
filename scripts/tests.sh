#!/bin/bash

function main {
    cd /scripts
    export ORDERER_ORGS="blockchain-technology"
    export CENTRAL="org1"
    export PEER_ORGS="$CENTRAL"
    export NUM_PEERS=2
    export RANDOM_NUMBER=${RANDOM}
    mkdir -p /private/crypto${RANDOM_NUMBER}
    echo $RANDOM_NUMBER > random.txt

    echo
    echo "Test 1 - add org1 to system channel"
    echo
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./run-fabric.sh updateSytemChannelConfig "org1"

    echo
    echo "Test 2 - create new channel between org1"
    echo
    export PEER_ORGS="org1"
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./run-fabric.sh testChannel

    echo
    echo "Test3 - add org2 to newly created channel"
    echo
    export PEER_ORGS="org1 org2"
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS
    ./run-fabric.sh updateChannelConfig $CENTRAL 1 org2

    echo
    echo "Test 4 - install annd instantiate ABAC chaincode in org1 and org2 peers"
    echo
    ./run-fabric.sh testABACChaincode
}

function createUser {
    cd /scripts
    export ORDERER_ORGS="blockchain-technology"
    export PEER_ORGS="org1"
    export NUM_PEERS=2
    IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"
    source env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    initOrdererVars ${OORGS[0]} 1
    initPeerVars ${PORGS[0]} 1
    ennrollNewUser $ORG_USER_HOME "mudryy" "mudryypw"
}

function testABACChaincode {
    cd /scripts
    export ORDERER_ORGS="blockchain-technology"
    export CENTRAL="org1"
    export PEER_ORGS="governor $CENTRAL"
    export NUM_PEERS=2
    export RANDOM_NUMBER=$(cat /scripts/random.txt)
    source env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./run-fabric.sh testABACChaincode
}

function testMarblesChaincode {
    cd /scripts
    export ORDERER_ORGS="blockchain-technology"
    export CENTRAL="org1"
    export PEER_ORGS="governor $CENTRAL"
    export NUM_PEERS=2
    export RANDOM_NUMBER=$(cat /scripts/random.txt)
    source env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./run-fabric.sh testMarblesChaincode
}

function testHighThroughputChaincode {
    cd /scripts
    export ORDERER_ORGS="blockchain-technology"
    export CENTRAL="org1"
    export PEER_ORGS="governor $CENTRAL"
    export NUM_PEERS=2
    export RANDOM_NUMBER=$(cat /scripts/random.txt)
    source env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./run-fabric.sh testHighThroughputChaincode
}

$1
