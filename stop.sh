#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

set -e
SDIR=$(dirname "$0")
source $SDIR/scripts/env.sh

log "Stopping docker containers ..."
docker stop $(docker ps -a --format "{{.Names}}")
docker rm -f $(docker ps -a --format "{{.Names}}")
docker network prune
docker volume prune
docker rmi -f $(docker images -a -q)
rm -rf data 
log "Docker containers have been stopped"