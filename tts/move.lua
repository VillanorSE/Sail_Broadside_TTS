-- Move controller. A ship in move mode is unlocked; while the player drags
-- it, the legal path and landing spot are previewed, and on release the
-- ship snaps to the legal spot nearest where it was dropped. Heading nudges,
-- mode switches, confirm and cancel come from the screen panel.
--
-- State.move = { ship, mode, start, allow, target, offset, plan }
local geo = require("rules.geometry")
local mv = require("rules.movement")
local ships_view = require("tts.ships")

local M = {}

local YELLOW = { 1, 0.85, 0.3 }
local ORANGE = { 0.9, 0.5, 0.2 }
local GREEN = { 0.45, 1, 0.55 }
local WHITE = { 1, 1, 1 }
local GREY = { 0.6, 0.6, 0.6 }

-- env: { config, ship_pose(obj), others(except_guid), wind_to() }
function M.context(env, move, ship, fine)
  local a = move.allow
  local backward = move.mode == "backward"
  return {
    radius = geo.turn_radius(ship.turn_arc),
    allowance = backward and a.backward or a.forward,
    min = backward and a.min_backward or a.min_forward,
    heading_offset = move.offset,
    w = ship.base.width,
    l = ship.base.length,
    others = env.others(move.ship),
    step = fine and env.config.movement.contact_step or 0.2,
    drift = env.config.movement.idle_drift,
    drift_dir = env.wind_to(),
  }
end

-- Recompute the plan for the current mode and target.
function M.replan(env, move, ship, fine)
  local ctx = M.context(env, move, ship, fine)
  local plan, why
  if move.mode == "drift" then
    plan = mv.plan_drift(move.start, ctx)
  elseif move.mode == "backward" then
    plan = mv.plan_backward(move.start, move.target or move.start, ctx)
  else
    local target = move.target
    if not target then
      -- Default: straight ahead by the minimum move.
      local r = math.rad(move.start.h)
      target = { x = move.start.x + math.sin(r) * ctx.min, z = move.start.z + math.cos(r) * ctx.min }
    end
    plan, why = mv.plan_forward(move.start, target, ctx)
  end
  if plan then move.plan = plan end
  return plan, why
end

local function rect(pose, w, l, y, color)
  local c = geo.corners({ x = pose.x, z = pose.z, h = pose.h, w = w, l = l })
  local pts = {}
  for i = 1, 5 do
    local p = c[(i - 1) % 4 + 1]
    pts[i] = { p[1], y, p[2] }
  end
  return { points = pts, color = color, thickness = 0.04 }
end

-- Lines for the move preview, drawn with the table lines.
function M.overlay(env, move, ship)
  local y = env.config.table.surface_y + 0.06
  local lines = {}
  local ctx = M.context(env, move, ship, false)
  local w, l = ship.base.width, ship.base.length

  lines[#lines + 1] = rect(move.start, w, l, y, GREY)
  if move.mode == "forward" then
    for _, spec in ipairs({ { ctx.allowance, YELLOW }, { ctx.min, ORANGE } }) do
      if spec[1] > 0 then
        local pts = {}
        for i, p in ipairs(geo.reach_outline(move.start, ctx.radius, spec[1], 36)) do pts[i] = { p.x, y, p.z } end
        lines[#lines + 1] = { points = pts, color = spec[2], thickness = 0.05 }
      end
    end
  end
  if move.plan and move.plan.length > 0 then
    local pts = {}
    for i, p in ipairs(geo.sample(move.plan.path, 0.25)) do pts[i] = { p.x, y, p.z } end
    lines[#lines + 1] = { points = pts, color = GREEN, thickness = 0.08 }
    lines[#lines + 1] = rect(move.plan.end_pose, w, l, y, WHITE)
  end
  return lines
end

function M.place(obj, pose, surface_y)
  obj.setPosition({ pose.x, surface_y + ships_view.THICKNESS / 2 + 0.02, pose.z })
  obj.setRotation({ 0, pose.h, 0 })
end

return M
