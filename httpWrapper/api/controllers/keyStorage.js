const fs = require('fs');
const AdmZip = require('adm-zip');
const util = require('util');

const apiResp = require('../../utils/requestWrapper');

const mkdir = util.promisify(fs.mkdir);
const writeFile = util.promisify(fs.writeFile);
const access = util.promisify(fs.access);
const readdir = util.promisify(fs.readdir);

const saveCryptoartifacts = apiResp(async (req) => {
  const { token } = req.body;
  const { cert, key } = req.files;

  await mkdir(`/storage/${token}`);
  await writeFile(`/storage/${token}/${cert.name}`, cert.data);
  await writeFile(`/storage/${token}/${key.name}`, key.data);
});


const returnCryptoartifacts = apiResp(async (req) => {
  const { token } = req.query;
  const archive = new AdmZip();

  await access(`/storage/${token}`);
  const files = await readdir(`/storage/${token}`);
  files.forEach(val => archive.addLocalFile(`/storage/${token}/${val}`));
  return {
    file: archive.toBuffer()
  };
});

module.exports = {
  saveCryptoartifacts,
  returnCryptoartifacts
};
