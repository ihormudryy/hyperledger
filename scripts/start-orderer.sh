#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

if [ -f /${COMMON}/tls/$ORDERER_HOST-cli-client.crt ]; then
  SRC=$(dirname "$0")
  source $SRC/env.sh $ORDERER_ORGS $ORGANIZATION $NUM_PEERS
  log "crypto artifacts exist, starting orderer"
  export PEER_HOME=/${COMMON}
  export ORDERER_HOME=/${COMMON}
  initOrdererVars $ORGANIZATION $COUNT
  export ORDERER_GENERAL_LOCALMSPDIR=$ORG_ADMIN_HOME/msp
  export CORE_ORDERER_TLS_CERT_FILE=/${COMMON}/tls/$ORDERER_NAME-cli-client.crt
  export CORE_ORDERER_TLS_KEY_FILE=/${COMMON}/tls/$ORDERER_NAME-cli-client.key
  export ORDERER_GENERAL_TLS_PRIVATEKEY=$CORE_ORDERER_TLS_KEY_FILE
  export ORDERER_GENERAL_TLS_CERTIFICATE=$CORE_ORDERER_TLS_CERT_FILE
else
  bash /scripts/setup-node.sh setupOrderer
fi

set -ex
orderer