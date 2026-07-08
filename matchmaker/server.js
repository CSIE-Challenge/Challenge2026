import http from "node:http";
import { spawn } from "node:child_process";

const HTTP_PORT = parseInt(process.env.HTTP_PORT || "3000", 10);

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ status: "ok" }));
});

server.listen(HTTP_PORT, () => {
  console.log(`[Matchmaker] HTTP server listening on port ${HTTP_PORT}`);
});
