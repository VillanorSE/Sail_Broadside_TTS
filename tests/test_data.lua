local T = require("tests.lib")
local factions = require("data.factions")

return {
  { "every faction has every rate and a free basic crew", function()
    for _, id in ipairs(factions.ORDER) do
      local f = factions[id]
      for _, rate in ipairs(factions.RATES) do
        local s = f.ships[rate]
        T.truthy(s, id .. " " .. rate)
        for _, w in ipairs(factions.WEIGHTS) do T.truthy(s.cannons[w], id .. " " .. rate .. " " .. w) end
      end
      T.eq(f.crews.basic.cost, 0, id)
      for _, c in ipairs(f.crews.order) do T.truthy(f.crews[c], id .. " crew " .. c) end
    end
  end },
  { "correction: 5th Rate crew is 4 for every faction", function()
    for _, id in ipairs(factions.ORDER) do T.eq(factions[id].ships["5th"].crew, 4, id) end
  end },
  { "correction: Denrudain 3rd Rate cargo is 5", function()
    T.eq(factions.denrudain.ships["3rd"].cargo, 5)
  end },
  { "Korgenal Sleek Hulls", function()
    T.eq(factions.korgenal.ships["1st"].sail, 6)
    for _, r in ipairs({ "2nd", "3rd", "4th", "5th" }) do T.eq(factions.korgenal.ships[r].sail, 8, r) end
    T.eq(factions.korgenal.ships.frigate.sail, 10)
  end },
  { "Pirate Hang in There: +1 hull over Atrytian", function()
    for _, r in ipairs(factions.RATES) do
      T.eq(factions.pirate.ships[r].hull, factions.atrytian.ships[r].hull + 1, r)
    end
  end },
  { "Denrudain Cheap Firepower cannon counts", function()
    local c = factions.denrudain.ships
    T.eq(c["3rd"].cannons.heavy, 4)
    T.eq(c["4th"].cannons.super_heavy, 3)
    T.eq(c["5th"].cannons.heavy, 2)
    T.eq(c["5th"].cannons.light, 0)
    T.eq(c.frigate.cannons.medium, 3)
  end },
}
