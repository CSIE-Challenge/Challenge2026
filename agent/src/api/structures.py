from __future__ import annotations

import math
from collections.abc import Iterator
from enum import Enum


class Vector2:
    """二維向量。正的 x 表示往右，正的 y 表示往下。"""

    def __init__(self, x: float = 0.0, y: float = 0.0) -> None:
        self.x = float(x)
        """x 座標"""

        self.y = float(y)
        """y 座標"""

        # 2D 旋轉矩陣

    @classmethod
    def from_list(cls, data: list[float]) -> Vector2:
        """由 ``[x, y]``陣列 或 ``(x, y)``元組 建立一個 Vector2。"""
        return cls(data[0], data[1])

    def __iter__(self) -> Iterator[float]:
        yield self.x
        yield self.y

    def __repr__(self) -> str:
        return f"Vector2({self.x}, {self.y})"

    def __add__(self, other: Vector2) -> Vector2:
        """向量加法 (v1 + v2)"""
        return Vector2(self.x + other.x, self.y + other.y)

    def __sub__(self, other: Vector2) -> Vector2:
        """向量減法 (v1 - v2)"""
        return Vector2(self.x - other.x, self.y - other.y)

    def __mul__(self, other: float | int) -> Vector2:
        """
        向量乘法。
        支援純量相乘 (v1 * 2)
        """
        if isinstance(other, (int, float)):
            return Vector2(self.x * other, self.y * other)
        return NotImplemented

    def __rmul__(self, other: float | int) -> Vector2:
        """支援反向純量相乘 (2 * v1)"""
        return self.__mul__(other)

    def __truediv__(self, other: float | int) -> Vector2:
        """
        向量除法。
        支援純量相除 (v1 / 2)
        """
        if isinstance(other, (int, float)):
            return Vector2(self.x / other, self.y / other)
        return NotImplemented

    def __neg__(self) -> Vector2:
        """負向量 (-v1)"""
        return Vector2(-self.x, -self.y)

    def __eq__(self, other: object) -> bool:
        """判斷相等 (v1 == v2)"""
        if not isinstance(other, Vector2):
            return False
        return math.isclose(self.x, other.x, abs_tol=1e-5) and math.isclose(
            self.y, other.y, abs_tol=1e-5
        )

    def __ne__(self, other: object) -> bool:
        """判斷不相等 (v1 != v2)"""
        return not self.__eq__(other)

    @property
    def magnitude(self) -> float:
        """向量的長度"""
        return math.hypot(self.x, self.y)

    @property
    def sqr_magnitude(self) -> float:
        """向量長度的平方"""
        return self.x**2 + self.y**2

    @property
    def normalized(self) -> Vector2:
        """回傳長度為 1 的新向量，不會改變原向量"""
        mag = self.magnitude
        if mag > 1e-5:
            return self / mag
        return Vector2(0.0, 0.0)

    def normalize(self) -> None:
        """將此向量自身的長度化為 1"""
        mag = self.magnitude
        if mag > 1e-5:
            self.x /= mag
            self.y /= mag
        else:
            self.x = 0.0
            self.y = 0.0

    @staticmethod
    def dot(a: Vector2, b: Vector2) -> float:
        """內積"""
        return a.x * b.x + a.y * b.y

    @staticmethod
    def distance(a: Vector2, b: Vector2) -> float:
        """計算兩點之間的距離"""
        return (a - b).magnitude

    @staticmethod
    def angle(a: Vector2, b: Vector2) -> float:
        """
        計算向量 (由 a 指向 b) 與 x 軸正向之間的夾角 (單位：弧度 rad)。
        回傳值範圍為 -π 到 π。
        """
        return math.atan2(b.y - a.y, b.x - a.x)

    @staticmethod
    def angle_deg(a: Vector2, b: Vector2) -> float:
        """
        計算向量 (由 a 指向 b) 與 x 軸正向之間的夾角 (單位：度 deg)。
        回傳值範圍為 -180 到 180。
        """
        return math.degrees(math.atan2(b.y - a.y, b.x - a.x))

    def rotate(self, rad: float) -> Vector2:
        """將該向量順時針旋轉 ``rad`` 弧度，回傳新的 Vector2。"""
        cos_theta = math.cos(rad)
        sin_theta = math.sin(rad)

        new_x = self.x * cos_theta - self.y * sin_theta
        new_y = self.x * sin_theta + self.y * cos_theta

        return Vector2(new_x, new_y)

    def rotate_deg(self, deg: float) -> Vector2:
        """將該向量順時針旋轉 ``deg`` 角度，回傳新的 Vector2。"""
        return self.rotate(math.radians(deg))

    def lerp(self, to: Vector2, weight: float) -> Vector2:
        """
        在該向量與新向量之間以線性插值產生新向量。
        weight (權重) 會被自動限制在 0.0 到 1.0 之間。
        當 weight = 0 時回傳原向量, weight = 1 時回傳目標向量。
        """
        t = max(0.0, min(1.0, float(weight)))
        new_x = self.x + (to.x - self.x) * t
        new_y = self.y + (to.y - self.y) * t

        return Vector2(new_x, new_y)


class Direction(Enum):
    """四個基本方向，值為單位 ``(x, y)`` 向量。"""

    UP = (0.0, -1.0)
    DOWN = (0.0, 1.0)
    LEFT = (-1.0, 0.0)
    RIGHT = (1.0, 0.0)
