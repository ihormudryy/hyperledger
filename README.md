# Scalable Hyperledger Fabric with Hyperledger Blockchain Explorer out-of-the box

## Description
This project allows running Hyperledger Fabric without a need of manually generating any crypto material, TLS certificats or configs or registering/enrolling users for each peer or orderer. 

Some key differentiators comparing to BYFN and other projects:
1. Docker compose, configtx.yaml and other config files are generated dynamically based on the ENV:s input in start.sh file. 
2. It is possible to scale the network on demand having unlimited amount of orgranizations, peers and ordreres with arbitrary name.
3. Usage of root and intermediate certificate authorities for certificates management.
4. All admin/user registrations and enrolments are done during the node bootstrap. Crypto material stays inside private docker volume and not shared outside.
5. Forked and modified Blockchain Explorer stats together with Hyperledger Fabric and allows to browse the network on behalf of the 'governer' organization which is a first one created in a network.
6. Genesis block, channel tx and channel block are generated automatically based on initial network setup.
7. Fabric CLI is wrapped into microservice inside a docker network with standalone endpoint http://setup:3000/

Modified Hyperledger Blockchain Explorer with new features allows:
1. Install and instantiate chaincodes via Web UI.
2. Browse chaicodes content
3. Create channels
4. Manage channels


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
Test 4 - install annd instantiate ABAC chaincode on a new channel
Test 5 - install annd instantiate testMarblesChaincode chaincode
Test 5 - install annd instantiate testHighThroughputChaincode chaincode
```

### Hyperledger explorer will be avalibale on http://localhost:8888

## How to stop Fabric
Run following command `./stop.sh` and it will stop all the containers and clean the images