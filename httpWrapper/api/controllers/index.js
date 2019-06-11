const exec = require('../../utils/exec');
const apiResp = require('../../utils/requestWrapper');

const ping = apiResp(async () => 'pong');

const getChannel = apiResp(async (req) => {
  const { orderer, peerOrgs, randomNumber } = req.query;

  return exec(`/scripts/api.sh getChannel ${orderer} "${peerOrgs}" ${randomNumber}`);
});

const createChannel = apiResp(async (req) => {
  const { randomNumber, orderer, peerOrgs, autojoin } = req.body;

  console.log('body', req.body);

  return exec(`/scripts/api.sh createChannel ${orderer} ${peerOrgs} ${randomNumber} ${autojoin}`);
});

const updateChannel = apiResp(async (req) => {
  const { orderer, newOrg, peerOrgs, randomNumber, peers } = req.body;

  return exec(
    `/scripts/api.sh addOrgToChannel ${orderer} "${peerOrgs}" ${newOrg} ${randomNumber} ${peers}`
  );
});

const updateConsortium = apiResp(async (req) => {
  const { orderer, org, peers } = req.body;

  return exec(`/scripts/api.sh addOrgToConsortium ${orderer} ${org} ${peers}`);
});

module.exports = {
  ping,
  getChannel,
  createChannel,
  updateChannel,
  updateConsortium
};
