#!/bin/bash

SRC=$(dirname "$0")
ORDERER_ORGS=$1
NEW_ORG=$2
GOVERNOR=$3
echo $EXISTING_ORGS
export RANDOM_NUMBER=$4
export PEER_HOME=/private
export ORDERER_HOME=/private

source $SRC/make-config-tx.sh

source $SRC/env.sh $ORDERER_ORGS $NEW_ORG 1
makeConfigTxYaml /${COMMON}
$SRC/run-fabric.sh generateChannelTx
export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
peer channel join -b $BLOCK_FILE

source $SRC/env.sh $ORDERER_ORGS $EXISTING_ORGS 1
initOrdererVars $ORDERER_ORGS 1
initPeerVars $GOVERNOR 1

cd /tmp
export FABRIC_CFG_PATH=/private
configtxgen -printOrg $NEW_ORG > org3.json

export FABRIC_CFG_PATH=/etc/hyperledger/fabric
export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
initOrdererVars $ORDERER_ORGS 1
echo "download config $CHANNEL_NAME"
peer channel fetch config config_block.pb -c $CHANNEL_NAME $ORDERER_CONN_ARGS
echo "downloaded config"
configtxlator proto_decode --input config_block.pb --type common.Block | jq .data.data[0].payload.data.config > config.json
jq -s '.[0] * {"channel_group":{"groups":{"Application":{"groups": {"'$NEW_ORG'":.[1]}}}}}' config.json org3.json > modified_config.json
configtxlator proto_encode --input  config.json --type common.Config --output config.pb
configtxlator proto_encode --input  modified_config.json --type common.Config --output  modified_config.pb
configtxlator compute_update --channel_id $CHANNEL_NAME --original config.pb --updated modified_config.pb --output org3_update.pb
configtxlator proto_decode --input  org3_update.pb --type common.ConfigUpdate | jq . >  org3_update.json
echo '{"payload":{"header":{"channel_header":{"channel_id":"'$CHANNEL_NAME'", "type":2}},"data":{"config_update":'$(cat  org3_update.json)'}}}' | jq . >  org3_update_in_envelope.json
configtxlator proto_encode --input org3_update_in_envelope.json --type common.Envelope --output  org3_update_in_envelope.pb

# sign by governor
initPeerVars $GOVERNOR 1
export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
peer channel signconfigtx -f org3_update_in_envelope.pb

peer channel update -f  org3_update_in_envelope.pb -c $CHANNEL_NAME $ORDERER_CONN_ARGS

sleep 3
echo $NEW_ORG
initPeerVars $NEW_ORG 1
export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
peer channel fetch config  config_block.pb -c $CHANNEL_NAME $ORDERER_CONN_ARGS