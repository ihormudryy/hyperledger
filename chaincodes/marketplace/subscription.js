/*
# Copyright IBM Corp. All Rights Reserved.
#
# SPDX-License-Identifier: Apache-2.0
*/

'use strict';
const shim = require('fabric-shim');
const util = require('util');

let Chaincode = class {

  // The Init method is called when the Smart Contract 'data subscribtion' is instantiated by the blockchain network
  // Best practice is to have any Ledger initialization in separate function -- see initLedger()
  async Init(stub) {
    console.info('=========== Instantiated data subscribtion smart contract ===========');
    return shim.success();
  }

  // The Invoke method is called as a result of an application request to run the Smart Contract
  // 'fabcar'. The calling application program has also specified the particular smart contract
  // function to be called, with arguments
  async Invoke(stub) {
    let ret = stub.getFunctionAndParameters();
    console.info(ret);

    let method = this[ret.fcn];
    if (!method) {
      console.error('no function of name:' + ret.fcn + ' found');
      throw new Error('Received unknown function ' + ret.fcn + ' invocation');
    }
    try {
      let payload = await method(stub, ret.params);
      return shim.success(payload);
    } catch (err) {
      console.log(err);
      return shim.error(err);
    }
  }

  async queryCatalogs(stub, args) {
    if (args.length != 1) {
      throw new Error('Incorrect number of arguments. Expecting Catalog BRN ex: brn:bla:data:::data-catalog-id-1');
    }
    let catalog = args[0];

    let catalogAsBytes = await stub.getState(catalog); //get the catalog from chaincode state
    if (!catalogAsBytes || catalogAsBytes.toString().length <= 0) {
      throw new Error(catalog + ' does not exist: ');
    }
    console.log(catalogAsBytes.toString());
    return catalogAsBytes;
  }

  async initLedger(stub, args) {
    console.info('============= START : Initialize Ledger ===========');
    let catalogs = [];
    catalogs.push({
        BRN: 'brn:bla:data:::data-catalog-id-1',
        Layers: 1,
        Description: 'Automotive',
        Version: 'none',
        Owner: 'Tomoko',
        Type: 'versioned'
    });

    for (let i = 0; i < catalogs.length; i++) {
        await stub.putState('CAT' + i, Buffer.from(JSON.stringify(catalogs[i])));
        console.info('Added <--> ', catalogs[i]);
    }
    console.info('============= END : Initialize Ledger ===========');
  }

  async createListing(stub, args) {
    console.info('============= START : Create data listing ===========');
    if (args.length != 5) {
      throw new Error('Incorrect number of arguments. Expecting 5');
    }

    var listing = {
        BRN: args[0],
        Layers: args[1],
        Version: args[2],
        Owner: args[3],
        Type: args[4]
    };

    await stub.putState(args[0], Buffer.from(JSON.stringify(listing)));
    console.info('============= END : Create data listing ===========');
  }

  async queryAllListings(stub, args) {

    let startKey = 'CAT0';
    let endKey = 'CAT9999';

    let iterator = await stub.getStateByRange(startKey, endKey);

    let allResults = [];
    while (true) {
      let res = await iterator.next();

      if (res.value && res.value.value.toString()) {
        let jsonRes = {};
        console.log(res.value.value.toString('utf8'));

        jsonRes.Key = res.value.key;
        try {
          jsonRes.Record = JSON.parse(res.value.value.toString('utf8'));
        } catch (err) {
          console.log(err);
          jsonRes.Record = res.value.value.toString('utf8');
        }
        allResults.push(jsonRes);
      }
      if (res.done) {
        console.log('end of data');
        await iterator.close();
        console.info(allResults);
        return Buffer.from(JSON.stringify(allResults));
      }
    }
  }

  async subscribeToListing(stub, args) {
    console.info('============= START : subscribeToListing ===========');
    if (args.length != 2) {
      throw new Error('Incorrect number of arguments. Expecting 2');
    }

    let catalogAsBytes = await stub.getState(args[0]);
    let catalog = JSON.parse(catalogAsBytes);
    catalog.owner = args[1];

    await stub.putState(args[0], Buffer.from(JSON.stringify(catalog)));
    console.info('============= END : changeCarOwner ===========');
  }
};

shim.start(new Chaincode());
