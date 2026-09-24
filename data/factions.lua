-- Faction data from Sail & Broadside v0.8.2.4 ("Building a Squadron").
-- Ship stats are the faction tables with faction bonuses already applied.
-- Corrections to the rulebook tables (see DESIGN.md, Rules Decisions):
--   5th Rate crew is 4 for every faction (Atrytian and Denrudain tables say 3).
--   Denrudain 3rd Rate cargo is 5 (table says 4; Resilient Ships gives +1).

-- points, sail, turn, crew, armor, durability, hull, cargo, cannons {L, M, H, SH}
local function ship(points, sail, turn, crew, armor, durability, hull, cargo, cannons)
  return {
    points = points, sail = sail, turn = turn, crew = crew, armor = armor,
    durability = durability, hull = hull, cargo = cargo,
    cannons = { light = cannons[1], medium = cannons[2], heavy = cannons[3], super_heavy = cannons[4] },
  }
end

local function crew(name, cost, gunnery, boarding, repair, objective)
  return { name = name, cost = cost, gunnery = gunnery, boarding = boarding, repair = repair, objective = objective }
end

local M = {}

M.RATES = { "1st", "2nd", "3rd", "4th", "5th", "frigate" }
M.RATE_NAMES = {
  ["1st"] = "1st Rate", ["2nd"] = "2nd Rate", ["3rd"] = "3rd Rate",
  ["4th"] = "4th Rate", ["5th"] = "5th Rate", frigate = "Frigate",
}
M.CLASS = {
  ["1st"] = "large", ["2nd"] = "large", ["3rd"] = "medium",
  ["4th"] = "medium", ["5th"] = "small", frigate = "small",
}
-- Base sizes in mm (width, length).
M.BASE_MM = {
  large = { 50, 100 },
  medium = { 40, 80 },
  small = { 30, 70 },
}
M.WEIGHTS = { "light", "medium", "heavy", "super_heavy" }
M.WEIGHT_NAMES = { light = "Light", medium = "Medium", heavy = "Heavy", super_heavy = "Super Heavy" }

M.ORDER = { "atrytian", "denrudain", "korgenal", "pirate" }

M.atrytian = {
  name = "Atrytian Empire",
  bonuses = { "Bring the Big Guns", "Carronade Factories", "Wait for the Broadside" },
  primary = { "sturdy_ships", "close_range_brawling" },
  secondary = { "versatility", "firepower", "tenacity" },
  crews = {
    order = { "basic", "deckhands", "boarders", "veterans" },
    basic = crew("Basic Crew", 0, 13, 12, 12, 12),
    deckhands = crew("Deckhands", 2, 13, 12, 14, 12),
    boarders = crew("Boarders", 2, 13, 14, 12, 12),
    veterans = crew("Veterans", 4, 14, 13, 13, 12),
  },
  ships = {
    ["1st"] = ship(65, 6, 5, 9, 6, 2, 5, 5, { 0, 3, 3, 4 }),
    ["2nd"] = ship(60, 6, 5, 8, 6, 1, 5, 4, { 0, 3, 3, 3 }),
    ["3rd"] = ship(45, 6, 4, 6, 5, 0, 4, 4, { 1, 0, 3, 3 }),
    ["4th"] = ship(40, 6, 4, 5, 5, -1, 4, 3, { 1, 3, 3, 0 }),
    ["5th"] = ship(30, 6, 3, 4, 4, -2, 3, 3, { 3, 3, 0, 0 }),
    frigate = ship(25, 8, 3, 3, 3, -3, 3, 3, { 4, 1, 0, 0 }),
  },
}

M.denrudain = {
  name = "Denrudain Republic",
  bonuses = { "Resilient Ships", "Precision Fire", "Cheap Firepower" },
  primary = { "long_range_combat", "versatility" },
  secondary = { "range_control", "movement_mastery", "firepower" },
  crews = {
    order = { "basic", "deckhands", "gunners", "veterans" },
    basic = crew("Basic Crew", 0, 12, 12, 12, 14),
    deckhands = crew("Deckhands", 2, 12, 12, 14, 15),
    gunners = crew("Gunners", 2, 13, 12, 12, 14),
    veterans = crew("Veterans", 4, 13, 12, 14, 14),
  },
  ships = {
    ["1st"] = ship(65, 6, 5, 9, 6, 2, 5, 5, { 0, 3, 3, 4 }),
    ["2nd"] = ship(60, 6, 5, 8, 6, 1, 5, 4, { 0, 3, 3, 3 }),
    ["3rd"] = ship(45, 6, 4, 6, 5, 0, 4, 5, { 0, 0, 4, 3 }),
    ["4th"] = ship(40, 6, 4, 5, 5, -1, 4, 4, { 1, 3, 0, 3 }),
    ["5th"] = ship(30, 6, 3, 4, 4, -2, 3, 4, { 0, 4, 2, 0 }),
    frigate = ship(25, 8, 3, 3, 3, -3, 3, 4, { 2, 3, 0, 0 }),
  },
}

M.korgenal = {
  name = "Korgenal Principality",
  bonuses = { "Sleek Hulls", "Aim for the Rigging", "Masterful Repairs", "Expert Sailmakers" },
  primary = { "range_control", "movement_mastery" },
  secondary = { "long_range_combat", "versatility", "tenacity" },
  crews = {
    order = { "basic", "deckhands", "gunners", "veterans" },
    basic = crew("Basic Crew", 0, 12, 12, 14, 12),
    deckhands = crew("Deckhands", 2, 12, 12, 15, 14),
    gunners = crew("Gunners", 2, 13, 12, 14, 12),
    veterans = crew("Veterans", 4, 13, 12, 15, 13),
  },
  ships = {
    ["1st"] = ship(65, 6, 5, 9, 6, 2, 5, 5, { 0, 3, 3, 4 }),
    ["2nd"] = ship(60, 8, 5, 8, 6, 1, 5, 4, { 0, 3, 3, 3 }),
    ["3rd"] = ship(45, 8, 4, 6, 5, 0, 4, 4, { 1, 0, 3, 3 }),
    ["4th"] = ship(40, 8, 4, 5, 5, -1, 4, 3, { 1, 3, 3, 0 }),
    ["5th"] = ship(30, 8, 3, 4, 4, -2, 3, 3, { 3, 3, 0, 0 }),
    frigate = ship(25, 10, 3, 3, 3, -3, 3, 3, { 4, 1, 0, 0 }),
  },
}

M.pirate = {
  name = "Pirate Nations",
  bonuses = { "More Firepower", "Aim for the Crew", "Pack 'em in", "Hang in There" },
  primary = { "firepower", "tenacity" },
  secondary = { "sturdy_ships", "close_range_brawling", "movement_mastery" },
  crews = {
    order = { "basic", "boarders", "gunners", "veterans" },
    basic = crew("Basic Crew", 0, 12, 14, 12, 12),
    boarders = crew("Boarders", 2, 12, 16, 12, 12),
    gunners = crew("Gunners", 2, 13, 14, 12, 12),
    veterans = crew("Veterans", 4, 13, 15, 13, 12),
  },
  ships = {
    ["1st"] = ship(65, 6, 5, 9, 6, 2, 6, 5, { 0, 3, 4, 4 }),
    ["2nd"] = ship(60, 6, 5, 8, 6, 1, 6, 4, { 0, 3, 4, 3 }),
    ["3rd"] = ship(45, 6, 4, 6, 5, 0, 5, 4, { 3, 0, 3, 3 }),
    ["4th"] = ship(40, 6, 4, 5, 5, -1, 5, 3, { 1, 4, 3, 0 }),
    ["5th"] = ship(30, 6, 3, 4, 4, -2, 4, 3, { 4, 3, 0, 0 }),
    frigate = ship(25, 8, 3, 3, 3, -3, 4, 3, { 5, 1, 0, 0 }),
  },
}

return M
