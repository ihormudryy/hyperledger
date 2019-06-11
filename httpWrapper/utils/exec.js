const { exec } = require('child_process');

const execPromise = command => new Promise((resolve, reject) => {
  exec(command,
    (error, stdout, stderr) => {
      console.log(stdout);
      console.log(stderr);
      if (error !== null) {
        return reject(stderr);
      }
      return resolve(stdout);
    });
});

module.exports = execPromise;
