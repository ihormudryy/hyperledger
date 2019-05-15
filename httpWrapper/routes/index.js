const express = require('express');
const router = express.Router();
const _exec = require('child_process').exec;

const apiResp = (fn) => {
  return async (req, res, next) => {
    try {
      const resp = await fn(req, res, next);
      res.send({
        success: true,
        response: resp
      });
    } catch (err) {
      console.log('ERROR', err);
      res.send({
        success: false,
        error: err
      });
    }
  }
};

const exec = (command) => {
  return new Promise((resolve, reject) => {
    _exec(command,
      (error, stdout, stderr) => {
        console.log(stdout);
        console.log(stderr);
        if (error !== null) {
          return reject(stderr);
        }
        return resolve(stdout);
      })
  });
};

router.get('/ping', apiResp(async () => {
  return 'pong';
}));

router.post('/channel', apiResp(async (req) => {
  const { randomNumber, orderer, peerOrgs, autojoin } = req.body;

  return exec(`/scripts/api.sh createChannel ${orderer} ${peerOrgs} ${randomNumber} ${autojoin}`);
}));

router.post('/add-org', apiResp(async (req) => {
  const { orderer, newOrg, peerOrgs, randomNumber, peers } = req.body;

  return exec(`/scripts/api.sh addOrgToChannel ${orderer} "${peerOrgs}" ${newOrg} ${randomNumber} ${peers}`);
}));

router.post('/add-org-to-consortium', apiResp(async (req) => {
  const { orderer, org, peers } = req.body;

  return exec(`/scripts/api.sh addOrgToConsortium ${orderer} ${org} ${peers}`);
}));

router.get('/channel', apiResp(async (req) => {
  const { orderer, peerOrgs, randomNumber } = req.query;

  return exec(`/scripts/api.sh getChannel ${orderer} "${peerOrgs}" ${randomNumber}`);
}));

module.exports = router;