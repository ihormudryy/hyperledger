#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# Start the peer
set -ex
bash /scripts/setup-node.sh setupPeer
env | grep CORE
peer node start