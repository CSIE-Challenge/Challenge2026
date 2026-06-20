from __future__ import annotations

import json
from typing import Any


def encode(obj: Any) -> str:
    """Serialize a Python object to a JSON text frame."""
    return json.dumps(obj)


def decode(text: str) -> Any:
    """Deserialize a JSON text frame to a Python object."""
    return json.loads(text)
