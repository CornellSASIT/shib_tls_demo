const fs = require('fs');
const https = require('https');
const express = require('express')


const app = express();

app.get('/', (req, res) => {
  res.send('Hello World!')
})

https
  .createServer(
    {
      cert: fs.readFileSync('certs/server-crt.pem'),
      key: fs.readFileSync('certs/server-key.pem'),
      ca: fs.readFileSync('certs/client-ca-crt.pem'),
      requestCert: true,
      // As specified as "true", so no unauthenticated traffic
      // will make it to the specified route specified
      rejectUnauthorized: true
    },
    app
  )
  .listen(9443);
