const apiResp = fn => async (req, res, next) => {
  try {
    const resp = await fn(req, res, next);
    if (resp.file) {
      res.attachment('files.zip');
      return res.send(resp.file);
    }
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
};

module.exports = apiResp;
