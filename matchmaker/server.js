import fs from "node:fs";
import http from "node:http";
import crypto from "node:crypto";
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
const GAME_IP = process.env.GAME_IP || "127.0.0.1";

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

/**
 * @typedef {Object} Room
 * @property {string} code
 * @property {number} port
 * @property {string[]} playerIds
 * @property {Set<string>} readyPlayerIds
 * @property {boolean} gameStarted
 * @property {import("child_process").ChildProcess} process
 * @property {ReturnType<typeof setTimeout>} expireTimer
 * @property {ReturnType<typeof setTimeout>|null} readyTimer
 */

/** @type {Map<string, Room>} */
const rooms = new Map();

function generateCode() {
    let code;
    do {
        code = "";
        for (let i = 0; i < CODE_LENGTH; i++) {
            code += CODE_CHARS[Math.floor(Math.random() * CODE_CHARS.length)];
        }
    } while (rooms.has(code));
    return code;
}

function generatePlayerId() {
    return crypto.randomUUID();
}

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

function expireRoom(code) {
    console.log(`[Matchmaker] Room ${code} expired (60s), killing Godot`);
    const room = rooms.get(code);
    if (!room) return;
    if (room.process) {
        room.process.kill("SIGTERM");
        const forceKill = setTimeout(() => {
            if (room.process.exitCode === null) room.process.kill("SIGKILL");
        }, 5000);
        room.process.on("exit", () => clearTimeout(forceKill));
    }
    cleanupRoom(code);
}

function expireReady(code) {
    console.log(`[Matchmaker] Room ${code} ready timer expired (90s), cleaning up`);
    const room = rooms.get(code);
    if (!room) return;
    if (room.process) {
        room.process.kill("SIGTERM");
    }
    cleanupRoom(code);
}

function cleanupRoom(code) {
    const room = rooms.get(code);
    if (!room) return;
    if (room.port !== undefined) {
        freePorts.add(room.port);
    }
    if (room.expireTimer) {
        clearTimeout(room.expireTimer);
    }
    if (room.readyTimer) {
        clearTimeout(room.readyTimer);
    }
    rooms.delete(code);
    console.log(`[Matchmaker] Room ${code} cleaned up, port ${room.port} freed`);
}

function findRoomCodeByProcess(proc) {
    for (const [code, room] of rooms) {
        if (room.process === proc) return code;
    }
    return null;
}

const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://${req.headers.host}`);
    const method = req.method;

    res.setHeader("Content-Type", "application/json");

    // ── POST /qiaohu/room ──────────────────────────────────────────
    if (method === "POST" && url.pathname === "/qiaohu/room") {
        if (freePorts.size === 0) {
            res.writeHead(503);
            res.end(JSON.stringify({ error: "no free ports" }));
            return;
        }

        const port = freePorts.values().next().value;
        freePorts.delete(port);
        const code = generateCode();
        const playerId = generatePlayerId();

        let proc;
        try {
            proc = spawnGodot(port);
        } catch (err) {
            console.error(`[Matchmaker] Failed to spawn Godot: ${err.message}`);
            freePorts.add(port);
            res.writeHead(500);
            res.end(JSON.stringify({ error: "failed to start game server" }));
            return;
        }

        const room = {
            code,
            port,
            playerIds: [playerId],
            readyPlayerIds: new Set(),
            gameStarted: false,
            process: proc,
            expireTimer: setTimeout(() => expireRoom(code), 60_000),
            readyTimer: null,
        };
        rooms.set(code, room);

        console.log(
            `[Matchmaker] Room ${code} → port ${port} (pid ${proc.pid})`,
        );
        res.writeHead(200);
        res.end(JSON.stringify({
            code,
            game_ip: GAME_IP,
            game_port: port,
            player_id: playerId,
        }));
        return;
    }

    // ── POST /qiaohu/join ──────────────────────────────────────────
    if (method === "POST" && url.pathname === "/qiaohu/join") {
        const body = await parseBody(req);
        const code = body.code?.toUpperCase?.() || "";

        const room = rooms.get(code);
        if (!room) {
            res.writeHead(404);
            res.end(JSON.stringify({ error: "room not found" }));
            return;
        }

        if (!room.expireTimer) {
            res.writeHead(410);
            res.end(JSON.stringify({ error: "room expired" }));
            return;
        }

        clearTimeout(room.expireTimer);
        room.expireTimer = null;

        const playerId = generatePlayerId();
        room.playerIds.push(playerId);

        room.readyTimer = setTimeout(() => expireReady(code), 90_000);

        console.log(`[Matchmaker] Room ${code} joined, ${room.playerIds.length} players`);
        res.writeHead(200);
        res.end(JSON.stringify({
            game_ip: GAME_IP,
            game_port: room.port,
            player_id: playerId,
        }));
        return;
    }

    // ── POST /qiaohu/ready ─────────────────────────────────────────
    if (method === "POST" && url.pathname === "/qiaohu/ready") {
        const body = await parseBody(req);
        const code = body.code?.toUpperCase?.() || "";
        const playerId = body.player_id || "";

        const room = rooms.get(code);
        if (!room) {
            res.writeHead(404);
            res.end(JSON.stringify({ error: "room not found" }));
            return;
        }

        if (room.gameStarted) {
            res.writeHead(410);
            res.end(JSON.stringify({ error: "game already started" }));
            return;
        }

        if (!room.playerIds.includes(playerId)) {
            res.writeHead(403);
            res.end(JSON.stringify({ error: "invalid player_id" }));
            return;
        }

        room.readyPlayerIds.add(playerId);

        if (
            room.playerIds.length >= 2 &&
            room.readyPlayerIds.size >= room.playerIds.length
        ) {
            room.gameStarted = true;
            if (room.readyTimer) {
                clearTimeout(room.readyTimer);
                room.readyTimer = null;
            }
            console.log(`[Matchmaker] Room ${code} both ready, game starting`);
            res.writeHead(200);
            res.end(JSON.stringify({ status: "start" }));
            return;
        }

        res.writeHead(200);
        res.end(JSON.stringify({ status: "waiting" }));
        return;
    }

    // ── GET /qiaohu/status ─────────────────────────────────────────
    if (method === "GET" && url.pathname === "/qiaohu/status") {
        const code = url.searchParams.get("code")?.toUpperCase() || "";

        const room = rooms.get(code);
        if (!room) {
            res.writeHead(404);
            res.end(JSON.stringify({ error: "room not found" }));
            return;
        }

        res.writeHead(200);
        res.end(JSON.stringify({
            player_count: room.playerIds.length,
            ready_count: room.readyPlayerIds.size,
            game_started: room.gameStarted,
        }));
        return;
    }

    res.writeHead(404);
    res.end(JSON.stringify({ error: "not found" }));
});

process.on("SIGTERM", () => {
    console.log("[Matchmaker] Shutting down, killing all Godot instances...");
    for (const [, room] of rooms) {
        if (room.process) room.process.kill("SIGTERM");
    }
    process.exit(0);
});

process.on("SIGINT", () => {
    console.log("[Matchmaker] Interrupted, killing all Godot instances...");
    for (const [, room] of rooms) {
        if (room.process) room.process.kill("SIGTERM");
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
