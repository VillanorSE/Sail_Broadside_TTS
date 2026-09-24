-- Wind: game-start roll, Wind Phase changes, and sailing attitude.
--
-- Wind state: { condition = "calm"|"fair"|"rough", from = bearing, blowing = bool }
-- `from` is where the wind blows from; ships run when heading toward from + 180.
local angle = require("rules.angle")
local dice_util = require("rules.dice")

local M = {}

local function copy(w)
  return { condition = w.condition, from = w.from, blowing = w.blowing }
end

function M.is_blocked(from, cfg)
  for _, a in ipairs(cfg.blocked_axis) do
    if angle.diff(from, a) < 1e-6 then return true end
  end
  return false
end

function M.roll_direction(dice, cfg)
  local roll = dice.d(#cfg.direction_table)
  return cfg.direction_table[roll], roll
end

-- Game start: condition (D20) and direction (D6).
function M.setup(dice, cfg)
  local condition_roll = dice.d(20)
  local condition = dice_util.lookup(cfg.condition_table, condition_roll)
  local from, direction_roll = M.roll_direction(dice, cfg)
  local wind = { condition = condition, from = from, blowing = true }
  return wind, { condition_roll = condition_roll, direction_roll = direction_roll }
end

local function shift(from, dir, cfg)
  local step = cfg.shift_step * dir
  local to = angle.norm(from + step)
  if cfg.shift_skips_blocked_axis then
    local guard = 0
    while M.is_blocked(to, cfg) and guard < 8 do
      to = angle.norm(to + step)
      guard = guard + 1
    end
  end
  return to
end

-- One Wind Phase roll. opts.force_squall is used by The Cargo Must be Recovered.
-- Returns the new wind state (the input is not modified) and a record of the rolls.
function M.phase(dice, cfg, wind, opts)
  opts = opts or {}
  local new = copy(wind)
  local rec = { from_before = wind.from }

  if opts.force_squall then
    rec.change = "squall"
    rec.forced = true
  else
    rec.roll = dice.d(20)
    rec.change = dice_util.lookup(cfg.change_tables[wind.condition], rec.roll)
  end

  if rec.change == "none" then
    new.blowing = false
  elseif rec.change == "steady" then
    new.blowing = true
  elseif rec.change == "mild_shift" then
    new.blowing = true
    rec.shift_roll = dice.d(20)
    rec.shift_dir = rec.shift_roll <= cfg.shift_ccw_max and "ccw" or "cw"
    new.from = shift(wind.from, rec.shift_dir == "cw" and 1 or -1, cfg)
  elseif rec.change == "squall" then
    new.blowing = true
    new.from, rec.direction_roll = M.roll_direction(dice, cfg)
  else
    error("unknown wind change: " .. tostring(rec.change))
  end

  rec.from_after = new.from
  return new, rec
end

-- Degrees between the ship's heading and the wind's direction of travel
-- (0 = wind dead astern, 180 = wind dead ahead).
function M.off_stern(wind_from, heading)
  return angle.diff(heading, wind_from + 180)
end

function M.attitude(wind_from, heading, cfg)
  local s = M.off_stern(wind_from, heading)
  local t = cfg.attitude
  if s < t.running_below then return "running" end
  if s <= t.reaching_max then return "reaching" end
  if s <= t.beating_max then return "beating" end
  return "against"
end

function M.multiplier(attitude_name, cfg)
  return cfg.multipliers[attitude_name]
end

-- Movement multiplier for a ship's heading at the start of the turn.
-- With no wind (becalmed) every ship moves at base sail.
function M.move_multiplier(wind, heading, cfg)
  if not wind.blowing then return cfg.no_wind_multiplier end
  return M.multiplier(M.attitude(wind.from, heading, cfg), cfg)
end

function M.describe(wind, cfg)
  local name = cfg.condition_names[wind.condition] or wind.condition
  if not wind.blowing then return name .. ", no wind (from " .. angle.compass_name(wind.from) .. ")" end
  return name .. ", from " .. angle.compass_name(wind.from)
end

return M
