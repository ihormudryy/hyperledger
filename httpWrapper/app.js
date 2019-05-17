const express = require('express');
const cookieParser = require('cookie-parser');
const logger = require('morgan');
const SwaggerExpress = require('swagger-express-mw');
const SwaggerUi = require('swagger-tools/middleware/swagger-ui');

const app = express();

module.exports = new Promise(function (resolve, reject) {

  const config = {
    appRoot: __dirname,
    swaggerFile: 'api/swagger/swagger.json'
  };

  SwaggerExpress.create(config, function (err, swaggerExpress) {
    if (err) { throw err; }

    // install middleware
    app.use(logger('dev'));
    app.use(express.json());
    app.use(express.urlencoded({ extended: false }));
    app.use(cookieParser());
    app.use(SwaggerUi(swaggerExpress.runner.swagger));

    swaggerExpress.register(app);

    app.use(function(err, req, res, next) {
      if (typeof err !== 'object') {
        err = {
          message: String(err) // Coerce to string
        };
      } else {
        Object.defineProperty(err, 'message', { enumerable: true });
      }

      res.setHeader('Content-Type', 'application/json');
      console.log(JSON.stringify(err));
      res.end(JSON.stringify(err));
    });

    var port = process.env.PORT || 3000;
    app.listen(port, () => {
      console.log('listening on: ', port);
      resolve(app);
    });
  });
});
