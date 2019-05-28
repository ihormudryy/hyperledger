
'use strict';

// Bring key classes into scope, most importantly Fabric SDK network class
const fs = require('fs');
const yaml = require('js-yaml');
const { FileSystemWallet, Gateway, X509WalletMixin } = require('fabric-network');

// Specify userName for network access
const user = 'regular_5544@org1.com';
const userName = user + '@org1.com';
const channel = 'channel17086';

async function addToWallet() {

  // Main try/catch block
  try {

      const wallet = new FileSystemWallet('./identity/' + user + '/wallet');

      // Identity to credentials to be stored in the wallet
      const cert = fs.readFileSync('/private/orgs/org1/' + user + '/msp/cert.pem').toString();
      const key = fs.readFileSync('/private/orgs/org1/' + user + '/msp/key.pem').toString();

      // Load credentials into wallet
      const identity = X509WalletMixin.createIdentity('org1MSP', cert, key);

      await wallet.import(user, identity);

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
      identity: user,
      discovery: { 
        enabled: true, 
        asLocalhost: true 
      },
      wallet: wallet
    };

    // Connect to gateway using application specified parameters
    console.log('Connect to Fabric gateway.');

    await gateway.connect(connectionProfile, connectionOptions);
    //console.log(gateway);
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

}).catch((e) => {4
  
  console.log('Issue program exception.');
  console.log(e);
  console.log(e.stack);
  process.exit(-1);

});