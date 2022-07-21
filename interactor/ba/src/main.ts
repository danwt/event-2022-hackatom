import express from 'express';
import cors from 'cors';
import * as fs from 'fs';
const app = express();
const { exec } = require('child_process');
app.use(cors());

app.get('/', function (_, res) {
  console.log('received');
  res.send(["here is some data"]);
});

interface Req  {
  data:string
}

app.post('/', (req, res) => {
  console.log("body", req.body);
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({"hello":"world"}));
})


const port = 3001;
console.log(`listening on ${port}`);
app.listen(port);
