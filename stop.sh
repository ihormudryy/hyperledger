#!/bin/bash
#
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
#

#SDIR=$(dirname "$0")
#source $SDIR/scripts/env.sh

echo "Stopping docker containers ..."
docker stop $(docker ps -a --format "{{.Names}}")
docker rm -f $(docker ps -a --format "{{.Names}}")
docker network prune
docker volume prune
docker rmi -f $(docker images -a -q)
rm -rf data 
echo "Docker containers have been stopped"