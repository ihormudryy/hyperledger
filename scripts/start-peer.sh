#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# Start the peer

log "looking for $CORE_PEER_TLS_CERT_FILE"
if [ -f /${COMMON}/tls/$PEER_NAME-client.crt ]; then
  SRC=$(dirname "$0")
  source $SRC/env.sh $ORDERER_ORGS $ORGANIZATION $NUM_PEERS
  log "crypto artifacts exist, starting peer"
  export PEER_HOME=/${COMMON}
  export ORDERER_HOME=/${COMMON}
  initOrgVars $ORGANIZATION
  initPeerVars $ORGANIZATION $COUNT
  export CORE_PEER_MSPCONFIGPATH=$ORG_ADMIN_HOME/msp
  export CORE_PEER_TLS_KEY_FILE=$TLSDIR/$PEER_NAME-client.key
  export CORE_PEER_TLS_CERT_FILE=$TLSDIR/$PEER_NAME-client.crt
else
  bash /scripts/setup-node.sh setupPeer
fi

# env | grep CORE
echo "Start peer ... $CORE_PEER_TLS_CLIENTKEY_FILE"
peer node start