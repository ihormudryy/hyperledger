
cd /scripts
export ORDERER_ORGS="here"
export PEER_ORGS="consumer provider"
export NUM_PEERS=3
export RANDOM_NUMBER=$(cat random.txt)

./run-fabric.sh testChannel
export PEER_ORGS="$PEER_ORGS germany"
./run-fabric.sh updateChannelConfig consumer 1 germany
./run-fabric.sh testABACChaincode
./run-fabric.sh testHighThroughputChaincode
