local T = require("tests.lib")
local config = require("config")
local factions = require("data.factions")
local ship = require("rules.ship")

local cfg = config.ship

local function make(faction, rate, crew_type)
  return ship.new({ id = "s1", side = "red", faction = faction, rate = rate, crew_type = crew_type, name = "Test" }, factions)
end

return {
  { "new ship takes faction stats", function()
    local s = make("atrytian", "1st", "veterans")
    T.eq(s.class, "large")
    T.eq(s.crew, 9)
    T.eq(s.crew_base, 9)
    T.eq(s.armor.left, 6)
    T.eq(s.armor.right, 6)
    T.eq(s.hull, 5)
    T.eq(s.durability, 2)
    T.eq(s.crew_stats.gunnery, 14)
    T.eq(s.points, 69)
    T.eq(ship.cannon_total(s), 10)
  end },
  { "base sizes in inches", function()
    local s = make("pirate", "frigate")
    T.near(s.base.width, 30 / 25.4)
    T.near(s.base.length, 70 / 25.4)
    T.near(make("korgenal", "3rd").base.length, 80 / 25.4)
  end },
  { "unknown faction, rate or crew type errors", function()
    T.errors(function() make("spain", "1st") end, "unknown faction")
    T.errors(function() make("atrytian", "6th") end, "unknown rate")
    T.errors(function() make("atrytian", "1st", "gunners") end, "no crew type")
  end },
  { "crew status thresholds against base crew", function()
    local s = make("atrytian", "1st") -- base 9
    s.crew = 5; T.eq(ship.crew_status(s, cfg), "full")      -- 55%
    s.crew = 4; T.eq(ship.crew_status(s, cfg), "reduced")   -- 44%
    s.crew = 3; T.eq(ship.crew_status(s, cfg), "reduced")   -- 33%
    s.crew = 2; T.eq(ship.crew_status(s, cfg), "abandoned") -- 22%
    s.crew = 13; T.eq(ship.crew_status(s, cfg), "full")     -- extra berths
  end },
  { "crew status boundaries: exactly 50% is full, exactly 25% is abandoned", function()
    local s = make("atrytian", "2nd") -- base 8
    s.crew = 4; T.eq(ship.crew_status(s, cfg), "full")
    s.crew = 2; T.eq(ship.crew_status(s, cfg), "abandoned")
  end },
  { "condition: defeated at 0 hull, wreck at -2", function()
    local s = make("atrytian", "3rd") -- hull 4
    T.eq(ship.condition(s, cfg), "active")
    s.hull_damage = 4; T.eq(ship.condition(s, cfg), "defeated")
    s.hull_damage = 5; T.eq(ship.condition(s, cfg), "defeated")
    s.hull_damage = 6; T.eq(ship.condition(s, cfg), "wreck")
    T.falsy(ship.can_activate(s, cfg))
  end },
  { "condition: abandoned crew", function()
    local s = make("atrytian", "3rd")
    s.crew = 1
    T.eq(ship.condition(s, cfg), "abandoned")
  end },
  { "effect labels", function()
    local s = make("atrytian", "3rd")
    T.eq(#ship.effect_labels(s), 0)
    s.effects.fire = 1
    s.effects.rigging = true
    local l = ship.effect_labels(s)
    T.eq(l[1], "Fire")
    T.eq(l[2], "Rigging")
  end },
}
