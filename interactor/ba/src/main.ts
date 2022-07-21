import express from 'express';
import cors from 'cors';
const app = express();
import { execa } from 'execa';
app.use(cors());
app.use(express.json());

async function doCmd(cmd: string) {
  let res = undefined
  try {
    res = await execa(cmd, [], {
      cwd: "/Users/danwt/Documents/work/hackatom/testnet",
      all: true
    });
  } catch (error) {
    console.log(error);
    /*
    {
      message: 'Command failed with ENOENT: unknown command spawn unknown ENOENT',
      errno: -2,
      code: 'ENOENT',
      syscall: 'spawn unknown',
      path: 'unknown',
      spawnargs: ['command'],
      originalMessage: 'spawn unknown ENOENT',
      shortMessage: 'Command failed with ENOENT: unknown command spawn unknown ENOENT',
      command: 'unknown command',
      escapedCommand: 'unknown command',
      stdout: '',
      stderr: '',
      all: '',
      failed: true,
      timedOut: false,
      isCanceled: false,
      killed: false
    }
    */
  }
  console.log(res);
}

interface Req {
  kind: string
}

async function handleReq(r: Req) {
  console.log(r);
  if (r.kind === 'helloWorld') {
    doCmd('./0_helloWorld.sh')
  }
  if (r.kind === 'preconditions') {
    doCmd('./1_preconditions.sh')
  }
  if (r.kind === 'killAndClean') {
    doCmd('./2_killAndClean.sh')
  }
  if (r.kind === 'launch') {
    doCmd('./3_launch.sh')
  }
  if (r.kind === 'relay') {
    doCmd('./4_relay.sh')
  }
}

app.post('/', (req, res) => {
  const r = req.body as Req
  handleReq(r)
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({ "received": "true" }));
})


const port = 3001;
console.log(`listening on ${port}`);
app.listen(port);
