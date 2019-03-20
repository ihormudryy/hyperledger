
if [ $# -ne 2 ]; then
    fatalr "Usage: tests <RandomNumber>"
fi
export CHAINCODE_NAME="abac"
export CHAINCODE_PATH="abac/go"
export CHAINCODE_VERSION="2.0"
export ORDERER_ORGS="here"
export PEER_ORGS="consumer provider"
export NUM_PEERS=3
export RANDOM_NUMBER=$1
cd /scripts
./run-fabric.sh testABAC