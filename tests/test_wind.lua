local T = require("tests.lib")
local config = require("config")
local dice = require("rules.dice")
local wind = require("rules.wind")

local cfg = config.wind

-- Change-table roll that produces `change` for `condition`.
local function roll_for(condition, change)
  for _, row in ipairs(cfg.change_tables[condition]) do
    if row.result == change then return row.min end
  end
  error("no " .. change .. " in " .. condition)
end

return {
  { "setup: condition boundaries", function()
    T.eq((wind.setup(dice.fixed({ 5, 1 }), cfg)).condition, "calm")
    T.eq((wind.setup(dice.fixed({ 6, 1 }), cfg)).condition, "fair")
    T.eq((wind.setup(dice.fixed({ 15, 1 }), cfg)).condition, "fair")
    T.eq((wind.setup(dice.fixed({ 16, 1 }), cfg)).condition, "rough")
  end },
  { "setup: direction from D6 and records rolls", function()
    local w, rec = wind.setup(dice.fixed({ 10, 4 }), cfg)
    T.eq(w.from, cfg.direction_table[4])
    T.eq(w.blowing, true)
    T.eq(rec.condition_roll, 10)
    T.eq(rec.direction_roll, 4)
  end },
  { "setup never picks the deployment axis", function()
    local d = dice.seeded(7)
    for _ = 1, 500 do
      local w = wind.setup(d, cfg)
      T.falsy(wind.is_blocked(w.from, cfg))
    end
  end },
  { "phase: steady keeps direction", function()
    local w0 = { condition = "fair", from = 90, blowing = true }
    local w, rec = wind.phase(dice.fixed({ roll_for("fair", "steady") }), cfg, w0)
    T.eq(rec.change, "steady")
    T.eq(w.from, 90)
    T.eq(w.blowing, true)
  end },
  { "phase: no wind stops blowing but keeps direction", function()
    local w0 = { condition = "calm", from = 90, blowing = true }
    local w = wind.phase(dice.fixed({ roll_for("calm", "none") }), cfg, w0)
    T.eq(w.blowing, false)
    T.eq(w.from, 90)
  end },
  { "phase: mild shift 1-10 is counterclockwise, 11-20 clockwise", function()
    local w0 = { condition = "fair", from = 90, blowing = true }
    local shift = roll_for("fair", "mild_shift")
    local w, rec = wind.phase(dice.fixed({ shift, 10 }), cfg, w0)
    T.eq(rec.shift_dir, "ccw")
    T.eq(w.from, 45)
    w, rec = wind.phase(dice.fixed({ shift, 11 }), cfg, w0)
    T.eq(rec.shift_dir, "cw")
    T.eq(w.from, 135)
  end },
  { "phase: mild shift skips the deployment axis", function()
    local shift = roll_for("fair", "mild_shift")
    local w = wind.phase(dice.fixed({ shift, 1 }), cfg, { condition = "fair", from = 45, blowing = true })
    T.eq(w.from, 315)
    w = wind.phase(dice.fixed({ shift, 20 }), cfg, { condition = "fair", from = 135, blowing = true })
    T.eq(w.from, 225)
  end },
  { "phase: squall re-rolls direction", function()
    local w0 = { condition = "rough", from = 90, blowing = false }
    local w, rec = wind.phase(dice.fixed({ roll_for("rough", "squall"), 6 }), cfg, w0)
    T.eq(rec.change, "squall")
    T.eq(w.from, cfg.direction_table[6])
    T.eq(w.blowing, true)
  end },
  { "phase: forced squall skips the change roll", function()
    local w0 = { condition = "calm", from = 90, blowing = true }
    local w, rec = wind.phase(dice.fixed({ 1 }), cfg, w0, { force_squall = true })
    T.eq(rec.forced, true)
    T.eq(rec.roll, nil)
    T.eq(w.from, cfg.direction_table[1])
  end },
  { "phase does not modify its input", function()
    local w0 = { condition = "fair", from = 90, blowing = true }
    wind.phase(dice.fixed({ roll_for("fair", "mild_shift"), 20 }), cfg, w0)
    T.eq(w0.from, 90)
  end },
  { "attitude: wind from north", function()
    -- Wind from 0 blows toward 180, so heading 180 is dead astern.
    T.eq(wind.attitude(0, 180, cfg), "running")
    T.eq(wind.attitude(0, 151, cfg), "running")    -- 29 off stern
    T.eq(wind.attitude(0, 150, cfg), "reaching")   -- 30 off stern
    T.eq(wind.attitude(0, 90, cfg), "reaching")    -- 90, abeam
    T.eq(wind.attitude(0, 89, cfg), "beating")     -- 91 off stern
    T.eq(wind.attitude(0, 30, cfg), "beating")     -- 30 off bow
    T.eq(wind.attitude(0, 29, cfg), "against")     -- 29 off bow
    T.eq(wind.attitude(0, 0, cfg), "against")
    T.eq(wind.attitude(0, 330, cfg), "beating")    -- other tack
  end },
  { "attitude: wraps across 0/360", function()
    T.eq(wind.attitude(225, 45, cfg), "running")
    T.eq(wind.attitude(225, 20, cfg), "running")
    T.eq(wind.attitude(315, 300, cfg), "against")
  end },
  { "multipliers", function()
    T.eq(wind.multiplier("reaching", cfg), 1.5)
    T.eq(wind.multiplier("against", cfg), 0.25)
  end },
  { "move multiplier: wind blowing uses attitude, no wind is 1x", function()
    T.eq(wind.move_multiplier({ condition = "fair", from = 0, blowing = true }, 90, cfg), 1.5)
    T.eq(wind.move_multiplier({ condition = "fair", from = 0, blowing = true }, 0, cfg), 0.25)
    T.eq(wind.move_multiplier({ condition = "calm", from = 0, blowing = false }, 0, cfg), 1)
  end },
  { "describe", function()
    T.eq(wind.describe({ condition = "rough", from = 45, blowing = true }, cfg), "Rough Seas, from NE")
  end },
}
