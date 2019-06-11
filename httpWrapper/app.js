const express = require('express');
const cookieParser = require('cookie-parser');
const fileUpload = require('express-fileupload');
const logger = require('morgan');
const SwaggerExpress = require('swagger-express-mw');
const SwaggerUi = require('swagger-tools/middleware/swagger-ui');

const app = express();

module.exports = new Promise(((resolve, reject) => {
  const config = {
    appRoot: __dirname,
    swaggerFile: 'api/swagger/swagger.json'
  };

  SwaggerExpress.create(config, (error, swaggerExpress) => {
    if (error) {
      reject(error);
    }

    app.use(logger('dev'));
    app.use(fileUpload({}));
    app.use(express.json());
    app.use(express.urlencoded({ extended: false }));
    app.use(cookieParser());
    app.use(SwaggerUi(swaggerExpress.runner.swagger));

    swaggerExpress.register(app);

    app.use((err, req, res, next) => { // eslint-disable-line no-unused-vars
      Object.defineProperty(err, 'message', { enumerable: true });
      if (err.errors) {
        err.errors.forEach((val) => {
          delete val.errors;
        });
      }

      res.setHeader('Content-Type', 'application/json');
      console.log(JSON.stringify(err));
      res.end(JSON.stringify(err));
    });

    const port = process.env.PORT || 3000;
    app.listen(port, () => {
      console.log('listening on: ', port);
      resolve(app);
    });
  });
}));
