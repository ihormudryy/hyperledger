
cd /scripts
export ORDERER_ORGS="blockchain-technology"
export CENTRAL="governor"
export PEER_ORGS="$CENTRAL"
export NUM_PEERS=2
export RANDOM_NUMBER=${RANDOM}
mkdir -p /private/crypto${RANDOM_NUMBER}
#./run-fabric.sh fetchSystemChannelConfig

#export PEER_ORGS="$CENTRAL org2"
source env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS
#./run-fabric.sh updateSytemChannelConfig "org2"

./run-fabric.sh testChannel

export PEER_ORGS="$CENTRAL org1"
source env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS
./run-fabric.sh updateChannelConfig $CENTRAL 1 org1

export PEER_ORGS="$CENTRAL org1 org2"
source env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS
./run-fabric.sh updateChannelConfig $CENTRAL 1 org2

#./run-fabric.sh testABACChaincode
./run-fabric.sh testMarblesChaincode
#./run-fabric.sh testHighThroughputChaincode
