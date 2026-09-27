-- Movement: allowance and planning a legal move.
local geo = require("rules.geometry")

local M = {}

-- Allowance in the ruled order (DESIGN.md, Rules Decisions):
--   1. base sail minus 1" per Taking on Water
--   2. minus ball & chain losses
--   3. halved for damaged rigging
--   4. times the wind attitude multiplier (forward only)
--   5. halved once for crew under 50% or entangled
-- opts: { multiplier, crew_reduced, entangled }, cfg: config.movement
function M.allowance(ship, opts, cfg)
  local e = ship.effects
  local base = ship.sail - e.taking_on_water - e.ball_chain
  if e.rigging then base = base / 2 end
  if base < 0 then base = 0 end
  local half = (opts.crew_reduced or opts.entangled) and 0.5 or 1

  local forward = base * opts.multiplier * half
  local backward = base * cfg.backward_fraction * half
  return {
    base = base,
    forward = forward,
    backward = backward,
    -- Must move at least 2", or everything if the allowance is under 2".
    min_forward = math.min(cfg.min_move, forward),
    min_backward = math.min(cfg.min_move, backward),
    halved = half < 1,
  }
end

-- Repair roll for a ship involved in a scrape, before it moves.
-- Success: not entangled. Failure: entangled, half speed this activation.
function M.entangle_check(dice, ship)
  local roll = dice.d(20)
  local target = ship.crew_stats.repair
  return { roll = roll, target = target, success = roll <= target }
end

local function finish(path, ctx)
  local plan = { path = path }
  if ctx.others and #ctx.others > 0 then
    local free, id = geo.first_contact(path, ctx.w, ctx.l, ctx.others, ctx.step)
    if id then
      plan.path = geo.truncate(path, free)
      plan.contact = id
    end
  end
  plan.length = plan.path.length
  plan.end_pose = geo.end_pose(plan.path)
  return plan
end

-- Forward move toward a target point: arc then straight. Out of reach, the
-- ship goes to the reachable spot nearest the target; too close, the path
-- is extended to the minimum move. heading_offset (degrees) nudges the
-- final heading, rerouting with the shortest curved path.
-- ctx: { radius, allowance, min, heading_offset, w, l, others, step }
-- Returns a plan { path, length, end_pose, contact? } or nil and a reason.
function M.plan_forward(start, target, ctx)
  local path = geo.arc_straight(start, target, ctx.radius)
  if not path or path.length > ctx.allowance then
    path = geo.closest_reachable(start, target, ctx.radius, ctx.allowance, ctx.min)
    if not path then return nil, "no legal move" end
  elseif path.length < ctx.min then
    path = geo.extend_straight(path, ctx.min - path.length)
  end

  local offset = ctx.heading_offset or 0
  if offset ~= 0 then
    local e = geo.end_pose(path)
    local nudged = geo.dubins(start, { x = e.x, z = e.z, h = e.h + offset }, ctx.radius)
    if not nudged or nudged.length > ctx.allowance + 1e-9 then return nil, "not enough movement to turn that far" end
    if nudged.length < ctx.min - 1e-9 then return nil, "move is shorter than the minimum" end
    path = nudged
  end
  return finish(path, ctx)
end

-- Straight backward move, no turning, toward the target's distance behind.
function M.plan_backward(start, target, ctx)
  local r = math.rad(start.h)
  local back = -((target.x - start.x) * math.sin(r) + (target.z - start.z) * math.cos(r))
  local d = math.max(ctx.min, math.min(ctx.allowance, back))
  local path = geo.make_path(start, { { kind = "T", len = d, dir = (start.h + 180) % 360 } }, ctx.radius)
  return finish(path, ctx)
end

-- Drift with the wind instead of moving (no turning). No wind, no drift.
-- ctx.drift_dir: compass bearing the wind blows toward, or nil if becalmed.
function M.plan_drift(start, ctx)
  local len = ctx.drift_dir and ctx.drift or 0
  local path = geo.make_path(start, { { kind = "T", len = len, dir = ctx.drift_dir or 0 } }, ctx.radius)
  return finish(path, ctx)
end

return M
