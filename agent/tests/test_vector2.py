from __future__ import annotations

import math

from api.structures import Vector2


def section(title: str) -> None:
    print("\n" + "=" * 50)
    print(title)
    print("=" * 50)


v_from_list = Vector2.from_list([1.5, -2.5])
print("from_list([1.5, -2.5])    ->", repr(v_from_list))

v_from_tuple = Vector2.from_list((7, 8))
print("from_list((7, 8))         ->", repr(v_from_tuple))

# ---------------------------------------------------------------------------
# 運算子：+ - * / 負號
# ---------------------------------------------------------------------------
section("運算子：+ - * (純量) / (純量) 負號")

a = Vector2(2, 3)
b = Vector2(5, 1)
print("a =", a)
print("b =", b)
print("a + b                     ->", a + b)
print("a - b                     ->", a - b)
print("a * 2                     ->", a * 2)
print("a * 0.5                   ->", a * 0.5)
print("3 * a  (__rmul__)         ->", 3 * a)
print("a / 2                     ->", a / 3)
print("-a  (__neg__)             ->", -a)

# 不支援的乘法/除法型別，應回傳 NotImplemented -> Python 會丟 TypeError
print("\n預期不支援的操作：")
try:
    result = a * b  # type: ignore[operator]
    print("a * b (向量*向量)         ->", result)
except TypeError as e:
    print("a * b (向量*向量)         -> TypeError:", e)

try:
    result = a / b  # type: ignore[operator]
    print("a / b (向量/向量)         ->", result)
except TypeError as e:
    print("a / b (向量/向量)         -> TypeError:", e)


# ---------------------------------------------------------------------------
# 相等 / 不相等
# ---------------------------------------------------------------------------
section("__eq__ / __ne__ (含浮點容差)")

print("Vector2(1, 2) == Vector2(1, 2)          ->", Vector2(1, 2) == Vector2(1, 2))
print("Vector2(1, 2) == Vector2(1, 3)          ->", Vector2(1, 2) == Vector2(1, 3))
print(
    "Vector2(1, 2) == Vector2(1.000001, 2)   ->",
    Vector2(1, 2) == Vector2(1.000001, 2),
)
print("Vector2(1, 2) != Vector2(1, 3)          ->", Vector2(1, 2) != Vector2(1, 3))
print("Vector2(1, 2) == '不是向量'              ->", Vector2(1, 2) == [1, 2])


# ---------------------------------------------------------------------------
# magnitude / sqr_magnitude
# ---------------------------------------------------------------------------
section("magnitude / sqr_magnitude")

v = Vector2(3, 4)
print("v =", v)
print("v.magnitude               ->", v.magnitude, "(預期 5.0)")
print("v.sqr_magnitude           ->", v.sqr_magnitude, "(預期 25.0)")
print("Vector2(0, 0).magnitude   ->", Vector2(0, 0).magnitude)


# ---------------------------------------------------------------------------
# normalized (不改變原向量) / normalize (改變自身)
# ---------------------------------------------------------------------------
section("normalized (property) / normalize (method)")

v = Vector2(3, 4)
n = v.normalized
print("v                         ->", v, "(原向量不變)")
print("v.normalized              ->", n, "-> magnitude =", n.magnitude)
print("Vector2(0, 0).normalized  ->", Vector2(0, 0).normalized, "(零向量特例)")

v2 = Vector2(3, 4)
v2.normalize()
print("normalize() 後的 v2       ->", v2, "-> magnitude =", v2.magnitude)

v_zero = Vector2(0, 0)
v_zero.normalize()
print("零向量 normalize() 後      ->", v_zero)


# ---------------------------------------------------------------------------
# dot / distance
# ---------------------------------------------------------------------------
section("dot / distance (staticmethod)")

a = Vector2(1, 2)
b = Vector2(3, 4)
print("a =", a, " b =", b)
print("Vector2.dot(a, b)         ->", Vector2.dot(a, b), "(預期 1*3 + 2*4 = 11)")
print("Vector2.dot(a, a)         ->", Vector2.dot(a, a), "(= sqr_magnitude)")

p1 = Vector2(0, 0)
p2 = Vector2(3, 4)
print("Vector2.distance((0,0),(3,4)) ->", Vector2.distance(p1, p2), "(預期 5.0)")


# ---------------------------------------------------------------------------
# angle / angle_deg
# ---------------------------------------------------------------------------
section("angle / angle_deg (staticmethod, 由 a 指向 b)")

origin = Vector2(0, 0)
right = Vector2(1, 0)
up_down = Vector2(0, 1)  # 注意：正 y 往下
diag = Vector2(1, 1)

print("angle((0,0)->(1,0))       ->", Vector2.angle(origin, right), "rad (預期 0)")
print("angle_deg((0,0)->(1,0))   ->", Vector2.angle_deg(origin, right), "deg (預期 0)")
print(
    "angle_deg((0,0)->(0,1))   ->", Vector2.angle_deg(origin, up_down), "deg (預期 90)"
)
print("angle_deg((0,0)->(1,1))   ->", Vector2.angle_deg(origin, diag), "deg (預期 45)")
print(
    "angle_deg((0,0)->(-1,0))  ->",
    Vector2.angle_deg(origin, Vector2(-1, 0)),
    "deg (預期 180)",
)


# ---------------------------------------------------------------------------
# rotate / rotate_deg
# ---------------------------------------------------------------------------
section("rotate / rotate_deg (順時針，回傳新向量)")

v = Vector2(1, 0)
print("v =", v)
print("v.rotate(pi/2)            ->", v.rotate(math.pi / 2))
print("v.rotate_deg(90)          ->", v.rotate_deg(90))
print("v.rotate_deg(180)         ->", v.rotate_deg(180))
print("v.rotate_deg(360)         ->", v.rotate_deg(360))
print("原向量 v (應不變)          ->", v)


# ---------------------------------------------------------------------------
# lerp
# ---------------------------------------------------------------------------
section("lerp (線性插值，weight 夾在 0~1)")

start = Vector2(0, 0)
end = Vector2(10, 20)
print("start =", start, " end =", end)
print("lerp weight=0.0           ->", start.lerp(end, 0.0), "(預期 start)")
print("lerp weight=0.5           ->", start.lerp(end, 0.5))
print("lerp weight=1.0           ->", start.lerp(end, 1.0), "(預期 end)")
print("lerp weight=-1.0 (夾到 0)  ->", start.lerp(end, -1.0), "(預期 start)")
print("lerp weight=2.0  (夾到 1)  ->", start.lerp(end, 2.0), "(預期 end)")
