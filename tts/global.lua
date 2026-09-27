-- Global script: TTS glue only. Rules live in /rules; this file converts
-- between TTS (players, UI, objects, saves) and the plain tables those modules use.
local config = require("config")
local factions = require("data.factions")
local dice_mod = require("rules.dice")
local wind = require("rules.wind")
local initiative = require("rules.initiative")
local turn = require("rules.turn")
local ship_rules = require("rules.ship")
local mv = require("rules.movement")
local ui = require("tts.ui")
local draw = require("tts.draw")
local play_area = require("tts.table")
local ships_view = require("tts.ships")
local move_ctl = require("tts.move")

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
    turn_headings = {}, -- GUID -> heading at the start of the turn (fixes attitude)
    move = nil,  -- the move in progress, see tts/move.lua
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

local function button_state(s)
  if State.move and State.move.ship == s.id then return ships_view.BUTTONS.moving end
  if State.turn.activated[s.id] then return ships_view.BUTTONS.activated end
  if s.moved then return ships_view.BUTTONS.done end
  return ships_view.BUTTONS.move
end

local function decorate_ships()
  for guid, s in pairs(State.ships) do
    local obj = getObjectFromGUID(guid)
    if obj then
      ships_view.decorate(obj, s, {
        button = button_state(s),
        label_scale = config.tts.label_scale,
        done_scale = config.tts.done_scale,
        attitude = config.wind.attitude,
      })
    end
  end
end

-- Movement helpers ----------------------------------------------------------

local function pose_of(obj)
  local p = obj.getPosition()
  return { x = p.x, z = p.z, h = obj.getRotation().y }
end

-- The attitude and multiplier fixed by a ship's heading at the start of the turn.
local function turn_attitude(s)
  local h = State.turn_headings[s.id]
  if h == nil then
    local obj = getObjectFromGUID(s.id)
    h = obj and obj.getRotation().y or 0
  end
  if not State.wind then return "none", 1 end
  if not State.wind.blowing then return "becalmed", config.wind.no_wind_multiplier end
  local a = wind.attitude(State.wind.from, h, config.wind)
  return a, wind.multiplier(a, config.wind)
end

local move_env = {
  config = config,
  others = function(except)
    local list = {}
    for guid, s in pairs(State.ships) do
      local obj = guid ~= except and getObjectFromGUID(guid)
      if obj then
        local p = pose_of(obj)
        list[#list + 1] = { id = guid, x = p.x, z = p.z, h = p.h, w = s.base.width, l = s.base.length }
      end
    end
    return list
  end,
  wind_to = function()
    if State.wind and State.wind.blowing then return (State.wind.from + 180) % 360 end
  end,
}

local function move_info()
  local m = State.move
  if not m then return nil end
  local s = State.ships[m.ship]
  local attitude, mult = turn_attitude(s)
  local a = m.allow
  local lines = {
    string.format("%s: %s", s.name, m.mode == "forward" and "Forward" or m.mode == "backward" and "Backward" or "Drift"),
    string.format("Attitude at turn start: %s (x%s)%s", attitude, mult, a.halved and ", halved" or ""),
    string.format("Forward %.2f\" (min %.2f\")   Backward %.2f\"", a.forward, a.min_forward, a.backward),
  }
  if m.plan then
    local l = string.format("Path: %.2f\"", m.plan.length)
    if m.plan.contact then l = l .. "  (stops: scrapes " .. State.ships[m.plan.contact].name .. ")" end
    if m.offset ~= 0 then l = l .. string.format("  heading %+d", m.offset) end
    lines[#lines + 1] = l
  else
    lines[#lines + 1] = "Drag the ship to where it should go."
  end
  return table.concat(lines, "\n")
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
    move_info = move_info(),
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
  local overlay
  if State.move then overlay = move_ctl.overlay(move_env, State.move, State.ships[State.move.ship]) end
  draw.render(config, State.wind, overlay)
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
  State.turn_headings = State.turn_headings or {}
  play_area.ensure(config, State.objects)
  if State.move and not getObjectFromGUID(State.move.ship) then State.move = nil end
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
  if State.move and State.move.ship == guid then State.move = nil end
  log(s.name .. " removed from the game.")
  refresh()
end

-- Game flow ---------------------------------------------------------------

function uiStartGame(player)
  if not player.host then return broadcastToColor("Only the host can start the game.", player.color, ERROR_COLOR) end
  if State.started then return end
  State.started = true
  -- From here on ships only move through Move.
  for guid in pairs(State.ships) do
    local obj = getObjectFromGUID(guid)
    if obj then obj.setLock(true) end
  end
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

  -- Start of turn: headings fix each ship's attitude for the whole turn.
  State.turn_headings = {}
  local running = {}
  for guid, s in pairs(State.ships) do
    local obj = getObjectFromGUID(guid)
    if obj then State.turn_headings[guid] = obj.getRotation().y end
    s.moved, s.entangled = false, false
    if turn_attitude(s) == "running" and ship_rules.can_activate(s, config.ship) then
      running[s.side] = (running[s.side] or 0) + 1
    end
  end

  local sides = {}
  for i, s in ipairs(config.sides) do
    sides[i] = { id = s.id, bonus = 0, running = running[s.id] or 0 } -- captain bonuses arrive in Stage 7
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
  if not s.moved then
    return broadcastToColor(s.name .. " must move (or drift) first.", player_color, ERROR_COLOR)
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

-- Moving ------------------------------------------------------------------

-- Redraw just the move preview (cheap enough to run while dragging).
local function refresh_move()
  local overlay
  if State.move then overlay = move_ctl.overlay(move_env, State.move, State.ships[State.move.ship]) end
  draw.render(config, State.wind, overlay)
  UI.setValue("sbMoveInfo", move_info() or "")
end

local function moving_ship(player)
  local m = State.move
  if not m then return nil end
  local s = State.ships[m.ship]
  if player and not can_act_for(player, s.side) then
    broadcastToColor(s.name .. " belongs to " .. side_name(s.side) .. ".", player.color, ERROR_COLOR)
    return nil
  end
  return m, s, getObjectFromGUID(m.ship)
end

-- Replan and put the ship where the plan ends.
local function replan_and_place(m, s, obj)
  local plan, why = move_ctl.replan(move_env, m, s, true)
  if plan and obj then move_ctl.place(obj, plan.end_pose, config.table.surface_y) end
  return plan, why
end

function sbShipMove(obj, player_color)
  local s = State.ships[obj.getGUID()]
  if not s then return end
  local t = State.turn
  local player = Player[player_color]
  local function refuse(msg) broadcastToColor(msg, player_color, ERROR_COLOR) end
  if t.phase ~= turn.ACTIVATION then return refuse("Ships move during the activation phase.") end
  if t.current ~= s.side then return refuse("It is " .. side_name(t.current) .. "'s activation.") end
  if not can_act_for(player, s.side) then return refuse(s.name .. " belongs to " .. side_name(s.side) .. ".") end
  if t.activated[s.id] or s.moved then return end
  if State.move then return refuse(State.ships[State.move.ship].name .. " is still moving.") end
  local eligible = false
  for _, id in ipairs(turn.remaining(t, s.side)) do eligible = eligible or id == s.id end
  if not eligible then return refuse(s.name .. " cannot activate.") end

  if s.scrape_pending then
    local rec = mv.entangle_check(dice, s)
    s.scrape_pending = false
    s.entangled = not rec.success
    log(string.format("%s scrape check: D20 = %d vs Repair %d -> %s", s.name, rec.roll, rec.target,
      rec.success and "clear" or "ENTANGLED (half speed)"))
  end

  local _, mult = turn_attitude(s)
  local allow = mv.allowance(s, {
    multiplier = mult,
    crew_reduced = ship_rules.crew_status(s, config.ship) == "reduced",
    entangled = s.entangled,
  }, config.movement)
  State.move = { ship = s.id, mode = "forward", start = pose_of(obj), allow = allow, offset = 0 }
  move_ctl.replan(move_env, State.move, s, true)
  obj.setLock(false)
  refresh()
end

-- While the moving ship is held, preview the path it would take.
local update_tick = 0
function onUpdate()
  if not State or not State.move then return end
  update_tick = update_tick + 1
  if update_tick % 4 ~= 0 then return end
  local m, s, obj = moving_ship()
  if not obj or not obj.held_by_color or m.mode == "drift" then return end
  local p = obj.getPosition()
  m.target = { x = p.x, z = p.z }
  move_ctl.replan(move_env, m, s, false)
  refresh_move()
end

function onObjectPickUp(_, obj)
  if State and State.move and obj.getGUID() == State.move.ship then State.move.offset = 0 end
end

function onObjectDrop(_, obj)
  if not (State and State.move and obj.getGUID() == State.move.ship) then return end
  local m, s = moving_ship()
  if m.mode ~= "drift" then
    local p = obj.getPosition()
    m.target = { x = p.x, z = p.z }
  end
  replan_and_place(m, s, obj)
  refresh()
end

local function set_mode(player, mode)
  local m, s, obj = moving_ship(player)
  if not m then return end
  m.mode, m.offset = mode, 0
  replan_and_place(m, s, obj)
  refresh()
end

function uiMoveForward(player) set_mode(player, "forward") end
function uiMoveBackward(player) set_mode(player, "backward") end
function uiMoveDrift(player) set_mode(player, "drift") end

local function nudge(player, dir)
  local m, s, obj = moving_ship(player)
  if not m then return end
  if m.mode ~= "forward" then
    return broadcastToColor("Only forward moves can turn.", player.color, ERROR_COLOR)
  end
  local before = m.offset
  m.offset = before + dir * config.movement.nudge_step
  local plan, why = replan_and_place(m, s, obj)
  if not plan then
    m.offset = before
    replan_and_place(m, s, obj)
    broadcastToColor("Can't turn further: " .. why .. ".", player.color, ERROR_COLOR)
  end
  refresh()
end

-- Screen left/right as seen from behind the ship: left turns counterclockwise.
function uiNudgeLeft(player) nudge(player, -1) end
function uiNudgeRight(player) nudge(player, 1) end

function uiMoveConfirm(player)
  local m, s, obj = moving_ship(player)
  if not m then return end
  local plan = m.plan
  if not plan then return broadcastToColor("No legal move yet.", player.color, ERROR_COLOR) end
  move_ctl.place(obj, plan.end_pose, config.table.surface_y)
  obj.setLock(true)
  s.moved = true
  State.move = nil

  local what = m.mode == "drift" and "drifted" or m.mode == "backward" and "moved backward" or "moved"
  log(string.format("%s %s %.2f\".", s.name, what, plan.length))
  if plan.contact then
    local other = State.ships[plan.contact]
    s.scrape_pending = true
    if other then other.scrape_pending = true end
    log(string.format("%s scraped %s! Both roll for entanglement at their next activation.", s.name,
      other and other.name or "another ship"), ERROR_COLOR)
  end
  refresh()
end

function uiMoveCancel(player)
  local m, _, obj = moving_ship(player)
  if not m then return end
  move_ctl.place(obj, m.start, config.table.surface_y)
  obj.setLock(true)
  State.move = nil
  refresh()
end

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
