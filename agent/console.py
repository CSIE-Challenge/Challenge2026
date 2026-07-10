"""
Run the game without a bundle so it won't spawn its own agent; it self-picks a
port and prints both the port and a token:

    godot --headless --path .

Then point this at what it printed (uses uv's python + the source SDK):

    CHALLENGE_WS_URL=ws://127.0.0.1:<port> \
    CHALLENGE_TOKEN=<token> \
    uv run python -i console.py
"""

from __future__ import annotations

import atexit

from api.client_base import GameClientBase

client = GameClientBase.from_env()
client.connect()
atexit.register(client.close)

print(f"connected to {client.host}:{client.port}")
print("try:  client.ping()   client.get_my_energy()")
