-- Ship state: stats from faction data plus everything that changes in play.
local M = {}

local MM_PER_INCH = 25.4

-- spec: { id, side, faction, rate, crew_type, name }
function M.new(spec, factions)
  local faction = factions[spec.faction]
  if not faction then error("unknown faction " .. tostring(spec.faction), 2) end
  local stats = faction.ships[spec.rate]
  if not stats then error("unknown rate " .. tostring(spec.rate), 2) end
  local crew_type = spec.crew_type or "basic"
  local crew = faction.crews[crew_type]
  if not crew then error(faction.name .. " has no crew type " .. tostring(crew_type), 2) end

  local class = factions.CLASS[spec.rate]
  local base = factions.BASE_MM[class]
  local cannons = {}
  for _, w in ipairs(factions.WEIGHTS) do
    cannons[w] = { count = stats.cannons[w], carronade = false }
  end

  return {
    id = spec.id,
    side = spec.side,
    name = spec.name,
    faction = spec.faction,
    rate = spec.rate,
    class = class,
    base = { width = base[1] / MM_PER_INCH, length = base[2] / MM_PER_INCH },
    points = stats.points + crew.cost,
    sail = stats.sail,
    turn_arc = stats.turn,
    cargo = stats.cargo,
    durability = stats.durability,
    crew_type = crew_type,
    crew_stats = { gunnery = crew.gunnery, boarding = crew.boarding, repair = crew.repair, objective = crew.objective },
    crew_base = stats.crew,
    crew = stats.crew,
    armor_max = stats.armor,
    armor = { left = stats.armor, right = stats.armor },
    hull = stats.hull,
    hull_damage = 0,
    cannons = cannons,
    effects = {
      fire = 0,
      flooding = 0,
      taking_on_water = 0,
      gun_ports = 0,
      rigging = false,
      ball_chain = 0,
    },
  }
end

function M.hull_left(ship)
  return ship.hull - ship.hull_damage
end

-- "full" (>= 50% of base crew), "reduced" (< 50%) or "abandoned" (<= 25%).
-- Compared against base crew; extra berths don't raise the baseline.
function M.crew_status(ship, cfg)
  local pct = ship.crew * 100 / ship.crew_base
  if pct <= cfg.abandoned_pct then return "abandoned" end
  if pct < cfg.full_pct then return "reduced" end
  return "full"
end

-- "active", "defeated" (hull gone), "wreck" (hull at -2 or below) or "abandoned".
function M.condition(ship, cfg)
  local left = M.hull_left(ship)
  if left <= cfg.wreck_hull then return "wreck" end
  if left <= 0 then return "defeated" end
  if M.crew_status(ship, cfg) == "abandoned" then return "abandoned" end
  return "active"
end

function M.can_activate(ship, cfg)
  return M.condition(ship, cfg) == "active"
end

function M.cannon_total(ship)
  local n = 0
  for _, c in pairs(ship.cannons) do n = n + c.count end
  return n
end

-- Active effects as a list of short labels, for status displays.
function M.effect_labels(ship)
  local e, out = ship.effects, {}
  if e.fire > 0 then out[#out + 1] = e.fire > 1 and ("Fire x" .. e.fire) or "Fire" end
  if e.flooding > 0 then out[#out + 1] = e.flooding > 1 and ("Flooding x" .. e.flooding) or "Flooding" end
  if e.taking_on_water > 0 then out[#out + 1] = "Taking on Water -" .. e.taking_on_water .. "\"" end
  if e.gun_ports > 0 then out[#out + 1] = "Gun Ports x" .. e.gun_ports end
  if e.rigging then out[#out + 1] = "Rigging" end
  if e.ball_chain > 0 then out[#out + 1] = "Ball & Chain -" .. e.ball_chain .. "\"" end
  return out
end

return M
