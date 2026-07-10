from __future__ import annotations

from collections.abc import Iterator
from enum import Enum


class Vector2:
    """二維向量，傳給遊戲或從遊戲讀回時皆以 ``[x, y]`` 陣列表示。"""

    def __init__(self, x: float = 0.0, y: float = 0.0) -> None:
        self.x = float(x)
        """x 座標"""

        self.y = float(y)
        """y 座標"""

    @classmethod
    def from_list(cls, data: list[float]) -> Vector2:
        """由 ``[x, y]`` 陣列建立一個 Vector2。"""
        return cls(data[0], data[1])

    def __iter__(self) -> Iterator[float]:
        yield self.x
        yield self.y

    def __repr__(self) -> str:
        return f"Vector2({self.x}, {self.y})"


class Direction(Enum):
    """四個基本方向，值為單位 ``(x, y)`` 向量。"""

    UP = (0.0, -1.0)
    DOWN = (0.0, 1.0)
    LEFT = (-1.0, 0.0)
    RIGHT = (1.0, 0.0)
