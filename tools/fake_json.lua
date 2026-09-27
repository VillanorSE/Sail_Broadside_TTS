-- A strict JSON encode/decode for the fake TTS API, so saves in the smoke
-- test really go through text the way they do in TTS. It fails loudly on
-- things TTS would mangle or reject:
--   - functions, userdata, NaN and infinity;
--   - tables mixing array and non-array keys;
--   - number keys that aren't a plain 1..n array (they come back as strings).
-- Empty tables encode as [] and decode as empty tables.
local M = {}

local function is_array(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  for i = 1, n do
    if t[i] == nil then return false, n end
  end
  return true, n
end

local function quote(s)
  return '"' .. s:gsub('[%c"\\]', function(c)
    local map = { ['"'] = '\\"', ["\\"] = "\\\\", ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t" }
    return map[c] or string.format("\\u%04x", c:byte())
  end) .. '"'
end

local function encode(v, path)
  local t = type(v)
  if t == "nil" then return "null" end
  if t == "boolean" then return tostring(v) end
  if t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then error("JSON: " .. path .. " is " .. tostring(v)) end
    if v == math.floor(v) and math.abs(v) < 2 ^ 53 then return string.format("%d", v) end
    return string.format("%.17g", v)
  end
  if t == "string" then return quote(v) end
  if t ~= "table" then error("JSON: " .. path .. " is a " .. t) end

  local arr, n = is_array(v)
  local parts = {}
  if arr then
    for i = 1, n do parts[i] = encode(v[i], path .. "[" .. i .. "]") end
    return "[" .. table.concat(parts, ",") .. "]"
  end
  local keys = {}
  for k in pairs(v) do
    if type(k) ~= "string" then
      error("JSON: " .. path .. " has non-string key " .. tostring(k) .. " (would come back as a string)")
    end
    keys[#keys + 1] = k
  end
  table.sort(keys)
  for i, k in ipairs(keys) do parts[i] = quote(k) .. ":" .. encode(v[k], path .. "." .. k) end
  return "{" .. table.concat(parts, ",") .. "}"
end

function M.encode(v) return encode(v, "State") end

function M.decode(s)
  local i = 1
  local function ws() i = s:find("[^ \t\r\n]", i) or #s + 1 end
  local value
  local function str()
    local out = {}
    i = i + 1
    while true do
      local c = s:sub(i, i)
      if c == '"' then i = i + 1 break end
      if c == "" then error("JSON: unterminated string") end
      if c == "\\" then
        local e = s:sub(i + 1, i + 1)
        if e == "u" then
          out[#out + 1] = string.char(tonumber(s:sub(i + 2, i + 5), 16))
          i = i + 6
        else
          out[#out + 1] = ({ n = "\n", r = "\r", t = "\t", b = "\b", f = "\f" })[e] or e
          i = i + 2
        end
      else
        out[#out + 1] = c
        i = i + 1
      end
    end
    return table.concat(out)
  end
  function value()
    ws()
    local c = s:sub(i, i)
    if c == "{" then
      local t = {}
      i = i + 1
      ws()
      if s:sub(i, i) == "}" then i = i + 1 return t end
      while true do
        ws()
        local k = str()
        ws()
        assert(s:sub(i, i) == ":", "JSON: expected ':'")
        i = i + 1
        t[k] = value()
        ws()
        local d = s:sub(i, i)
        i = i + 1
        if d == "}" then return t end
        assert(d == ",", "JSON: expected ',' or '}'")
      end
    elseif c == "[" then
      local t = {}
      i = i + 1
      ws()
      if s:sub(i, i) == "]" then i = i + 1 return t end
      while true do
        t[#t + 1] = value()
        ws()
        local d = s:sub(i, i)
        i = i + 1
        if d == "]" then return t end
        assert(d == ",", "JSON: expected ',' or ']'")
      end
    elseif c == '"' then
      return str()
    elseif s:find("^true", i) then i = i + 4 return true
    elseif s:find("^false", i) then i = i + 5 return false
    elseif s:find("^null", i) then i = i + 4 return nil
    end
    local num = s:match("^-?%d+%.?%d*[eE]?[-+]?%d*", i)
    if not num or num == "" then error("JSON: unexpected '" .. c .. "' at " .. i) end
    i = i + #num
    return tonumber(num)
  end
  local v = value()
  return v
end

return M
