#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

# Start the orderer
set -ex
bash /scripts/setup-node.sh setupOrderer
env
orderer