-- Smoke test for the bundled Global script against a fake TTS API.
-- Catches nil calls and typos in /tts before the user loads it in game.
--   lua tools/bundle.lua && lua tools/tts_smoke.lua
local script = (arg and arg[0]) or "tools/tts_smoke.lua"
local root = script:match("^(.*)[/\\]tools[/\\][^/\\]*$") or "."

local messages, ui_values, ui_attrs, lines = {}, {}, {}, nil

local function deep_copy(v)
  if type(v) ~= "table" then return v end
  local t = {}
  for k, x in pairs(v) do t[k] = deep_copy(x) end
  return t
end

-- Stand-ins for the TTS globals the script uses.
JSON = { encode = function(t) return deep_copy(t) end, decode = function(t) return deep_copy(t) end }
UI = {
  setXml = function(xml) assert(xml:find("sbPanel"), "panel missing from XML") end,
  setValue = function(id, v) ui_values[id] = v end,
  setAttribute = function(id, k, v) ui_attrs[id .. "." .. k] = v end,
}
Wait = { frames = function(fn) fn() end }
Global = { setVectorLines = function(l) lines = l end }
function broadcastToAll(msg) messages[#messages + 1] = msg end
function broadcastToColor(msg) messages[#messages + 1] = "(private) " .. msg end
function getSeatedPlayers() return { "Red", "Blue" } end

local spawned = {}
function getObjectFromGUID(guid) return spawned[guid] end
function spawnObject(p)
  local guid = "g" .. (#spawned + 1)
  local o = { scale = { x = 1, y = 1, z = 1 } }
  function o.getBounds() return { size = { x = 2 * o.scale.x, y = 2 * o.scale.y, z = 2 * o.scale.z } } end
  function o.getScale() return o.scale end
  function o.setScale(s) o.scale = { x = s[1], y = s[2], z = s[3] } end
  function o.setColorTint() end
  function o.setName(n) o.name = n end
  function o.setLock() end
  function o.getGUID() return guid end
  spawned[guid] = o
  spawned[#spawned + 1] = o
  p.callback_function(o)
  return o
end

local host = { color = "White", host = true }
local red = { color = "Red", host = false }
local blue = { color = "Blue", host = false }

dofile(root .. "/build/Global.lua")
onLoad("")
assert(ui_attrs["sbBtnSetup.interactable"] == "true", "setup button should be enabled")
assert(lines and #lines >= 2, "border and wind ring should be drawn")
assert(#spawned == 2 and State.objects.sea and State.objects.surround, "sea and surround should spawn")
local sea = getObjectFromGUID(State.objects.sea)
assert(sea.getBounds().size.x == 48 and sea.name == "Sea", "sea should be scaled to 48 wide")

uiSetupWind(red) -- refused, not host
assert(State.turn.phase == "setup")
uiSetupWind(host)
assert(State.turn.phase == "initiative" and State.wind)

local guard = 0
while State.turn.phase ~= "over" do
  guard = guard + 1
  assert(guard < 200, "game did not finish")
  local phase = State.turn.phase
  if phase == "initiative" then
    uiRollInitiative(host)
  elseif phase == "activation" then
    local seat = State.turn.current == "red" and red or blue
    uiEndActivation(seat == red and blue or red) -- wrong seat is refused
    uiEndActivation(seat)
  elseif phase == "wind" then
    uiWindPhase(host)
  end
end
assert(State.turn.turn == 6, "expected 6 turns, got " .. State.turn.turn)

-- Save and reload mid-state.
local saved = onSave()
State = nil
onLoad(saved)
assert(State.turn.phase == "over")
assert(#spawned == 2, "reload should reuse the existing sea, not spawn another")

print(("smoke ok: %d broadcasts, last: %s"):format(#messages, messages[#messages]))
print("panel: " .. tostring(ui_values.sbTurn) .. " | " .. tostring(ui_values.sbWind))
