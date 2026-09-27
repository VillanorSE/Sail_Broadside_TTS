-- Movement geometry: poses, curved paths with a minimum turn radius, and
-- base (rectangle) overlap.
--
-- A pose is { x, z, h }: table position in inches and compass heading in
-- degrees (0 = +z, 90 = +x). Internally the path maths uses a standard
-- math frame (y = z, angle th = 90 - h in radians, counterclockwise = left).
--
-- A path is { start = pose, segs = { {kind, len, dir?}... }, radius, length }
-- with segment kinds:
--   "L" / "R"  arc turning left / right at `radius`, len = arc length
--   "S"        straight ahead, len = distance
--   "T"        translate without turning toward compass bearing `dir`
--              (backward moves and drift)
local angle = require("rules.angle")

local M = {}

local TAU = 2 * math.pi
-- math.atan2 in Lua 5.1/5.2 (TTS MoonSharp); two-argument math.atan in 5.3+.
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local EPS = 1e-9

local function mod2pi(a)
  local r = a % TAU
  if r < 0 then r = r + TAU end
  return r
end

local function to_math(p)
  return { x = p.x, y = p.z, th = math.rad(90 - p.h) }
end

local function from_math(m)
  return { x = m.x, z = m.y, h = angle.norm(90 - math.deg(m.th)) }
end

-- Minimum turn radius from the rulebook turn arc: a quarter circle of that length.
function M.turn_radius(arc_length)
  return 2 * arc_length / math.pi
end

-- Advance a math-frame pose along one segment by distance s.
local function advance(m, seg, s, R)
  local x, y, th = m.x, m.y, m.th
  if seg.kind == "S" then
    return { x = x + s * math.cos(th), y = y + s * math.sin(th), th = th }
  elseif seg.kind == "L" then
    local a = s / R
    return { x = x + R * (math.sin(th + a) - math.sin(th)), y = y + R * (math.cos(th) - math.cos(th + a)), th = th + a }
  elseif seg.kind == "R" then
    local a = s / R
    return { x = x + R * (math.sin(th) - math.sin(th - a)), y = y + R * (math.cos(th - a) - math.cos(th)), th = th - a }
  elseif seg.kind == "T" then
    local d = math.rad(90 - seg.dir)
    return { x = x + s * math.cos(d), y = y + s * math.sin(d), th = th }
  end
  error("unknown segment kind " .. tostring(seg.kind))
end

local function make_path(start, segs, R)
  local total = 0
  local kept = {}
  for _, s in ipairs(segs) do
    if s.len > EPS then
      kept[#kept + 1] = s
      total = total + s.len
    end
  end
  return { start = start, segs = kept, radius = R, length = total }
end
M.make_path = make_path

-- Pose after travelling `dist` along the path (clamped to its ends).
function M.pose_at(path, dist)
  local m = to_math(path.start)
  local left = math.max(0, dist)
  for _, seg in ipairs(path.segs) do
    local s = math.min(left, seg.len)
    m = advance(m, seg, s, path.radius)
    left = left - s
    if left <= 0 then break end
  end
  return from_math(m)
end

function M.end_pose(path)
  return M.pose_at(path, path.length)
end

-- The first `len` inches of a path.
function M.truncate(path, len)
  local segs, left = {}, len
  for _, seg in ipairs(path.segs) do
    if left <= 0 then break end
    segs[#segs + 1] = { kind = seg.kind, len = math.min(seg.len, left), dir = seg.dir }
    left = left - seg.len
  end
  return make_path(path.start, segs, path.radius)
end

-- The path with `extra` inches of straight sailing added at the end.
function M.extend_straight(path, extra)
  local segs = {}
  for i, seg in ipairs(path.segs) do segs[i] = seg end
  segs[#segs + 1] = { kind = "S", len = extra }
  return make_path(path.start, segs, path.radius)
end

-- Points every `step` inches along the path, for drawing and contact checks.
function M.sample(path, step)
  local pts = {}
  local n = math.max(1, math.ceil(path.length / step))
  for i = 0, n do pts[#pts + 1] = M.pose_at(path, path.length * i / n) end
  return pts
end

-- Shortest arc-then-straight path from a pose to a point, with the final
-- heading free. nil when the point is inside both turning circles.
function M.arc_straight(start, target, R)
  local m = to_math(start)
  local best
  for _, dir in ipairs({ 1, -1 }) do -- 1 = left, -1 = right
    local cx = m.x - dir * R * math.sin(m.th)
    local cy = m.y + dir * R * math.cos(m.th)
    local vx, vy = target.x - cx, target.z - cy
    local D = math.sqrt(vx * vx + vy * vy)
    if D >= R - EPS then
      local gamma = atan2(vy, vx)
      local psi = gamma + dir * math.asin(math.min(1, R / D))
      local phi = mod2pi(dir * (psi - m.th))
      if phi > TAU - 1e-7 then phi = 0 end
      local s = math.sqrt(math.max(0, D * D - R * R))
      local path = make_path(start, { { kind = dir == 1 and "L" or "R", len = R * phi }, { kind = "S", len = s } }, R)
      if not best or path.length < best.length then best = path end
    end
  end
  return best
end

-- Arc-then-straight path whose end point is as close to `target` as
-- possible with total length between minlen and maxlen. Used when the
-- target is out of reach: the ship stops at the edge nearest the pointer.
function M.closest_reachable(start, target, R, maxlen, minlen, samples)
  samples = samples or 90
  local m = to_math(start)
  local max_phi = math.min(maxlen / R, TAU)
  local best, best_d2
  for _, dir in ipairs({ 1, -1 }) do
    for i = 0, samples do
      local phi = max_phi * i / samples
      local e = advance(m, { kind = dir == 1 and "L" or "R" }, R * phi, R)
      local fx, fy = math.cos(e.th), math.sin(e.th)
      -- Best straight distance: project the target onto the heading, within limits.
      local s = (target.x - e.x) * fx + (target.z - e.y) * fy
      s = math.max(math.max(0, minlen - R * phi), math.min(maxlen - R * phi, s))
      if s >= 0 then
        local ex, ey = e.x + s * fx, e.y + s * fy
        local d2 = (ex - target.x) ^ 2 + (ey - target.z) ^ 2
        if not best_d2 or d2 < best_d2 - 1e-12 then
          best_d2 = d2
          best = make_path(start, { { kind = dir == 1 and "L" or "R", len = R * phi }, { kind = "S", len = s } }, R)
        end
      end
    end
  end
  return best
end

-- Outline of the end points of every arc-then-straight path of exactly
-- `len`: hard left round through straight ahead to hard right. Points {x, z}.
function M.reach_outline(start, R, len, samples)
  samples = samples or 36
  local m = to_math(start)
  local max_phi = math.min(len / R, TAU)
  local pts = {}
  local function add(dir, phi)
    local e = advance(m, { kind = dir == 1 and "L" or "R" }, R * phi, R)
    local s = len - R * phi
    pts[#pts + 1] = { x = e.x + s * math.cos(e.th), z = e.y + s * math.sin(e.th) }
  end
  for i = samples, 0, -1 do add(1, max_phi * i / samples) end
  for i = 1, samples do add(-1, max_phi * i / samples) end
  return pts
end

-- Shortest path between two poses with minimum turn radius R (Dubins).
local WORDS = {
  LSL = function(a, b, d, sa, sb, ca, cb, cab)
    local p2 = 2 + d * d - 2 * cab + 2 * d * (sa - sb)
    if p2 < 0 then return nil end
    local tmp = atan2(cb - ca, d + sa - sb)
    return mod2pi(-a + tmp), math.sqrt(p2), mod2pi(b - tmp)
  end,
  RSR = function(a, b, d, sa, sb, ca, cb, cab)
    local p2 = 2 + d * d - 2 * cab + 2 * d * (sb - sa)
    if p2 < 0 then return nil end
    local tmp = atan2(ca - cb, d - sa + sb)
    return mod2pi(a - tmp), math.sqrt(p2), mod2pi(-b + tmp)
  end,
  LSR = function(a, b, d, sa, sb, ca, cb, cab)
    local p2 = -2 + d * d + 2 * cab + 2 * d * (sa + sb)
    if p2 < 0 then return nil end
    local p = math.sqrt(p2)
    local tmp = atan2(-ca - cb, d + sa + sb) - atan2(-2, p)
    return mod2pi(-a + tmp), p, mod2pi(-mod2pi(b) + tmp)
  end,
  RSL = function(a, b, d, sa, sb, ca, cb, cab)
    local p2 = -2 + d * d + 2 * cab - 2 * d * (sa + sb)
    if p2 < 0 then return nil end
    local p = math.sqrt(p2)
    local tmp = atan2(ca + cb, d - sa - sb) - atan2(2, p)
    return mod2pi(a - tmp), p, mod2pi(b - tmp)
  end,
  RLR = function(a, b, d, sa, sb, ca, cb, cab)
    local tmp = (6 - d * d + 2 * cab + 2 * d * (sa - sb)) / 8
    if math.abs(tmp) > 1 then return nil end
    local p = mod2pi(TAU - math.acos(tmp))
    local t = mod2pi(a - atan2(ca - cb, d - sa + sb) + p / 2)
    return t, p, mod2pi(a - b - t + p)
  end,
  LRL = function(a, b, d, sa, sb, ca, cb, cab)
    local tmp = (6 - d * d + 2 * cab + 2 * d * (sb - sa)) / 8
    if math.abs(tmp) > 1 then return nil end
    local p = mod2pi(TAU - math.acos(tmp))
    local t = mod2pi(-a - atan2(ca - cb, d + sa - sb) + p / 2)
    return t, p, mod2pi(mod2pi(b) - a - t + p)
  end,
}

function M.dubins(start, goal, R)
  local s, g = to_math(start), to_math(goal)
  local dx, dy = g.x - s.x, g.y - s.y
  local d = math.sqrt(dx * dx + dy * dy) / R
  local line = atan2(dy, dx)
  local a, b = mod2pi(s.th - line), mod2pi(g.th - line)
  local sa, sb, ca, cb = math.sin(a), math.sin(b), math.cos(a), math.cos(b)
  local cab = math.cos(a - b)

  local best
  for _, word in ipairs({ "LSL", "RSR", "LSR", "RSL", "RLR", "LRL" }) do
    local t, p, q = WORDS[word](a, b, d, sa, sb, ca, cb, cab)
    if t then
      local total = (t + p + q) * R
      if not best or total < best.length - EPS then
        local k = {}
        for i = 1, 3 do k[i] = word:sub(i, i) end
        best = make_path(start, {
          { kind = k[1], len = t * R }, { kind = k[2], len = p * R }, { kind = k[3], len = q * R },
        }, R)
        best.length = total
      end
    end
  end
  return best
end

-- Base rectangle for a ship at a pose: { x, z, h, w, l }.
local function corners(b)
  local r = math.rad(b.h)
  local fx, fz = math.sin(r), math.cos(r)  -- forward
  local rx, rz = math.cos(r), -math.sin(r) -- right
  local hw, hl = b.w / 2, b.l / 2
  return {
    { b.x + fx * hl + rx * hw, b.z + fz * hl + rz * hw },
    { b.x + fx * hl - rx * hw, b.z + fz * hl - rz * hw },
    { b.x - fx * hl - rx * hw, b.z - fz * hl - rz * hw },
    { b.x - fx * hl + rx * hw, b.z - fz * hl + rz * hw },
  }, { { fx, fz }, { rx, rz } }
end
M.corners = function(b) return (corners(b)) end

-- True if two base rectangles overlap by more than `tolerance` inches.
function M.overlap(a, b, tolerance)
  tolerance = tolerance or 1e-6
  local ca, axa = corners(a)
  local cb, axb = corners(b)
  for _, axis in ipairs({ axa[1], axa[2], axb[1], axb[2] }) do
    local amin, amax, bmin, bmax = math.huge, -math.huge, math.huge, -math.huge
    for _, c in ipairs(ca) do
      local v = c[1] * axis[1] + c[2] * axis[2]
      amin, amax = math.min(amin, v), math.max(amax, v)
    end
    for _, c in ipairs(cb) do
      local v = c[1] * axis[1] + c[2] * axis[2]
      bmin, bmax = math.min(bmin, v), math.max(bmax, v)
    end
    if amax - bmin <= tolerance or bmax - amin <= tolerance then return false end
  end
  return true
end

-- How far along the path a base of size w x l can travel before touching
-- one of `others` (list of rectangles with an `id`). Returns the free
-- distance and the id hit, or nil if the whole path is clear.
-- Ships already overlapping at the start are ignored so a ship can move away.
function M.first_contact(path, w, l, others, step)
  step = step or 0.05
  local s = path.start
  local here = { x = s.x, z = s.z, h = s.h, w = w, l = l }
  local clear = {}
  for _, o in ipairs(others) do
    if not M.overlap(here, o) then clear[#clear + 1] = o end
  end
  others = clear
  local n = math.max(1, math.ceil(path.length / step))
  local prev = 0
  for i = 1, n do
    local dist = path.length * i / n
    local p = M.pose_at(path, dist)
    local me = { x = p.x, z = p.z, h = p.h, w = w, l = l }
    for _, o in ipairs(others) do
      if M.overlap(me, o) then return prev, o.id end
    end
    prev = dist
  end
  return nil
end

return M
