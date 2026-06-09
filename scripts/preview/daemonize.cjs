#!/usr/bin/env node
const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');

const logFile = process.argv[2];
if (!logFile) {
  console.error('Usage: daemonize.cjs <log-file>');
  process.exit(2);
}

const serverPath = path.join(__dirname, 'server.cjs');
const logFd = fs.openSync(logFile, 'a');

try {
  const child = childProcess.spawn(process.execPath, [serverPath], {
    detached: true,
    env: process.env,
    stdio: ['ignore', logFd, logFd]
  });
  child.unref();
  console.log(child.pid);
} finally {
  fs.closeSync(logFd);
}
