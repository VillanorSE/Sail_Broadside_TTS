local T = require("tests.lib")
local config = require("config")
local factions = require("data.factions")
local dice = require("rules.dice")
local ship = require("rules.ship")
local geo = require("rules.geometry")
local mv = require("rules.movement")

local cfg = config.movement

local function make(faction, rate)
  return ship.new({ id = "s", side = "red", faction = faction, rate = rate, name = "S" }, factions)
end

local function pose(x, z, h) return { x = x, z = z, h = h } end

return {
  { "allowance: plain ship, each attitude", function()
    local s = make("atrytian", "3rd") -- 6"
    T.eq(mv.allowance(s, { multiplier = 1 }, cfg).forward, 6)
    T.eq(mv.allowance(s, { multiplier = 1.5 }, cfg).forward, 9)
    T.eq(mv.allowance(s, { multiplier = 0.25 }, cfg).forward, 1.5)
  end },
  { "allowance: ruled order (water, ball & chain, rigging, wind, crew)", function()
    local s = make("korgenal", "3rd") -- 8"
    s.effects.taking_on_water = 1
    s.effects.ball_chain = 1
    s.effects.rigging = true
    local a = mv.allowance(s, { multiplier = 1.5 }, cfg)
    T.eq(a.base, 3)          -- (8 - 1 - 1) / 2
    T.eq(a.forward, 4.5)     -- x 1.5
    T.eq(mv.allowance(s, { multiplier = 1.5, crew_reduced = true }, cfg).forward, 2.25)
  end },
  { "allowance: crew and entangled halve only once", function()
    local s = make("atrytian", "3rd")
    T.eq(mv.allowance(s, { multiplier = 1, crew_reduced = true, entangled = true }, cfg).forward, 3)
  end },
  { "allowance: backward is a quarter of base, never wind-modified", function()
    local s = make("atrytian", "3rd")
    T.eq(mv.allowance(s, { multiplier = 1.5 }, cfg).backward, 1.5)
    T.eq(mv.allowance(s, { multiplier = 0.25 }, cfg).backward, 1.5)
  end },
  { "allowance: minimum move is 2 or everything if less", function()
    local s = make("atrytian", "3rd")
    T.eq(mv.allowance(s, { multiplier = 1 }, cfg).min_forward, 2)
    T.eq(mv.allowance(s, { multiplier = 0.25 }, cfg).min_forward, 1.5)
  end },
  { "allowance never goes negative", function()
    local s = make("atrytian", "frigate")
    s.effects.ball_chain = 20
    T.eq(mv.allowance(s, { multiplier = 1 }, cfg).forward, 0)
  end },
  { "entangle check against crew repair", function()
    local s = make("atrytian", "3rd") -- repair 12
    T.truthy(mv.entangle_check(dice.fixed({ 12 }), s).success)
    T.falsy(mv.entangle_check(dice.fixed({ 13 }), s).success)
  end },
  { "forward: clamps a far target to the allowance", function()
    local plan = mv.plan_forward(pose(0, 0, 0), { x = 0, z = 20 }, { radius = 2, allowance = 6, min = 2 })
    T.near(plan.length, 6)
    T.near(plan.end_pose.z, 6)
  end },
  { "forward: extends a near target to the minimum move", function()
    local plan = mv.plan_forward(pose(0, 0, 0), { x = 0, z = 0.5 }, { radius = 2, allowance = 6, min = 2 })
    T.near(plan.length, 2)
  end },
  { "forward: out-of-reach target goes to the nearest reachable spot", function()
    -- Beside the ship, too tight to reach: ends as close as it can, within limits.
    local plan = mv.plan_forward(pose(0, 0, 0), { x = 3, z = 0 }, { radius = 2, allowance = 4, min = 2 })
    T.truthy(plan.length <= 4 + 1e-9)
    T.truthy(plan.end_pose.x > 1.5, "should turn toward the target")
  end },
  { "forward: heading nudge keeps the end point and turns the ship", function()
    local ctx = { radius = 2, allowance = 10, min = 2, heading_offset = 20 }
    local plan = mv.plan_forward(pose(0, 0, 0), { x = 0, z = 6 }, ctx)
    T.near(plan.end_pose.x, 0, 1e-6)
    T.near(plan.end_pose.z, 6, 1e-6)
    T.near(plan.end_pose.h, 20, 1e-6)
    T.truthy(plan.length > 6)
  end },
  { "forward: nudge beyond the allowance is refused", function()
    local ctx = { radius = 2, allowance = 6, min = 2, heading_offset = 90 }
    local plan, why = mv.plan_forward(pose(0, 0, 0), { x = 0, z = 6 }, ctx)
    T.eq(plan, nil)
    T.truthy(why:find("turn that far"))
  end },
  { "forward: stops at contact with another ship", function()
    local other = { id = "enemy", x = 0, z = 6, h = 90, w = 1, l = 3 }
    local ctx = { radius = 2, allowance = 10, min = 2, w = 1, l = 3, others = { other }, step = 0.01 }
    local plan = mv.plan_forward(pose(0, 0, 0), { x = 0, z = 10 }, ctx)
    T.eq(plan.contact, "enemy")
    T.near(plan.length, 4, 0.02)
  end },
  { "backward: straight back, clamped", function()
    local ctx = { radius = 2, allowance = 1.5, min = 1.5 }
    local plan = mv.plan_backward(pose(0, 0, 90), { x = -5, z = 3 }, ctx)
    T.near(plan.end_pose.x, -1.5)
    T.near(plan.end_pose.z, 0)
    T.eq(plan.end_pose.h, 90)
  end },
  { "drift: 2 inches with the wind, keeps heading", function()
    local plan = mv.plan_drift(pose(0, 0, 45), { radius = 2, drift = 2, drift_dir = 180 })
    T.near(plan.end_pose.z, -2)
    T.near(plan.end_pose.h, 45)
    T.eq(mv.plan_drift(pose(0, 0, 45), { radius = 2, drift = 2 }).length, 0)
  end },
  { "turn radius for real ships", function()
    local s = make("atrytian", "1st")
    T.near(geo.turn_radius(s.turn_arc), 10 / math.pi)
  end },
}
