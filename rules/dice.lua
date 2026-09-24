-- Injectable dice. Every rules function takes a roller instead of calling
-- math.random, so tests can use fixed or seeded rolls.
--
-- A roller has:
--   roller.d(sides)        -> one result in 1..sides
--   roller.many(n, sides)  -> list of n results
local M = {}

local function wrap(fn)
  local r = {}
  function r.d(sides)
    local v = fn(sides)
    if type(v) ~= "number" or v < 1 or v > sides or v ~= math.floor(v) then
      error("die roll " .. tostring(v) .. " is not a valid D" .. sides, 2)
    end
    return v
  end
  function r.many(n, sides)
    local t = {}
    for i = 1, n do t[i] = r.d(sides) end
    return t
  end
  return r
end

-- Wraps a function like math.random: randfn(n) returns an integer in 1..n.
function M.from_random(randfn)
  return wrap(function(sides) return randfn(sides) end)
end

-- Returns the given results in order; errors if a test asks for more.
function M.fixed(seq)
  local i = 0
  return wrap(function()
    i = i + 1
    local v = seq[i]
    if v == nil then error("fixed dice exhausted after " .. (i - 1) .. " rolls", 3) end
    return v
  end)
end

-- Deterministic Park-Miller generator, identical in every Lua interpreter.
function M.seeded(seed)
  local m = 2147483647
  local x = math.floor(math.abs(seed or 1)) % (m - 1) + 1
  return wrap(function(sides)
    x = (x * 16807) % m
    return math.floor((x - 1) * sides / (m - 1)) + 1
  end)
end

-- Looks up a roll in a list of {min, max, result} rows.
function M.lookup(tbl, roll)
  for _, row in ipairs(tbl) do
    if roll >= row.min and roll <= row.max then return row.result end
  end
  error("no table entry for roll " .. tostring(roll), 2)
end

return M
