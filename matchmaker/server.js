import http from "node:http";
import { spawn } from "node:child_process";

const HTTP_PORT = parseInt(process.env.HTTP_PORT || "3000", 10);
const PORT_START = parseInt(process.env.PORT_RANGE_START || "7777", 10);
const PORT_END = parseInt(process.env.PORT_RANGE_END || "7791", 10);

/** @type {Set<number>} */
const freePorts = new Set();
for (let p = PORT_START; p <= PORT_END; p++) {
  freePorts.add(p);
}
console.log(
  `[Matchmaker] Port pool: ${PORT_START}–${PORT_END} (${freePorts.size} ports)`
);

const CODE_CHARS = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"; // no 0/O/1/I/L
const CODE_LENGTH = 6;

/** @type {Map<string, number>} */ // code → port
const roomCodes = new Map();

function generateCode() {
  let code;
  do {
    code = "";
    for (let i = 0; i < CODE_LENGTH; i++) {
      code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
    }
  } while (roomCodes.has(code));
  return code;
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ status: "ok" }));
});

server.listen(HTTP_PORT, () => {
  console.log(`[Matchmaker] HTTP server listening on port ${HTTP_PORT}`);
});
