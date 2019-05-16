# Scalable Hyperledger Fabric with Hyperledger Blockchain Explorer out-of-the box

## Description
TODO

## How to start
You need the following components installed:
- Docker
- Docker Composer version > 3.4

### 1. Launch blockchain fabric network infrastructure `./start.sh`

### 2. Run fabric basic functionality tests:
#### 2.1 Login to Fabric CLI docker container `docker exec setup /bin/bash`
#### 2.3 Inside docker launch tests `cd /scripts && ./tests.sh main`
```
Test 1 - add org1 to the system channel
Test 2 - create new channel between governor and org1
Test 3 - add org2 to newly created channel
Test 4 - install annd instantiate ABAC chaincode on new channel
Test 5 - install annd instantiate testMarblesChaincode chaincode
Test 5 - install annd instantiate testHighThroughputChaincode chaincode
```

### Hyperledger explorer will be avalibale on http://localhost:8888

## How to stop
Run following command `./stop.sh` and it will stop all the containers and clean the images