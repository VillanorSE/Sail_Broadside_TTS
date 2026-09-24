-- Minimal assertion helpers. A test file returns a list of { name, fn } pairs.
local T = {}

local function fail(msg, level)
  error(msg, (level or 2) + 1)
end

function T.eq(actual, expected, msg)
  if actual ~= expected then
    fail((msg and msg .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

function T.near(actual, expected, eps, msg)
  if math.abs(actual - expected) > (eps or 1e-9) then
    fail((msg and msg .. ": " or "") .. "expected ~" .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

function T.truthy(v, msg)
  if not v then fail(msg or "expected a truthy value") end
end

function T.falsy(v, msg)
  if v then fail(msg or ("expected a falsy value, got " .. tostring(v))) end
end

function T.list_eq(actual, expected, msg)
  local ok = #actual == #expected
  for i = 1, #expected do
    if actual[i] ~= expected[i] then ok = false end
  end
  if not ok then
    local function show(t)
      local parts = {}
      for i, v in ipairs(t) do parts[i] = tostring(v) end
      return "{" .. table.concat(parts, ", ") .. "}"
    end
    fail((msg and msg .. ": " or "") .. "expected " .. show(expected) .. ", got " .. show(actual))
  end
end

function T.errors(fn, pattern)
  local ok, err = pcall(fn)
  if ok then fail("expected an error") end
  if pattern and not tostring(err):find(pattern) then
    fail("error '" .. tostring(err) .. "' does not match '" .. pattern .. "'")
  end
end

return T
