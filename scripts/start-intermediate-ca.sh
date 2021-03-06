#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -ex
source $(dirname "$0")/env.sh $ORDERER_ORGS "$PEER_ORGS" $NUM_PEERS
initOrgVars $ORGANIZATION

if [ ! -f $TARGET_CHAINFILE ]; then
 # Wait for the root CA to start
  waitPort "root CA to start" 60 $ROOT_CA_LOGFILE $ROOT_CA_HOST 7054

  # Initialize the intermediate CA
  fabric-ca-server init -b $BOOTSTRAP_USER_PASS -u $PARENT_URL

  # Copy the intermediate CA's certificate chain to the data directory to be used by others
  cp $FABRIC_CA_SERVER_HOME/ca-chain.pem $TARGET_CHAINFILE

  # Add the custom orgs
  for o in $FABRIC_ORGS; do
     aff=$aff"\n   $o: []"
  done
  aff="${aff#\\n   }"
  sed -i "/affiliations:/a \\   $aff" \
     $FABRIC_CA_SERVER_HOME/fabric-ca-server-config.yaml
fi

# Start the intermediate CA
fabric-ca-server start -b $BOOTSTRAP_USER_PASS -u $PARENT_URL
