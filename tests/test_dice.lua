local T = require("tests.lib")
local dice = require("rules.dice")

return {
  { "fixed returns the sequence then errors", function()
    local d = dice.fixed({ 3, 20, 1 })
    T.eq(d.d(20), 3)
    T.eq(d.d(20), 20)
    T.eq(d.d(6), 1)
    T.errors(function() d.d(20) end, "exhausted")
  end },
  { "out-of-range results are rejected", function()
    local d = dice.fixed({ 7 })
    T.errors(function() d.d(6) end, "not a valid D6")
  end },
  { "many rolls n dice", function()
    local d = dice.fixed({ 1, 2, 3 })
    T.list_eq(d.many(3, 20), { 1, 2, 3 })
  end },
  { "seeded is reproducible and in range", function()
    local a, b = dice.seeded(42), dice.seeded(42)
    local seen = {}
    for _ = 1, 2000 do
      local x = a.d(20)
      T.eq(x, b.d(20))
      T.truthy(x >= 1 and x <= 20)
      seen[x] = true
    end
    for face = 1, 20 do T.truthy(seen[face], "face " .. face .. " never rolled") end
  end },
  { "different seeds differ", function()
    local a, b = dice.seeded(1), dice.seeded(2)
    local same = 0
    for _ = 1, 50 do
      if a.d(20) == b.d(20) then same = same + 1 end
    end
    T.truthy(same < 20)
  end },
  { "from_random wraps a math.random-like function", function()
    local d = dice.from_random(function(n) return n end)
    T.eq(d.d(6), 6)
  end },
  { "lookup finds the row", function()
    local tbl = { { min = 1, max = 5, result = "a" }, { min = 6, max = 20, result = "b" } }
    T.eq(dice.lookup(tbl, 5), "a")
    T.eq(dice.lookup(tbl, 6), "b")
    T.errors(function() dice.lookup(tbl, 21) end, "no table entry")
  end },
}
