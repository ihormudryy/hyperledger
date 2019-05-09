
'use strict';

// Bring key classes into scope, most importantly Fabric SDK network class
const fs = require('fs');
const yaml = require('js-yaml');
const { FileSystemWallet, Gateway, X509WalletMixin } = require('fabric-network');

// Specify userName for network access
const userName = 'user-org11@org1.com';
const channel = 'channel26704';

async function addToWallet() {

  // Main try/catch block
  try {

      const wallet = new FileSystemWallet('./identity/' + userName + '/wallet');

      // Identity to credentials to be stored in the wallet
      const cert = fs.readFileSync('/private/orgs/org1/user/msp/signcerts/cert.pem').toString();
      const key = fs.readFileSync('/private/orgs/org1/user/msp/keystore/bf3205e4e8d312e6bb109024a908635dc69a2e3bdd83534f6f73745a35558827_sk').toString();

      // Load credentials into wallet
      const identity = X509WalletMixin.createIdentity('org1MSP', cert, key);

      await wallet.import(userName, identity);

      return wallet;

  } catch (error) {
      console.log(`Error adding to wallet. ${error}`);
      console.log(error.stack);
  }

}

// Main program function
async function main() {

  // A gateway defines the peers used to access Fabric networks
  const gateway = new Gateway();
  
  // Main try/catch block
  try {
    
    // Load connection profile; will be used to locate a gateway
    let connectionProfile = yaml.safeLoad(fs.readFileSync('./gateway/connectionProfile.yaml', 'utf8'));
    let wallet = await addToWallet();

    // Set connection options; identity and wallet
    let connectionOptions = {
      identity: userName,
      discovery: { 
        enabled: false, 
        asLocalhost: true 
      },
      wallet: wallet
    };

    // Connect to gateway using application specified parameters
    console.log('Connect to Fabric gateway.');
    await gateway.connect(connectionProfile, connectionOptions);

    const network = await gateway.getNetwork(channel);

  } catch (error) {

    console.log(`Error processing transaction. ${error}`);
    console.log(error.stack);

  } finally {

    // Disconnect from the gateway
    console.log('Disconnect from Fabric gateway.')
    gateway.disconnect();

  }
}

main().then(() => {

  console.log('Issue program complete.');

}).catch((e) => {
  
  console.log('Issue program exception.');
  console.log(e);
  console.log(e.stack);
  process.exit(-1);

});