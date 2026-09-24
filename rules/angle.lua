-- Compass angle helpers. Bearings are degrees, 0 = north (+z), clockwise.
local M = {}

-- Wrap any angle into [0, 360).
function M.norm(deg)
  local d = deg % 360
  if d < 0 then d = d + 360 end
  return d
end

-- Smallest absolute difference between two bearings, in [0, 180].
function M.diff(a, b)
  local d = math.abs(M.norm(a) - M.norm(b))
  if d > 180 then d = 360 - d end
  return d
end

local POINTS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }

-- Nearest of the eight compass point names.
function M.compass_name(deg)
  return POINTS[math.floor(M.norm(deg + 22.5) / 45) + 1]
end

-- Unit vector {x, z} for a bearing.
function M.vector(deg)
  local r = math.rad(deg)
  return { x = math.sin(r), z = math.cos(r) }
end

return M
