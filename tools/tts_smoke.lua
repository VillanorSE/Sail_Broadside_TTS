-- Smoke test for the bundled Global script against a fake TTS API.
-- Catches nil calls and typos in /tts before the user loads it in game.
--   lua tools/bundle.lua && lua tools/tts_smoke.lua
local script = (arg and arg[0]) or "tools/tts_smoke.lua"
local root = script:match("^(.*)[/\\]tools[/\\][^/\\]*$") or "."

local messages, ui_values, ui_attrs, lines, xml = {}, {}, {}, nil, nil

-- Stand-ins for the TTS globals the script uses.
-- Real text JSON, strict about what TTS would mangle (see tools/fake_json.lua).
JSON = dofile(root .. "/tools/fake_json.lua")
UI = {
  setXml = function(x) xml = x end,
  setValue = function(id, v) ui_values[id] = v end,
  setAttribute = function(id, k, v) ui_attrs[id .. "." .. k] = v end,
}
Wait = { frames = function(fn) fn() end }
Global = { setVectorLines = function(l) lines = l end }
function broadcastToAll(msg) messages[#messages + 1] = msg end
function broadcastToColor(msg) messages[#messages + 1] = "(private) " .. msg end
function getSeatedPlayers() return { "Red", "Blue" } end

local host = { color = "White", host = true }
local red = { color = "Red", host = false }
local blue = { color = "Blue", host = false }
Player = { White = host, Red = red, Blue = blue }

local objects, spawn_count = {}, 0
function getObjectFromGUID(guid) return objects[guid] end
function spawnObject(p)
  spawn_count = spawn_count + 1
  local guid = "g" .. spawn_count
  local o = {
    scale = { x = 1, y = 1, z = 1 }, pos = { x = p.position[1], y = p.position[2], z = p.position[3] },
    rot = { x = 0, y = 0, z = 0 }, buttons = {},
  }
  function o.getBounds() return { size = { x = 2 * o.scale.x, y = 2 * o.scale.y, z = 2 * o.scale.z } } end
  function o.getScale() return o.scale end
  function o.setScale(s) o.scale = { x = s[1], y = s[2], z = s[3] } end
  function o.getPosition() return o.pos end
  function o.getRotation() return o.rot end
  function o.setRotation(r) o.rot = { x = r[1], y = r[2], z = r[3] } end
  function o.positionToLocal(w) return { x = (w.x - o.pos.x) / o.scale.x, y = (w.y - o.pos.y) / o.scale.y, z = (w.z - o.pos.z) / o.scale.z } end
  function o.setColorTint() end
  function o.setName(n) o.name = n end
  function o.setLock(v) o.locked = v end
  function o.setPosition(p) o.pos = { x = p[1], y = p[2], z = p[3] } end
  function o.setVectorLines(l) o.lines = l end
  function o.clearButtons() o.buttons = {} end
  function o.createButton(b)
    assert(type(_G[b.click_function]) == "function", "missing click function " .. b.click_function)
    o.buttons[#o.buttons + 1] = b
  end
  function o.getGUID() return guid end
  function o.destruct()
    objects[guid] = nil
    onObjectDestroy(o)
  end
  objects[guid] = o
  p.callback_function(o)
  return o
end

local function ship_objects()
  local list = {}
  for guid, s in pairs(State.ships) do list[#list + 1] = { obj = objects[guid], ship = s } end
  return list
end

-- Fixed dice so a failure can be reproduced: SMOKE_SEED=n picks another game.
local seed = tonumber(os.getenv("SMOKE_SEED") or "") or 1
math.randomseed(seed)
math.randomseed = function() end -- the script's own os.time() seeding is ignored

dofile(root .. "/build/Global.lua")
onLoad("")
assert(xml and xml:find("sbPickFaction"), "add-ship dropdowns missing")
assert(ui_attrs["sbBtnSetup.interactable"] == "true", "setup button should be enabled")
assert(State.objects.sea and State.objects.surround, "sea and surround should spawn")

-- Add ships: Red adds Atrytian ships, Blue switches to Pirates.
uiAddShip(red)
uiPickRate(red, "1st Rate (65 pts)")
uiAddShip(red)
uiPickSide(blue, "Blue")
uiPickFaction(blue, "Pirate Nations")
assert(xml:find("Boarders %(2 pts%) G12 B16"), "crew options should follow the faction")
uiPickCrew(blue, "Gunners (2 pts) G13 B14 R12 O12")
uiAddShip(red) -- refused: Red can't add Blue ships
uiAddShip(blue)
local count = 0
for _ in pairs(State.ships) do count = count + 1 end
assert(count == 3, "expected 3 ships, got " .. count)
for _, e in ipairs(ship_objects()) do
  assert(#e.obj.buttons == 2, e.ship.name .. " should have a label and Done button")
  -- 6 attitude rays (30, 90, 150 off the bow, both sides) + 2 arrow lines.
  assert(#e.obj.lines == 8, e.ship.name .. " has " .. #e.obj.lines .. " lines")
  for _, l in ipairs(e.obj.lines) do
    for _, p in ipairs(l.points) do
      -- Stays on the base: local coords within half size (ship at rotation 0 or 180, scale = size).
      assert(math.abs(p[1] * e.obj.scale.x) <= e.ship.base.width / 2 + 1e-6, "line leaves the base sideways")
      assert(math.abs(p[3] * e.obj.scale.z) <= e.ship.base.length / 2 + 1e-6, "line leaves the base lengthways")
    end
  end
end

-- Game controls stay hidden until Start Game.
assert(ui_attrs["sbGameSection.active"] == "false" and ui_attrs["sbSetupSection.active"] == "true")
assert(ui_values.sbTitle == "Sail & Broadside")
uiSetupWind(host)
assert(State.turn.phase == "setup", "wind can't be rolled before Start Game")
uiStartGame(red)
assert(not State.started, "only the host starts the game")
uiStartGame(host)
assert(ui_attrs["sbGameSection.active"] == "true" and ui_attrs["sbSetupSection.active"] == "false")
uiAddShip(host)
assert(count == 3 and spawn_count == 5, "no ships can be added after Start Game")
assert(ui_values.sbFleetText:find("Blue 1st Rate 1"), "fleet panel should list ships")
assert(ui_values.sbFleetText:find("Crew 9/9  Hull 6/6"), "pirate 1st rate has 6 hull")

uiSetupWind(host)
for _, e in ipairs(ship_objects()) do assert(e.obj.locked, "Start Game locks ships") end
local scrapes = 0
local reloaded_mid_move = false
local backed, drifted = 0, 0
local guard = 0
while State.turn.phase ~= "over" do
  guard = guard + 1
  assert(guard < 200, "game did not finish")
  local phase = State.turn.phase
  if phase == "initiative" then
    uiRollInitiative(host)
  elseif phase == "activation" then
    local side = State.turn.current
    local seat = side == "red" and "Red" or "Blue"
    local wrong = side == "red" and "Blue" or "Red"
    local id = State.turn.ships[side][1]
    for _, sid in ipairs(State.turn.ships[side]) do
      if not State.turn.activated[sid] then id = sid break end
    end
    local obj = objects[id]
    assert(obj.locked, "ships are locked outside their move")
    assert(obj.buttons[2].label == "Move")

    sbShipDone(obj, seat) -- refused: must move first
    assert(not State.turn.activated[id], "can't end activation before moving")
    sbShipMove(obj, wrong)
    assert(not State.move, "wrong seat can't move the ship")
    sbShipMove(obj, seat)
    assert(State.move and not obj.locked and obj.buttons[2].label == "Moving")

    local turn_no = State.turn.turn
    if turn_no == 4 then
      -- Backward with a turn (D-016): drag behind and to one side, nudge, confirm.
      uiMoveBackward(Player[seat])
      local st = State.move.start
      local r = math.rad(st.h)
      obj.held_by_color = seat
      obj.pos = { x = st.x - math.sin(r) * 1.2 + math.cos(r) * 1.2, y = obj.pos.y, z = st.z - math.cos(r) * 1.2 - math.sin(r) * 1.2 }
      for _ = 1, 4 do onUpdate() end
      obj.held_by_color = nil
      onObjectDrop(seat, obj)
      uiNudgeLeft(Player[seat])
      local planned = State.move.plan
      assert(planned.backward, "backward mode plans a backward move")
      assert(planned.length <= State.move.allow.backward + 1e-9, "backward move within allowance")
      local fx, fz = math.sin(r), math.cos(r)
      local ahead = (planned.end_pose.x - st.x) * fx + (planned.end_pose.z - st.z) * fz
      assert(ahead <= 1e-9, "backward move never ends ahead of the start")
      uiMoveConfirm(Player[seat])
      assert(not State.move and obj.locked and State.ships[id].moved)
      assert(math.abs(obj.rot.y - planned.end_pose.h) < 1e-9, "ship placed at the backward move's heading")
      if planned.contact then scrapes = scrapes + 1 end
      backed = backed + 1
    elseif turn_no == 5 then
      -- Drift instead of moving (D-017, D-015).
      uiMoveDrift(Player[seat])
      uiNudgeRight(Player[seat]) -- refused: drifting ships can't turn
      assert(State.move.offset == 0, "drift can't turn")
      local planned = State.move.plan
      local expect = State.wind.blowing and 1.5 or 0
      assert(planned.contact or math.abs(planned.length - expect) < 1e-9,
        "drift should be " .. expect .. ", got " .. planned.length)
      uiMoveConfirm(Player[seat])
      assert(not State.move and State.ships[id].moved)
      if planned.contact then scrapes = scrapes + 1 end
      drifted = drifted + 1
    else
      -- Drag onto the nearest enemy ship (so the sides eventually scrape), preview, drop.
      local aim, best
      for _, e in ipairs(ship_objects()) do
        if e.ship.side ~= side then
          local d = (e.obj.pos.x - obj.pos.x) ^ 2 + (e.obj.pos.z - obj.pos.z) ^ 2
          if not best or d < best then aim, best = e.obj, d end
        end
      end
      obj.held_by_color = seat
      obj.pos = { x = aim.pos.x, y = obj.pos.y, z = aim.pos.z }
      for _ = 1, 4 do onUpdate() end
      assert(State.move.plan, "dragging should preview a plan")
      obj.held_by_color = nil
      onObjectDrop(seat, obj)
      if State.turn.turn == 2 and not reloaded_mid_move then
        -- Save and reload with a move in progress (TTS autosaves at any time).
        reloaded_mid_move = true
        local saved = onSave()
        assert(type(saved) == "string", "onSave should return JSON text")
        State = nil
        onLoad(saved)
        assert(State.move and State.move.plan and State.move.ship == id, "move in progress survives a reload")
      end
      uiNudgeRight(Player[wrong])
      assert(State.move.offset == 0, "wrong seat can't nudge")
      uiNudgeRight(Player[seat])
      uiNudgeLeft(Player[seat])
      local planned = State.move.plan
      assert(planned.length <= State.move.allow.forward + 1e-9, "move within allowance")
      assert(planned.length >= State.move.allow.min_forward - 1e-9 or planned.contact, "move at least the minimum")
      uiMoveConfirm(Player[seat])
      assert(not State.move and obj.locked and State.ships[id].moved)
      assert(math.abs(obj.pos.x - planned.end_pose.x) < 1e-9, "ship placed at the end of its path")
      if planned.contact then scrapes = scrapes + 1 end
    end

    sbShipDone(obj, wrong) -- wrong seat is refused
    assert(not State.turn.activated[id], "wrong seat should not activate")
    sbShipDone(obj, seat)
    assert(State.turn.activated[id], "ship should be activated")
    assert(obj.buttons[2].label == "Activated")
  elseif phase == "wind" then
    uiWindPhase(host)
  end
  -- Delete a Red ship mid-game, as if a player removed it.
  if State.turn.turn == 3 and count == 3 then
    for _, e in ipairs(ship_objects()) do
      if e.ship.side == "red" then e.obj.destruct() break end
    end
    count = 2
  end
end
assert(State.turn.turn == 6, "expected 6 turns, got " .. State.turn.turn)
assert(scrapes > 0, "ships sailing at each other should scrape")
assert(reloaded_mid_move, "smoke should reload mid-move")
assert(backed > 0 and drifted > 0, "smoke should back up and drift")
print(("seed %d, scrapes: %d, backward moves: %d, drifts: %d"):format(seed, scrapes, backed, drifted))

local saved = onSave()
State = nil
onLoad(saved)
assert(State.turn.phase == "over")
assert(spawn_count == 5, "reload should reuse existing objects")

uiNewGame(host)
assert(next(State.ships) == nil, "new game should clear ships")

print(("smoke ok: %d broadcasts, last: %s"):format(#messages, messages[#messages]))
