#!/usr/bin/env node
const http = require('http');

const counts = {};

const server = http.createServer((req, res) => {
  if (req.method === "POST") {
    counts[req.url] = (counts[req.url] || 0) + 1;
    return res.end("counted");
  } else if (req.method === "GET") {
    res.end(JSON.stringify({ counts }));
  }

  res.end();
});

server.listen(3000);