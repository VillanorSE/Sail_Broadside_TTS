-- Writes a TTS save file with build/Global.lua as the Global script, so the
-- mod can be opened from Games > Save & Load instead of pasted in.
--   lua tools/make_save.lua [output.json]
-- Default output: the TTS Saves folder, as "Sail & Broadside (dev)".
local script = (arg and arg[0]) or "tools/make_save.lua"
local root = script:match("^(.*)[/\\]tools[/\\][^/\\]*$") or "."

local function default_out()
  local home = os.getenv("USERPROFILE") or os.getenv("HOME") or "."
  return home .. "/Documents/My Games/Tabletop Simulator/Saves/Sail_Broadside_Dev.json"
end
local out_path = arg[1] or default_out()

local f = assert(io.open(root .. "/build/Global.lua", "rb"), "run tools/bundle.lua first")
local lua = f:read("*a")
f:close()

local function json_string(s)
  s = s:gsub('[%c"\\]', function(c)
    local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
    return map[c] or string.format("\\u%04x", c:byte())
  end)
  return '"' .. s .. '"'
end

local fields = {
  { "SaveName", json_string("Sail & Broadside (dev)") },
  { "GameMode", json_string("Sail & Broadside") },
  { "Date", json_string(os.date("%m/%d/%Y %I:%M:%S %p")) },
  { "EpochTime", tostring(os.time()) },
  { "Table", json_string("Table_None") },
  { "Sky", json_string("Sky_Regal") },
  { "Note", json_string("") },
  { "LuaScript", json_string(lua) },
  { "LuaScriptState", json_string("") },
  { "XmlUI", json_string("") },
  { "ObjectStates", "[]" },
}
local parts = {}
for i, kv in ipairs(fields) do parts[i] = "  " .. json_string(kv[1]) .. ": " .. kv[2] end

local out = assert(io.open(out_path, "wb"), "cannot write " .. out_path)
out:write("{\n" .. table.concat(parts, ",\n") .. "\n}\n")
out:close()
print("wrote " .. out_path)
