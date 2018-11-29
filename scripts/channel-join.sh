#!/bin/bash
set -xe

# peer0.${ORG1} channel join
echo "========== Joining peer0.${ORG1} to channel ${CHANNEL_NAME} =========="
export CORE_PEER_MSPCONFIGPATH=${CA_DIR}/peers/peerOrganizations/${ORG1}/users/Admin@${ORG1}/msp
export CORE_PEER_ADDRESS=peer0.${ORG1}:7051
export CORE_PEER_LOCALMSPID="${ORG1_ID}MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${CA_DIR}/peers/peerOrganizations/${ORG1}/peers/peer0.${ORG1}/tls/ca.crt
peer channel join -b ${CA_DIR}/peers/${CHANNEL_NAME}.block
peer channel update -o orderer.${ORDERER_DOMAIN}:7050 \
    -c $CHANNEL_NAME \
    -f ${CA_DIR}/peers/${CORE_PEER_LOCALMSPID}Anchors.tx \
    --tls $CORE_PEER_TLS_ENABLED \
    --cafile $ORDERER_CA

# peer1.${ORG1} channel join
echo "========== Joining peer1.${ORG1} to channel ${CHANNEL_NAME} =========="
export CORE_PEER_MSPCONFIGPATH=${CA_DIR}/peers/peerOrganizations/${ORG1}/users/Admin@${ORG1}/msp
export CORE_PEER_ADDRESS=peer1.${ORG1}:8051
export CORE_PEER_LOCALMSPID="${ORG1_ID}MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${CA_DIR}/peers/peerOrganizations/${ORG1}/peers/peer1.${ORG1}/tls/ca.crt
peer channel join -b ${CHANNEL_NAME}.block

# peer0.${ORG2} channel join
echo "========== Joining peer0.${ORG2} to channel ${CHANNEL_NAME} =========="
export CORE_PEER_MSPCONFIGPATH=${CA_DIR}/peers/peerOrganizations/${ORG2}/users/Admin@${ORG2}/msp
export CORE_PEER_ADDRESS=peer0.${ORG2}:9051
export CORE_PEER_LOCALMSPID="${ORG2_ID}MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${CA_DIR}/peers/peerOrganizations/${ORG2}/peers/peer0.${ORG2}/tls/ca.crt
peer channel join -b ${CHANNEL_NAME}.block
peer channel update -o orderer.${ORDERER_DOMAIN}:7050 \
    -c $CHANNEL_NAME \
    -f ${CA_DIR}/${CORE_PEER_LOCALMSPID}Anchors.tx \
    --tls $CORE_PEER_TLS_ENABLED \
    --cafile $ORDERER_CA

# peer1.${ORG2} channel join
echo "========== Joining peer1.${ORG2} to channel ${CHANNEL_NAME} =========="
export CORE_PEER_MSPCONFIGPATH=${CA_DIR}/peers/peerOrganizations/${ORG2}/users/Admin@${ORG2}/msp
export CORE_PEER_ADDRESS=peer1.${ORG2}:10051
export CORE_PEER_LOCALMSPID="${ORG2_ID}MSP"
export CORE_PEER_TLS_ROOTCERT_FILE=${CA_DIR}/peerOrganizations/${ORG2}/peers/peer1.${ORG2}/tls/ca.crt
peer channel join -b ${CHANNEL_NAME}.block