#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#
set -x
SDIR=$(dirname "$0")
source $SDIR/env.sh
./scripts/setup-fabric.sh
./scripts/run-fabric.sh