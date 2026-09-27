local T = require("tests.lib")
local angle = require("rules.angle")
local dice = require("rules.dice")
local geo = require("rules.geometry")

local function pose(x, z, h) return { x = x, z = z, h = h } end

local function pose_near(actual, expected, eps, msg)
  eps = eps or 1e-6
  T.near(actual.x, expected.x, eps, (msg or "") .. " x")
  T.near(actual.z, expected.z, eps, (msg or "") .. " z")
  if expected.h then T.near(angle.diff(actual.h, expected.h), 0, eps * 10, (msg or "") .. " h") end
end

return {
  { "turn radius: quarter circle of the turn arc", function()
    T.near(geo.turn_radius(3), 6 / math.pi)
    T.near(geo.turn_radius(5) * math.pi / 2, 5)
  end },
  { "straight ahead is a pure straight path", function()
    local p = geo.arc_straight(pose(0, 0, 0), { x = 0, z = 6 }, 2)
    T.near(p.length, 6)
    pose_near(geo.end_pose(p), pose(0, 6, 0))
    p = geo.arc_straight(pose(1, 1, 90), { x = 5, z = 1 }, 2)
    T.near(p.length, 4)
  end },
  { "quarter turn to the right ends facing east", function()
    local R = geo.turn_radius(4)
    local p = geo.arc_straight(pose(0, 0, 0), { x = R, z = R }, R)
    T.near(p.length, 4, 1e-6)
    pose_near(geo.end_pose(p), pose(R, R, 90))
    T.eq(p.segs[1].kind, "R")
  end },
  { "quarter turn to the left ends facing west", function()
    local R = 2
    local p = geo.arc_straight(pose(0, 0, 0), { x = -R, z = R }, R)
    pose_near(geo.end_pose(p), pose(-R, R, 270))
    T.eq(p.segs[1].kind, "L")
  end },
  { "arc then straight reaches the target point", function()
    local d = dice.seeded(3)
    for _ = 1, 200 do
      local start = pose(d.d(20) - 10, d.d(20) - 10, d.d(360))
      local target = { x = d.d(40) - 20, z = d.d(40) - 20 }
      local p = geo.arc_straight(start, target, 1.9)
      if p then pose_near(geo.end_pose(p), target, 1e-6, "target") end
    end
  end },
  { "a point just beside the ship needs a loop the other way", function()
    -- Inside the right turning circle, so the path loops left around it.
    local p = geo.arc_straight(pose(0, 0, 0), { x = 0.5, z = 0 }, 2)
    T.eq(p.segs[1].kind, "L")
    T.truthy(p.length > math.pi * 2)
  end },
  { "closest reachable: straight ahead beyond range stops at the limit", function()
    local p = geo.closest_reachable(pose(0, 0, 0), { x = 0, z = 20 }, 2, 6, 2)
    pose_near(geo.end_pose(p), pose(0, 6, 0), 1e-6)
  end },
  { "closest reachable: respects both limits", function()
    local d = dice.seeded(5)
    for _ = 1, 100 do
      local p = geo.closest_reachable(pose(0, 0, 0), { x = d.d(30) - 15, z = d.d(30) - 15 }, 2, 5, 2)
      T.truthy(p.length <= 5 + 1e-9 and p.length >= 2 - 1e-9, "length " .. p.length)
    end
  end },
  { "dubins reaches the goal pose and is never shorter than the straight line", function()
    local d = dice.seeded(11)
    for _ = 1, 300 do
      local s = pose(d.d(20) - 10, d.d(20) - 10, d.d(360))
      local g = pose(d.d(30) - 15, d.d(30) - 15, d.d(360))
      local R = ({ 1.9, 2.55, 3.18 })[d.d(3)]
      local p = geo.dubins(s, g, R)
      T.truthy(p, "no dubins path")
      pose_near(geo.end_pose(p), g, 1e-6, "goal")
      T.truthy(p.length >= math.sqrt((g.x - s.x) ^ 2 + (g.z - s.z) ^ 2) - 1e-9)
    end
  end },
  { "dubins agrees with arc-straight when the heading matches", function()
    local s = pose(0, 0, 30)
    local cs = geo.arc_straight(s, { x = 6, z = 7 }, 2)
    local db = geo.dubins(s, geo.end_pose(cs), 2)
    T.near(db.length, cs.length, 1e-6)
  end },
  { "truncate and extend", function()
    local p = geo.arc_straight(pose(0, 0, 0), { x = 0, z = 10 }, 2)
    local t = geo.truncate(p, 4)
    T.near(t.length, 4)
    pose_near(geo.end_pose(t), pose(0, 4, 0))
    local e = geo.extend_straight(t, 1)
    pose_near(geo.end_pose(e), pose(0, 5, 0))
  end },
  { "translate segments move without turning", function()
    local p = geo.make_path(pose(0, 0, 0), { { kind = "T", len = 1.5, dir = 180 } }, 2)
    pose_near(geo.end_pose(p), pose(0, -1.5, 0))
  end },
  { "reach outline: every point is exactly one allowance of travel away", function()
    local start = pose(1, 2, 60)
    local pts = geo.reach_outline(start, 2, 6, 24)
    T.eq(#pts, 49)
    for _, p in ipairs(pts) do
      local path = geo.arc_straight(start, p, 2)
      T.near(path.length, 6, 1e-6)
    end
  end },
  { "rectangle overlap", function()
    local a = { x = 0, z = 0, h = 0, w = 2, l = 4 }
    T.truthy(geo.overlap(a, { x = 1.5, z = 0, h = 0, w = 2, l = 4 }))
    T.falsy(geo.overlap(a, { x = 2.5, z = 0, h = 0, w = 2, l = 4 }))
    T.falsy(geo.overlap(a, { x = 2, z = 0, h = 0, w = 2, l = 4 }), "touching is not overlapping")
    -- Rotated 90: now 4 wide, so it reaches back to x = 1.
    T.truthy(geo.overlap(a, { x = 2.9, z = 0, h = 90, w = 2, l = 4 }))
    T.falsy(geo.overlap(a, { x = 3.1, z = 0, h = 90, w = 2, l = 4 }))
  end },
  { "first contact stops short of another base", function()
    local p = geo.arc_straight(pose(0, 0, 0), { x = 0, z = 12 }, 2)
    local other = { id = "b", x = 0, z = 8, h = 90, w = 1, l = 3 }
    local free, id = geo.first_contact(p, 1, 3, { other }, 0.01)
    T.eq(id, "b")
    -- Bow reaches the other's near edge (z = 7.5) when centre is at 6.
    T.near(free, 6, 0.02)
    T.eq(geo.first_contact(p, 1, 3, { { id = "c", x = 5, z = 8, h = 0, w = 1, l = 3 } }), nil)
  end },
  { "first contact ignores a ship already overlapping at the start", function()
    local p = geo.arc_straight(pose(0, 0, 0), { x = 0, z = 6 }, 2)
    T.eq(geo.first_contact(p, 1, 3, { { id = "d", x = 0.5, z = 0, h = 0, w = 1, l = 3 } }), nil)
  end },
}
