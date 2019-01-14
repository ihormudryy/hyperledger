'use strict';

const fs = require('fs');
const path = require('path');
const os = require('os');

const log4js = require('log4js');
const logger = log4js.getLogger('SampleWebApp');

const Fabric_Client = require('fabric-client');
const Fabric_CA_Client = require('fabric-ca-client');

const fabric_client = new Fabric_Client();
const store_path = path.join(__dirname, 'tmp');
console.log('Store path:' + store_path);
logger.setLevel('DEBUG');
Fabric_Client.addConfigFile(path.join(__dirname, 'config.json'));

// Create new and single crypto suite
async function createCryptoSuite(dir_path){
  return Fabric_Client.newDefaultKeyValueStore({ 
    path: dir_path
  }).then((path) => {
    fabric_client.setStateStore(path);
    let crypto_suite = Fabric_Client.newCryptoSuite();
    let crypto_store = Fabric_Client.newCryptoKeyStore({path: dir_path});
    crypto_suite.setCryptoKeyStore(crypto_store);
    fabric_client.setCryptoSuite(crypto_suite);
    return crypto_suite;
  }).catch((err) => {
    throw new Error('Failed to createCryptoSuite ' + err);
  });
}

async function registerIdentities(org, assets) {
  fabric_client.setUserContext(assets.admin);
  const user = org['server-hostname'] + '_' + Math.random().toString(36).substring(2);
  const secret = user + '-pwd';
  assets.fabric_ca_client.enroll({
    enrollmentID: user,
    enrollmentSecret: secret
  }).then((enrollment) => {
  //assets.crypto.generateKey({algorithm: 'ECDSA', ephemeral: true}).then((key) => {
    return fabric_client.createUser(
    {
      username: user,
      mspid: assets.mspid,
      cryptoContent: { 
        privateKeyPEM: enrollment.key.toBytes(), 
        signedCertPEM: enrollment.certificate
      }
    });
  }).then((new_user) => {
    /*
    assets.fabric_ca_client.register({
      enrollmentID: user,
      enrollmentSecret: secret,
      affiliation: assets.affiliation.result.name,
      role: "member",
      attrs: [
        { name: "hf.Registrar.Roles", value: "Cleint" },
        { name: "hf.Registrar.Attributes", value: "*" },
        { name: "hf.Revoker", value: "true" },
        { name: "hf.GenCTL", value: "true" },
        { name: "member", value: "true:ecert" },
        { name: "abac.init", value: "true:ecert" },
        { name: "ecert", value: "default", ecert: true }
      ]
    },
    new_user)
    */
    if (new_user) {
      console.log(new_user._name + ' was created');
      return new_user;
    } else {
      console.log(new_user._name + ' failed to create');
    }
  }).catch((err) => {
    console.error('Failed to register client on the peer: ' + err);
  });
}

async function createCaClient(org, cryptoSuite) {
  const pem_file = fs.readFileSync(org.root_cert, 'utf-8');
  let	tlsOptions = {
    trustedRoots: [pem_file],
    verify: false
  };
  const { url, name } = org.ca;
  return new Fabric_CA_Client(url, tlsOptions, name, cryptoSuite);
}

async function enrollOrganizationAdmins(org, fabric_ca_client) {
  const user = org.admin.username;
  const secret = org.admin.secret;
  let results = {};
  await fabric_client.getUserContext(user, true).then((user_from_store) => {
    if (user_from_store && user_from_store.isEnrolled()) {
      console.log('Successfully loaded admin from persistence');
      fabric_client.setUserContext(user_from_store);
      results.admin = user_from_store;
      return user_from_store;
    } else {
      return fabric_ca_client.enroll({
        enrollmentID: user,
        enrollmentSecret: secret
      }).then((enrollment) => {
        console.log('Successfully enrolled admin user ' + user + ' to ' + org.name);
        results.enrollment = enrollment;
        return fabric_client.createUser(
        {
          username: user,
          mspid: org.mspid,
          cryptoContent: { 
            privateKeyPEM: enrollment.key.toBytes(), 
            signedCertPEM: enrollment.certificate 
          }
        });
      }).then((user_admin) => {
        results.admin = user_admin;
        fabric_client.setUserContext(user_admin);
        return fabric_ca_client.newAffiliationService();
      }).then((affiliation_service) => {
        results.affiliation_name = org.mspid + '_' + Math.random().toString(36).substring(2);
        console.log("Affiliation created named: " + results.affiliation_name);
        return affiliation_service.create({ name: results.affiliation_name }, results.admin);
      }).then((affiliation) => {
        results.affiliation = affiliation;
        results.admin.setEnrollment(results.enrollment.key, results.enrollment.certificate, org.mspid);
        let username = 'admin_' + Math.random().toString(36).substring(2);
        fabric_ca_client.register({
          enrollmentID: username,
          enrollmentSecret: secret,
          type: org.type
        }, results.admin).then((peer) => {
          console.log(peer + " was registered!!!");
        })

        let attrs = org.type == "orderer" ? [{ name: "admin", value: "true", ecert: true }] : [
          { name: "hf.Registrar.Roles", value: "Admin" },
          { name: "hf.Registrar.Attributes", value: "*" },
          { name: "hf.Revoker", value: "true" },
          { name: "admin", value: "true", ecert: true },
          { name: "abac.init", value: "true", ecert: true },
          { name: "ecert", value: "default", ecert: true }
        ];

        fabric_ca_client.register(
          {
            enrollmentID: username,
            enrollmentSecret: 'adminpw',
            affiliation: results.affiliation.result.name,
            role: "admin",
            attrs: attrs
          },
          results.admin
        );
        console.log("Registered user named: " + user);
        return results.admin;
      }).catch((err) => {
        console.error('Failed to register user. Error: ' + err.stack ? err.stack : err);
        throw new Error('Failed to register user');
      });
    }
  }).then((active_user) => {
    console.log('Assigned the admin user to the fabric client: ' + active_user._name);
    return active_user;
  }).catch((err) => {
    console.error('Failed to enroll admin: ' + err);
  });
  return results;
}

async function main() {
  const data_raw = fs.readFileSync(path.join(__dirname, 'config.json'), 'utf-8');
  const network = "HomeNetwork";
  const data = JSON.parse(data_raw.toString());
  const crypto = await createCryptoSuite(store_path);
  const channel = fabric_client.newChannel("fakechannel");
  for (let organization in data[network]) {
    if (typeof(data[network][organization]) === "object") {
      const org = data[network][organization];
      org["ca"]["client"] = await createCaClient(org, crypto);
      await enrollOrganizationAdmins(org, org["ca"]["client"]).then(results => {
        org["results"] = results;
        for (let peer in org["peers"]) {
          org["results"].crypto = crypto;
          org["results"].mspid = org.mspid;
          org["results"].fabric_ca_client = org["ca"]["client"];
          registerIdentities(org["peers"][peer], org["results"]).then(user => {
            org["peers"][peer]["user"] = user;
            /*
            const peerObject = fabric_client.newPeer(
              org["peers"][peer].requests,
              {
                pem: fs.readFileSync(org["peers"][peer].tls_cacerts, 'utf-8'),
                'ssl-target-name-override': org["peers"][peer]['server-hostname']
              }
            );
  
            targets.push(peerObject);    // a peer can be the target this way
            channel.addPeer(peerObject);*/
          })
        };
      });
      console.log(fabric_client.getPeersForOrg(org.mspid));
      //console.log(fabric_client.getConfigSetting(network));
    }
  }
}

main();