#!/bin/bash

function main {
    cd /scripts
    export ORDERER_ORGS="blockchain-technology"
    export CENTRAL="governor"
    export PEER_ORGS="$CENTRAL org1"
    export NUM_PEERS=2
    export RANDOM_NUMBER=${RANDOM}
    mkdir -p /private/crypto${RANDOM_NUMBER}
    echo $RANDOM_NUMBER > random.txt

    IFS=', ' read -r -a OORGS <<< "$ORDERER_ORGS"
    IFS=', ' read -r -a PORGS <<< "$PEER_ORGS"

    echo
    echo "Test 1 - add new org to system channel"
    echo
    ./env.sh "$ORDERER_ORGS" "$PEER_ORGS" $NUM_PEER
    ./run-fabric.sh updateSytemChannelConfig "org1"

    echo
    echo "Test 2 - create new channel between org and governor"
    echo
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./run-fabric.sh testChannel

    echo
    echo "Test3 - add new org to newly created channel"
    echo
    export PEER_ORGS="governor org1 org2"
    ./run-fabric.sh updateChannelConfig "governor" 1 "org2"

    export PEER_ORGS="governor org1 org2 org3"
    ./run-fabric.sh updateChannelConfig "governor" 1 "org3"

    export PEER_ORGS="governor org1 org2 org3 org4"
    ./run-fabric.sh updateChannelConfig "governor" 1 "org4"

    export PEER_ORGS="governor org1 org2 org3 org4 org5"
    ./run-fabric.sh updateChannelConfig "governor" 1 "org5"

    echo
    echo "Test 4 - install annd instantiate ABAC chaincode"
    echo
    #./run-fabric.sh testABACChaincode

    echo
    echo "Test 5 - install annd instantiate testMarblesChaincode chaincode"
    echo
    ./run-fabric.sh testMarblesChaincode
}

function performanceTest {
    cd /scripts
    export ORDERER_ORGS="blockchain-technology"
    export CENTRAL="governor"
    export PEER_ORGS="$CENTRAL"
    export NUM_PEERS=1
    
    local ORG_COUNT=1
    local PEER_COUNT=1
    local MAX_ORGS=5
    local MAX_PEERS=4

    export MAX_TX_COUNT=1000

    mkdir -p /logs/performance
    export CURRENT_DATE=`date +%d.%m.%Y_%H:%M:%S`
    echo "num_orgs,num_peers,tx_count,invoke,queue" > /logs/performance/test_$CURRENT_DATE.csv
    while [[ "$ORG_COUNT" -le $MAX_ORGS ]]; do
        while [[ "$PEER_COUNT" -le $MAX_PEERS ]]; do
            export NUM_ORGS=$ORG_COUNT
            export NUM_PEERS=$PEER_COUNT
            export RANDOM_NUMBER="${NUM_ORGS}orgs${NUM_PEERS}peers"
            mkdir -p /private/crypto${RANDOM_NUMBER}
            export PEER_ORGS="org${ORG_COUNT} $PEER_ORGS"
            ./run-fabric.sh updateSytemChannelConfig "org${ORG_COUNT}"
            ./run-fabric.sh testChannel
            ##./run-fabric.sh updateChannelConfig $CENTRAL 1 "org${ORG_COUNT}"
            ./run-fabric.sh testHighThroughputChaincode
            rm -rf /logs/*.Broadcast
            echo "${NUM_ORGS} orgs ${NUM_PEERS} peers"
            PEER_COUNT=$((PEER_COUNT+1))
        done
        PEER_COUNT=1
        ORG_COUNT=$((ORG_COUNT+1))
    done
}

function testOneOrgInNewChannel {
    cd /scripts
    export ORDERER_ORGS="blockchain-technology"
    export CENTRAL="governor"
    export PEER_ORGS="$CENTRAL"
    export NUM_PEERS=2
    export RANDOM_NUMBER=${RANDOM}
    mkdir -p /private/crypto${RANDOM_NUMBER}
    echo $RANDOM_NUMBER > random.txt
    ./env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ./run-fabric.sh testChannel
    echo
    echo "Test install annd instantiate testHighThroughputChaincode chaincode"
    echo
    ./run-fabric.sh testHighThroughputChaincode
}

function createUser {
    cd /scripts
    export ORDERER_ORGS="blockchain-technology"
    export PEER_ORGS="org1"
    export NUM_PEERS=2
    source env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEER
    ORG="org1"
    initPeerVars ${ORG} 1
    export USER_NAME="regular_${RANDOM}@org1.com"
    export USER_PASS="regularpw_${RANDOM}"
    ennrollNewUser /${COMMON}/orgs/${ORG}/${USER_NAME} ${USER_NAME} $USER_PASS
    registerNewUser /${COMMON}/orgs/${ORG}/${USER_NAME} ${USER_NAME} $USER_PASS
    cp /${COMMON}/orgs/${ORG}/${USER_NAME}/msp/keystore/* /${COMMON}/orgs/${ORG}/${USER_NAME}/msp/key.pem
    cp /${COMMON}/orgs/${ORG}/${USER_NAME}/msp/signcerts/cert.pem /${COMMON}/orgs/${ORG}/${USER_NAME}/msp/cert.pem
}

function testConsentChaincode {
    export CHAINCODE_PREFIX="github.com/hyperledger/fabric-samples"
    export ORDERER_ORGS="blockchain-technology"
    export PEER_ORGS="org1 org2"
    cd $GOPATH/src/$CHAINCODE_PREFIX/consent
    #./deploy_chaincode.sh deploy
    cd $GOPATH/src/$CHAINCODE_PREFIX/consent/application
    #npm install
    node index.js
}

$1
