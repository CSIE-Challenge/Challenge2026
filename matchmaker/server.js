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

/** @type {Map<string, import("child_process").ChildProcess>} */
const children = new Map();

const GODOT_BIN = process.env.GODOT_BIN || "godot";

function spawnGodot(port) {
  const args = [
    "--headless",
    "--path",
    process.env.GODOT_PROJECT_PATH || ".",
    "--",
    "--server",
    "--port",
    String(port),
  ];
  const proc = spawn(GODOT_BIN, args, {
    stdio: "pipe",
    detached: false,
  });
  proc.stdout.on("data", (data) => {
    console.log(`[Godot:${port}] ${data.toString().trim()}`);
  });
  proc.stderr.on("data", (data) => {
    console.error(`[Godot:${port}] ${data.toString().trim()}`);
  });
  return proc;
}

/** @type {Map<string, ReturnType<typeof setTimeout>>} */
const expireTimers = new Map();

function parseBody(req) {
  return new Promise((resolve) => {
    let body = "";
    req.on("data", (chunk) => (body += chunk));
    req.on("end", () => {
      try {
        resolve(JSON.parse(body));
      } catch {
        resolve({});
      }
    });
  });
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  const method = req.method;

  res.setHeader("Content-Type", "application/json");

  if (method === "POST" && url.pathname === "/room") {
    if (freePorts.size === 0) {
      res.writeHead(503);
      res.end(JSON.stringify({ error: "no free ports" }));
      return;
    }

    const port = freePorts.values().next().value;
    freePorts.delete(port);
    const code = generateCode();

    const proc = spawnGodot(port);
    children.set(code, proc);
    roomCodes.set(code, port);

    const timer = setTimeout(() => expireRoom(code), 60_000);
    expireTimers.set(code, timer);

    console.log(`[Matchmaker] Room ${code} → port ${port} (pid ${proc.pid})`);
    res.writeHead(200);
    res.end(JSON.stringify({ code, port }));
    return;
  }

  if (method === "POST" && url.pathname === "/join") {
    const body = await parseBody(req);
    const code = body.code?.toUpperCase?.() || "";

    if (!roomCodes.has(code)) {
      res.writeHead(404);
      res.end(JSON.stringify({ error: "room not found" }));
      return;
    }

    const timer = expireTimers.get(code);
    if (!timer) {
      res.writeHead(410);
      res.end(JSON.stringify({ error: "room expired" }));
      return;
    }

    clearTimeout(timer);
    expireTimers.delete(code);

    const port = roomCodes.get(code);
    console.log(`[Matchmaker] Room ${code} joined on port ${port}`);
    res.writeHead(200);
    res.end(JSON.stringify({ port }));
    return;
  }

  res.writeHead(404);
  res.end(JSON.stringify({ error: "not found" }));
});

function expireRoom(code) {
  console.log(`[Matchmaker] Room ${code} expiry stub — cleaning up`);
  const port = roomCodes.get(code);
  if (port !== undefined) {
    freePorts.add(port);
  }
  roomCodes.delete(code);
  const timer = expireTimers.get(code);
  if (timer) {
    clearTimeout(timer);
    expireTimers.delete(code);
  }
}

server.listen(HTTP_PORT, () => {
  console.log(`[Matchmaker] HTTP server listening on port ${HTTP_PORT}`);
});
