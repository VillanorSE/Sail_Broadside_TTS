-- Vector-line drawing: table border and wind indicator.
-- Global.setVectorLines replaces every line, so everything is drawn in one call.
local angle = require("rules.angle")

local M = {}

local WHITE = { 1, 1, 1 }
local WIND = { 0.55, 0.85, 1 }
local CALM = { 0.5, 0.5, 0.5 }

local function border(tbl)
  local hw, hd, y = tbl.width / 2, tbl.depth / 2, tbl.surface_y + 0.05
  return {
    points = { { -hw, y, -hd }, { -hw, y, hd }, { hw, y, hd }, { hw, y, -hd }, { -hw, y, -hd } },
    color = WHITE,
    thickness = 0.1,
  }
end

-- Arrow pointing the way the wind blows, inside a ring with a north tick.
local function wind_arrow(wind, tbl, spec)
  local y = tbl.surface_y + 0.05
  local cx, cz, len = spec.x, spec.z, spec.length
  local lines = {}

  local ring = {}
  for i = 0, 32 do
    local v = angle.vector(i * 360 / 32)
    ring[#ring + 1] = { cx + v.x * len * 0.6, y, cz + v.z * len * 0.6 }
  end
  lines[#lines + 1] = { points = ring, color = WHITE, thickness = 0.05 }
  -- "N" above the ring, readable from the south (Deployment Zone A) side.
  local h = len * 0.22
  local w = h * 0.7
  local base = cz + len * 0.6 + len * 0.1
  lines[#lines + 1] = {
    points = {
      { cx - w / 2, y, base }, { cx - w / 2, y, base + h },
      { cx + w / 2, y, base }, { cx + w / 2, y, base + h },
    },
    color = WHITE, thickness = 0.12,
  }

  if wind then
    local to = angle.vector(wind.from + 180)
    local tail = { cx - to.x * len / 2, y, cz - to.z * len / 2 }
    local tip = { cx + to.x * len / 2, y, cz + to.z * len / 2 }
    local l = angle.vector(wind.from + 180 + 150)
    local r = angle.vector(wind.from + 180 - 150)
    local head = len * 0.2
    local color = wind.blowing and WIND or CALM
    lines[#lines + 1] = { points = { tail, tip }, color = color, thickness = 0.2 }
    lines[#lines + 1] = {
      points = {
        { tip[1] + l.x * head, y, tip[3] + l.z * head },
        tip,
        { tip[1] + r.x * head, y, tip[3] + r.z * head },
      },
      color = color, thickness = 0.2,
    }
  end
  return lines
end

-- extra: more lines to draw this frame (move preview).
function M.render(config, wind, extra)
  local lines = { border(config.table) }
  for _, l in ipairs(wind_arrow(wind, config.table, config.tts.wind_indicator)) do
    lines[#lines + 1] = l
  end
  for _, l in ipairs(extra or {}) do lines[#lines + 1] = l end
  Global.setVectorLines(lines)
end

return M
