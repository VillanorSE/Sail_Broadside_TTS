-- Test runner. From the repo root:  lua tests/run.lua [filter]
local script = (arg and arg[0]) or "tests/run.lua"
local root = script:match("^(.*)[/\\]tests[/\\][^/\\]*$") or "."
package.path = root .. "/?.lua;" .. package.path

local FILES = {
  "tests.test_angle",
  "tests.test_dice",
  "tests.test_config",
  "tests.test_wind",
  "tests.test_initiative",
  "tests.test_turn",
  "tests.test_data",
  "tests.test_ship",
}

local filter = arg and arg[1]
local passed, failed = 0, 0

for _, mod in ipairs(FILES) do
  local cases = require(mod)
  for _, case in ipairs(cases) do
    local name = mod:gsub("^tests%.", "") .. " > " .. case[1]
    if not filter or name:find(filter, 1, true) then
      local ok, err = pcall(case[2])
      if ok then
        passed = passed + 1
      else
        failed = failed + 1
        print("FAIL  " .. name .. "\n      " .. tostring(err))
      end
    end
  end
end

print(string.format("%d passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
