-- Global script: TTS glue only. Rules live in /rules; this file converts
-- between TTS (players, UI, objects, saves) and the plain tables those modules use.
local config = require("config")
local factions = require("data.factions")
local dice_mod = require("rules.dice")
local wind = require("rules.wind")
local initiative = require("rules.initiative")
local turn = require("rules.turn")
local ship_rules = require("rules.ship")
local ui = require("tts.ui")
local draw = require("tts.draw")
local play_area = require("tts.table")
local ships_view = require("tts.ships")

State = nil
local dice

local SIDE_BY_ID = {}
for _, s in ipairs(config.sides) do SIDE_BY_ID[s.id] = s end

local ERROR_COLOR = { 1, 0.5, 0.5 }

local function side_ids()
  local ids = {}
  for i, s in ipairs(config.sides) do ids[i] = s.id end
  return ids
end

local function new_state()
  return {
    version = 2,
    turn = turn.new(side_ids(), config.game.max_turns),
    wind = nil,
    log = {},
    objects = {},
    ships = {},  -- object GUID -> ship table (rules/ship.lua)
    seq = 0,     -- ships added so far, for naming and ordering
    pick = { side = config.sides[1].id, faction = factions.ORDER[1], rate = "3rd", crew = "basic" },
  }
end

local function side_name(id)
  return SIDE_BY_ID[id] and SIDE_BY_ID[id].name or tostring(id)
end

local function log(msg, color)
  broadcastToAll(msg, color or { 1, 1, 1 })
  table.insert(State.log, 1, msg)
  while #State.log > config.tts.log_lines do table.remove(State.log) end
end

-- The side's seat, the host, or anyone if that seat is empty.
local function can_act_for(player, side_id)
  if player.host then return true end
  local seat = SIDE_BY_ID[side_id] and SIDE_BY_ID[side_id].seat
  if player.color == seat then return true end
  for _, c in ipairs(getSeatedPlayers()) do
    if c == seat then return false end
  end
  return true
end

local function ships_in_order()
  local list = {}
  for _, s in pairs(State.ships) do list[#list + 1] = s end
  table.sort(list, function(a, b) return a.seq < b.seq end)
  return list
end

-- Give the turn tracker every ship able to activate this turn.
local function assign_ships()
  for _, side in ipairs(side_ids()) do
    local ids = {}
    for _, s in ipairs(ships_in_order()) do
      if s.side == side and ship_rules.can_activate(s, config.ship) then ids[#ids + 1] = s.id end
    end
    turn.set_ships(State.turn, side, ids)
  end
end

-- Dropdowns ---------------------------------------------------------------

local function options(ids, name_of)
  local out = {}
  for i, id in ipairs(ids) do out[i] = { id, name_of(id) } end
  return out
end

local function pick_dropdowns()
  local p = State.pick
  local f = factions[p.faction]
  return {
    { id = "sbPickSide", label = "Side", handler = "uiPickSide", selected = p.side,
      options = options(side_ids(), side_name) },
    { id = "sbPickFaction", label = "Faction", handler = "uiPickFaction", selected = p.faction,
      options = options(factions.ORDER, function(id) return factions[id].name end) },
    { id = "sbPickRate", label = "Rate", handler = "uiPickRate", selected = p.rate,
      options = options(factions.RATES, function(r)
        return factions.RATE_NAMES[r] .. " (" .. f.ships[r].points .. " pts)"
      end) },
    { id = "sbPickCrew", label = "Crew", handler = "uiPickCrew", selected = p.crew,
      options = options(f.crews.order, function(c)
        local cr = f.crews[c]
        return string.format("%s (%d pts) G%d B%d R%d O%d", cr.name, cr.cost, cr.gunnery, cr.boarding, cr.repair, cr.objective)
      end) },
  }
end

-- Maps a dropdown's displayed text back to its id.
local function picked(dd_id, label)
  for _, dd in ipairs(pick_dropdowns()) do
    if dd.id == dd_id then
      for _, o in ipairs(dd.options) do
        if o[2] == label then return o[1] end
      end
    end
  end
end

-- Display -----------------------------------------------------------------

local function fleet_text()
  local lines = {}
  for _, side in ipairs(side_ids()) do
    local points = 0
    local block = {}
    for _, s in ipairs(ships_in_order()) do
      if s.side == side then
        points = points + s.points
        local cond = ship_rules.condition(s, config.ship)
        local flags = {}
        if State.turn.activated[s.id] then flags[#flags + 1] = "activated" end
        if cond ~= "active" then flags[#flags + 1] = cond:upper() end
        if ship_rules.crew_status(s, config.ship) == "reduced" then flags[#flags + 1] = "crew < 50%" end
        local effects = ship_rules.effect_labels(s)
        block[#block + 1] = string.format("%s  (%s, %s)%s", s.name, factions.RATE_NAMES[s.rate],
          factions[s.faction].name, #flags > 0 and ("  [" .. table.concat(flags, ", ") .. "]") or "")
        block[#block + 1] = string.format("   Crew %d/%d  Hull %d/%d  Armor L%d R%d  Sail %d\"",
          s.crew, s.crew_base, ship_rules.hull_left(s), s.hull, s.armor.left, s.armor.right, s.sail)
        if #effects > 0 then block[#block + 1] = "   " .. table.concat(effects, ", ") end
      end
    end
    lines[#lines + 1] = string.format("%s: %d pts", side_name(side), points)
    if #block == 0 then block[1] = "   (no ships)" end
    for _, l in ipairs(block) do lines[#lines + 1] = l end
    lines[#lines + 1] = ""
  end
  return table.concat(lines, "\n")
end

local function decorate_ships()
  for guid, s in pairs(State.ships) do
    local obj = getObjectFromGUID(guid)
    if obj then
      ships_view.decorate(obj, s, {
      activated = State.turn.activated[s.id],
      label_scale = config.tts.label_scale,
      done_scale = config.tts.done_scale,
      attitude = config.wind.attitude,
    })
    end
  end
end

local function refresh()
  local t = State.turn
  local phase_names = {
    setup = "Setup", initiative = "Initiative", activation = "Activation", wind = "Wind Phase", over = "Game Over",
  }
  local turn_text = t.phase == turn.SETUP and "Setup"
    or string.format("Turn %d / %d: %s", t.turn, t.max_turns, phase_names[t.phase])

  local init_text = "Initiative: -"
  if t.order then
    local names = {}
    for i, id in ipairs(t.order) do names[i] = side_name(id) end
    init_text = "Initiative: " .. table.concat(names, " then ")
  end

  local active = ""
  if t.phase == turn.ACTIVATION then
    active = string.format("%s to activate (%d left)", side_name(t.current), #turn.remaining(t, t.current))
  elseif t.phase == turn.OVER then
    active = "Game over"
  end

  if not State.started then
    turn_text = "Setup: add ships, then Start Game"
  end

  ui.update({
    started = State.started,
    turn = turn_text,
    wind = "Wind: " .. (State.wind and wind.describe(State.wind, config.wind) or "not rolled"),
    initiative = init_text,
    active = active,
    log = table.concat(State.log, "\n"),
    fleet = fleet_text(),
    buttons = {
      sbBtnSetup = t.phase == turn.SETUP,
      sbBtnInit = t.phase == turn.INITIATIVE,
      sbBtnWind = t.phase == turn.WIND,
    },
  })
  draw.render(config, State.wind)
  decorate_ships()
end

local function rebuild_ui()
  ui.build(pick_dropdowns())
  refresh()
end

-- Lifecycle ---------------------------------------------------------------

function onLoad(saved)
  math.randomseed(os.time())
  dice = dice_mod.from_random(math.random)
  if saved and saved ~= "" then
    local ok, decoded = pcall(JSON.decode, saved)
    if ok and type(decoded) == "table" and decoded.version == 2 then State = decoded end
  end
  State = State or new_state()
  play_area.ensure(config, State.objects)
  -- Drop ships whose objects were deleted while the script wasn't running.
  for guid in pairs(State.ships) do
    if not getObjectFromGUID(guid) then
      State.ships[guid] = nil
      turn.remove_ship(State.turn, guid)
    end
  end
  rebuild_ui()
end

function onSave()
  return JSON.encode(State)
end

function onObjectDestroy(obj)
  if not State then return end
  local guid = obj.getGUID()
  local s = State.ships[guid]
  if not s then return end
  State.ships[guid] = nil
  turn.remove_ship(State.turn, guid)
  log(s.name .. " removed from the game.")
  refresh()
end

-- Game flow ---------------------------------------------------------------

function uiStartGame(player)
  if not player.host then return broadcastToColor("Only the host can start the game.", player.color, ERROR_COLOR) end
  if State.started then return end
  State.started = true
  log("Game started. Host: roll the wind.", { 0.95, 0.85, 0.6 })
  refresh()
end

function uiSetupWind(player)
  if not player.host then return broadcastToColor("Only the host can roll the wind.", player.color, ERROR_COLOR) end
  if not State.started or State.turn.phase ~= turn.SETUP then return end
  local w, rec = wind.setup(dice, config.wind)
  State.wind = w
  log(string.format("Wind: D20 = %d -> %s. D6 = %d -> %s",
    rec.condition_roll, config.wind.condition_names[w.condition], rec.direction_roll, wind.describe(w, config.wind)),
    { 0.55, 0.85, 1 })
  turn.start(State.turn)
  assign_ships()
  refresh()
end

function uiRollInitiative()
  if State.turn.phase ~= turn.INITIATIVE then return end
  assign_ships()
  local sides = {}
  for i, s in ipairs(config.sides) do
    sides[i] = { id = s.id, bonus = 0, running = 0 } -- captains and attitudes arrive in later stages
  end
  local result = initiative.roll(dice, sides, config.initiative)
  for n, attempt in ipairs(result.attempts) do
    local parts = {}
    for i, r in ipairs(attempt) do
      parts[i] = string.format("%s %d%s", side_name(r.id), r.roll, r.bonus ~= 0 and string.format("%+d", r.bonus) or "")
    end
    log((n > 1 and "Re-roll: " or "Initiative: ") .. table.concat(parts, ", "))
  end
  log(side_name(result.first) .. " goes first" .. (result.reason == "running" and " (more ships running)" or ""),
    { 0.95, 0.85, 0.6 })
  local ok, err = turn.set_initiative(State.turn, result.order)
  if not ok then log(err, ERROR_COLOR) end
  refresh()
end

-- Click handler for the "Done" button on a ship base.
function sbShipDone(obj, player_color)
  local s = State.ships[obj.getGUID()]
  if not s then return end
  local player = Player[player_color]
  local t = State.turn
  if t.activated[s.id] then return end
  if t.phase ~= turn.ACTIVATION then
    return broadcastToColor("Ships activate during the activation phase.", player_color, ERROR_COLOR)
  end
  if not can_act_for(player, s.side) then
    return broadcastToColor(s.name .. " belongs to " .. side_name(s.side) .. ".", player_color, ERROR_COLOR)
  end
  local ok, err = turn.activate(t, s.side, s.id)
  if ok then
    log(s.name .. " activated.")
  else
    broadcastToColor(err, player_color, ERROR_COLOR)
  end
  refresh()
end

function sbNoop() end

function uiWindPhase()
  if State.turn.phase ~= turn.WIND then return end
  -- Defeated-ship drift is added in Stage 5.
  local w, rec = wind.phase(dice, config.wind, State.wind, { force_squall = State.force_squall })
  State.wind = w
  local msg = rec.forced and "Wind Phase: forced squall" or string.format("Wind Phase: D20 = %d -> %s",
    rec.roll, config.wind.change_names[rec.change])
  if rec.shift_roll then
    msg = msg .. string.format(" (D20 = %d, %s)", rec.shift_roll, rec.shift_dir == "cw" and "clockwise" or "counterclockwise")
  end
  if rec.direction_roll then msg = msg .. string.format(" (D6 = %d)", rec.direction_roll) end
  log(msg .. ". " .. wind.describe(w, config.wind), { 0.55, 0.85, 1 })

  turn.end_wind_phase(State.turn)
  if State.turn.phase == turn.OVER then
    log("Game over after turn " .. State.turn.turn .. ".", { 0.95, 0.85, 0.6 })
  else
    assign_ships()
  end
  refresh()
end

function uiNewGame(player)
  if not player.host then return broadcastToColor("Only the host can reset the game.", player.color, ERROR_COLOR) end
  local old = State
  State = new_state()
  State.objects = old.objects
  State.pick = old.pick
  for guid in pairs(old.ships) do
    local obj = getObjectFromGUID(guid)
    if obj then obj.destruct() end
  end
  log("New game. Add ships, then the host clicks Start Game.")
  refresh()
end

-- Adding ships ------------------------------------------------------------

function uiPickSide(_, label) State.pick.side = picked("sbPickSide", label) or State.pick.side end
function uiPickRate(_, label) State.pick.rate = picked("sbPickRate", label) or State.pick.rate end
function uiPickCrew(_, label) State.pick.crew = picked("sbPickCrew", label) or State.pick.crew end

function uiPickFaction(_, label)
  local f = picked("sbPickFaction", label)
  if not f or f == State.pick.faction then return end
  State.pick.faction = f
  if not factions[f].crews[State.pick.crew] then State.pick.crew = "basic" end
  rebuild_ui() -- crew choices and costs differ by faction
end

function uiAddShip(player)
  if State.started then return end
  local p = State.pick
  if not can_act_for(player, p.side) then
    return broadcastToColor("Only " .. side_name(p.side) .. " or the host can add " .. side_name(p.side) .. " ships.",
      player.color, ERROR_COLOR)
  end
  local side = SIDE_BY_ID[p.side]
  local count = 0
  for _, s in pairs(State.ships) do
    if s.side == p.side then count = count + 1 end
  end
  State.seq = State.seq + 1
  local seq = State.seq
  local s = ship_rules.new({
    side = p.side, faction = p.faction, rate = p.rate, crew_type = p.crew,
    name = string.format("%s %s %d", side.name, factions.RATE_NAMES[p.rate], count + 1),
  }, factions)
  s.seq = seq

  -- Line new ships up along the side's deployment edge; players drag them into place.
  local slot = count % 8
  local pos = { x = -config.table.width / 2 + 5 + slot * 5.5, z = side.spawn_z }
  ships_view.spawn(s, pos, side.heading, side.tint, config.table.surface_y, function(obj)
    s.id = obj.getGUID()
    State.ships[s.id] = s
    if State.turn.phase ~= turn.ACTIVATION then assign_ships() end
    log(string.format("%s added: %s, %s (%d pts).", s.name, factions[s.faction].name,
      factions[s.faction].crews[s.crew_type].name, s.points))
    refresh()
  end)
end
