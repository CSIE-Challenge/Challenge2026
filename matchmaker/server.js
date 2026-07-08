import fs from "node:fs";
import http from "node:http";
import { spawn, execSync } from "node:child_process";

// Load .env file if present
const envPath = new URL(".env", import.meta.url).pathname;
if (fs.existsSync(envPath)) {
    for (const line of fs.readFileSync(envPath, "utf8").split("\n")) {
        const trimmed = line.trim();
        if (!trimmed || trimmed.startsWith("#")) continue;
        const eq = trimmed.indexOf("=");
        if (eq === -1) continue;
        const key = trimmed.slice(0, eq).trim();
        const value = trimmed.slice(eq + 1).trim();
        if (key && !process.env[key]) {
            process.env[key] = value;
        }
    }
}

const HTTP_PORT = parseInt(process.env.HTTP_PORT || "3000", 10);
const PORT_START = parseInt(process.env.PORT_RANGE_START || "7777", 10);
const PORT_END = parseInt(process.env.PORT_RANGE_END || "7791", 10);

/** @type {Set<number>} */
const freePorts = new Set();
for (let p = PORT_START; p <= PORT_END; p++) {
    freePorts.add(p);
}
console.log(
    `[Matchmaker] Port pool: ${PORT_START}–${PORT_END} (${freePorts.size} ports)`,
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
    proc.on("error", (err) => {
        console.error(
            `[Matchmaker] Godot process error on port ${port}: ${err.message}`,
        );
    });
    proc.on("exit", (exitCode) => {
        const code = findRoomCodeByProcess(proc);
        if (code) {
            console.log(
                `[Matchmaker] Godot for room ${code} exited (code ${exitCode})`,
            );
            cleanupRoom(code);
        }
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

        let proc;
        try {
            proc = spawnGodot(port);
        } catch (err) {
            console.error(`[Matchmaker] Failed to spawn Godot: ${err.message}`);
            freePorts.add(port);
            roomCodes.delete(code);
            res.writeHead(500);
            res.end(JSON.stringify({ error: "failed to start game server" }));
            return;
        }
        children.set(code, proc);
        roomCodes.set(code, port);

        const timer = setTimeout(() => expireRoom(code), 60_000);
        expireTimers.set(code, timer);

        console.log(
            `[Matchmaker] Room ${code} → port ${port} (pid ${proc.pid})`,
        );
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

function cleanupRoom(code) {
    const port = roomCodes.get(code);
    if (port !== undefined) {
        freePorts.add(port);
    }
    roomCodes.delete(code);
    children.delete(code);

    const timer = expireTimers.get(code);
    if (timer) {
        clearTimeout(timer);
        expireTimers.delete(code);
    }
    if (port !== undefined) {
        console.log(`[Matchmaker] Room ${code} cleaned up, port ${port} freed`);
    }
}

function findRoomCodeByProcess(proc) {
    for (const [code, p] of children) {
        if (p === proc) return code;
    }
    return null;
}

function expireRoom(code) {
    console.log(`[Matchmaker] Room ${code} expired, killing Godot`);
    const proc = children.get(code);
    if (proc) {
        proc.kill("SIGTERM");
        const forceKill = setTimeout(() => {
            if (proc.exitCode === null) proc.kill("SIGKILL");
        }, 5000);
        proc.on("exit", () => clearTimeout(forceKill));
    }
    cleanupRoom(code);
}

process.on("SIGTERM", () => {
    console.log("[Matchmaker] Shutting down, killing all Godot instances...");
    for (const [, proc] of children) {
        proc.kill("SIGTERM");
    }
    process.exit(0);
});

process.on("SIGINT", () => {
    console.log("[Matchmaker] Interrupted, killing all Godot instances...");
    for (const [, proc] of children) {
        proc.kill("SIGTERM");
    }
    process.exit(0);
});

console.log(
    "[Matchmaker] Clearing any orphaned Godot processes from previous run...",
);
try {
    execSync("pkill -f 'godot.*--server'", { timeout: 3000 });
    console.log("[Matchmaker] Orphan cleanup complete");
} catch {
    // pkill exits non-zero when no matching processes — that's fine
}

server.listen(HTTP_PORT, () => {
    console.log(`[Matchmaker] HTTP server listening on port ${HTTP_PORT}`);
});
