-- Sanity checks on config.lua so a typo in a rules table fails loudly.
local T = require("tests.lib")
local config = require("config")
local wind = require("rules.wind")

local function covers_d20_once(tbl, label)
  for roll = 1, 20 do
    local hits = 0
    for _, row in ipairs(tbl) do
      if roll >= row.min and roll <= row.max then hits = hits + 1 end
    end
    T.eq(hits, 1, label .. " roll " .. roll)
  end
end

return {
  { "condition table covers 1-20 exactly once", function()
    covers_d20_once(config.wind.condition_table, "condition")
  end },
  { "every condition has a change table covering 1-20", function()
    for _, row in ipairs(config.wind.condition_table) do
      local tbl = config.wind.change_tables[row.result]
      T.truthy(tbl, "missing change table for " .. row.result)
      covers_d20_once(tbl, row.result)
    end
  end },
  { "direction table is a D6 that never uses the blocked axis", function()
    T.eq(#config.wind.direction_table, 6)
    for _, from in ipairs(config.wind.direction_table) do
      T.falsy(wind.is_blocked(from, config.wind), "direction " .. from)
    end
  end },
  { "D6 points follow the rules numbering", function()
    local angle = require("rules.angle")
    local t = config.wind.direction_table
    T.eq(angle.compass_name(t[1]), "SW", "point 1 is the near-left corner")
    for i = 1, 3 do
      T.eq(angle.diff(t[i], t[i + 3]), 180, "points " .. i .. " and " .. (i + 3) .. " are opposite")
    end
  end },
  { "every attitude has a multiplier", function()
    for _, a in ipairs({ "running", "reaching", "beating", "against" }) do
      T.truthy(config.wind.multipliers[a], a)
    end
  end },
}
