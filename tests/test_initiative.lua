local T = require("tests.lib")
local config = require("config")
local dice = require("rules.dice")
local initiative = require("rules.initiative")

local cfg = config.initiative

return {
  { "highest roll goes first", function()
    local r = initiative.roll(dice.fixed({ 7, 12 }), { { id = "red" }, { id = "blue" } }, cfg)
    T.eq(r.first, "blue")
    T.list_eq(r.order, { "blue", "red" })
    T.eq(r.reason, "roll")
  end },
  { "captain bonus is added", function()
    local r = initiative.roll(dice.fixed({ 10, 12 }), { { id = "red", bonus = 3 }, { id = "blue" } }, cfg)
    T.eq(r.first, "red")
    T.eq(r.attempts[1][1].total, 13)
  end },
  { "tie goes to more running ships", function()
    local sides = { { id = "red", running = 1 }, { id = "blue", running = 2 } }
    local r = initiative.roll(dice.fixed({ 9, 9 }), sides, cfg)
    T.eq(r.first, "blue")
    T.eq(r.reason, "running")
  end },
  { "tie on total and running re-rolls", function()
    local sides = { { id = "red", running = 1 }, { id = "blue", running = 1 } }
    local r = initiative.roll(dice.fixed({ 9, 9, 15, 4 }), sides, cfg)
    T.eq(r.first, "red")
    T.eq(#r.attempts, 2)
  end },
  { "bonus can create a tie", function()
    local sides = { { id = "red", bonus = 2 }, { id = "blue" } }
    local r = initiative.roll(dice.fixed({ 8, 10, 1, 20 }), sides, cfg)
    T.eq(r.first, "blue")
    T.eq(#r.attempts, 2)
  end },
}
