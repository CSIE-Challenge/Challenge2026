from __future__ import annotations

import json
from typing import Any

from .structures import Direction, Vector2


def _default(obj: Any) -> Any:
    """Encode the value types json doesn't know natively as ``[x, y]``."""
    if isinstance(obj, Vector2):
        return [obj.x, obj.y]
    if isinstance(obj, Direction):
        return list(obj.value)
    raise TypeError(f"Object of type {type(obj).__name__} is not JSON serializable")


def encode(obj: Any) -> str:
    """Serialize a Python object to a JSON text frame."""
    return json.dumps(obj, default=_default)


def decode(text: str) -> Any:
    """Deserialize a JSON text frame to a Python object."""
    return json.loads(text)
