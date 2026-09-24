-- Initiative: one D20 per side plus captain bonuses. Highest total goes first.
-- Ties go to the side with more ships running; if still tied, everyone re-rolls.
local M = {}

local function better(a, b)
  if a.total ~= b.total then return a.total > b.total end
  return a.running > b.running
end

-- sides: list of { id, bonus = n, running = n }
-- Returns { first, order = {ids...}, reason = "roll"|"running", attempts = {{results}...} }
function M.roll(dice, sides, cfg)
  local attempts = {}
  for _ = 1, cfg.max_rerolls do
    local results = {}
    for i, s in ipairs(sides) do
      local roll = dice.d(cfg.die)
      local bonus = s.bonus or 0
      results[i] = { id = s.id, roll = roll, bonus = bonus, total = roll + bonus, running = s.running or 0 }
    end
    attempts[#attempts + 1] = results

    local sorted = {}
    for i, r in ipairs(results) do sorted[i] = r end
    table.sort(sorted, better)

    local top, second = sorted[1], sorted[2]
    if not second or better(top, second) then
      local order = {}
      for i, r in ipairs(sorted) do order[i] = r.id end
      local reason = (second and top.total == second.total) and "running" or "roll"
      return { first = top.id, order = order, reason = reason, attempts = attempts }
    end
  end
  error("initiative still tied after " .. cfg.max_rerolls .. " re-rolls")
end

return M
