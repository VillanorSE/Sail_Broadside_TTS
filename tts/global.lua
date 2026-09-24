-- Global script: TTS glue only. Rules live in /rules; this file converts
-- between TTS (players, UI, saves) and the plain tables those modules use.
local config = require("config")
local dice_mod = require("rules.dice")
local wind = require("rules.wind")
local initiative = require("rules.initiative")
local turn = require("rules.turn")
local ui = require("tts.ui")
local draw = require("tts.draw")
local play_area = require("tts.table")

State = nil
local dice

local SIDE_BY_ID = {}
for _, s in ipairs(config.sides) do SIDE_BY_ID[s.id] = s end

local function side_ids()
  local ids = {}
  for i, s in ipairs(config.sides) do ids[i] = s.id end
  return ids
end

local function new_state()
  return { version = 1, turn = turn.new(side_ids(), config.game.max_turns), wind = nil, initiative = nil, log = {} }
end

-- Stage 1 stand-ins until real ships exist (Stage 2).
local function assign_test_ships()
  for _, s in ipairs(config.sides) do
    local ids = {}
    for i = 1, config.tts.stage1_test_ships do ids[i] = s.id .. i end
    turn.set_ships(State.turn, s.id, ids)
  end
end

local function log(msg, color)
  broadcastToAll(msg, color or { 1, 1, 1 })
  table.insert(State.log, 1, msg)
  while #State.log > config.tts.log_lines do table.remove(State.log) end
end

local function side_name(id)
  return SIDE_BY_ID[id] and SIDE_BY_ID[id].name or tostring(id)
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

  ui.update({
    turn = turn_text,
    wind = "Wind: " .. (State.wind and wind.describe(State.wind, config.wind) or "not rolled"),
    initiative = init_text,
    active = active,
    log = table.concat(State.log, "\n"),
    buttons = {
      sbBtnSetup = t.phase == turn.SETUP,
      sbBtnInit = t.phase == turn.INITIATIVE,
      sbBtnActivate = t.phase == turn.ACTIVATION,
      sbBtnWind = t.phase == turn.WIND,
    },
  })
  draw.render(config, State.wind)
end

function onLoad(saved)
  math.randomseed(os.time())
  dice = dice_mod.from_random(math.random)
  if saved and saved ~= "" then
    local ok, decoded = pcall(JSON.decode, saved)
    if ok and type(decoded) == "table" and decoded.version == 1 then State = decoded end
  end
  State = State or new_state()
  State.objects = State.objects or {}
  play_area.ensure(config, State.objects)
  ui.build()
  refresh()
end

function onSave()
  return JSON.encode(State)
end

-- UI handlers -----------------------------------------------------------

function uiSetupWind(player)
  if not player.host then return broadcastToColor("Only the host can start the game.", player.color, { 1, 0.5, 0.5 }) end
  local w, rec = wind.setup(dice, config.wind)
  State.wind = w
  log(string.format("Wind: D20 = %d -> %s. D6 = %d -> %s",
    rec.condition_roll, config.wind.condition_names[w.condition], rec.direction_roll, wind.describe(w, config.wind)),
    { 0.55, 0.85, 1 })
  turn.start(State.turn)
  assign_test_ships()
  refresh()
end

function uiRollInitiative()
  local sides = {}
  for i, s in ipairs(config.sides) do
    sides[i] = { id = s.id, bonus = 0, running = 0 } -- captains and ship attitudes arrive in later stages
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
  if not ok then log(err, { 1, 0.5, 0.5 }) end
  refresh()
end

function uiEndActivation(player)
  local t = State.turn
  if t.phase ~= turn.ACTIVATION then return end
  if not can_act_for(player, t.current) then
    return broadcastToColor("It is " .. side_name(t.current) .. "'s activation.", player.color, { 1, 0.5, 0.5 })
  end
  local side = t.current
  local ship = turn.remaining(t, side)[1]
  local ok, err = turn.activate(t, side, ship)
  if ok then
    log(side_name(side) .. " activated " .. ship)
  else
    log(err, { 1, 0.5, 0.5 })
  end
  refresh()
end

function uiWindPhase()
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
    assign_test_ships()
  end
  refresh()
end

function uiNewGame(player)
  if not player.host then return broadcastToColor("Only the host can reset the game.", player.color, { 1, 0.5, 0.5 }) end
  local objects = State.objects
  State = new_state()
  State.objects = objects
  log("New game. Host: roll the wind to begin.")
  refresh()
end
