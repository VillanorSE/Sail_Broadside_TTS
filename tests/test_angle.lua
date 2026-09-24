local T = require("tests.lib")
local angle = require("rules.angle")

return {
  { "norm wraps negatives and overflow", function()
    T.eq(angle.norm(-30), 330)
    T.eq(angle.norm(360), 0)
    T.eq(angle.norm(725), 5)
  end },
  { "diff is the short way round", function()
    T.eq(angle.diff(10, 350), 20)
    T.eq(angle.diff(0, 180), 180)
    T.eq(angle.diff(90, 90), 0)
    T.eq(angle.diff(-45, 45), 90)
  end },
  { "compass names", function()
    T.eq(angle.compass_name(0), "N")
    T.eq(angle.compass_name(45), "NE")
    T.eq(angle.compass_name(135), "SE")
    T.eq(angle.compass_name(315), "NW")
    T.eq(angle.compass_name(350), "N")
  end },
  { "vector points along the bearing", function()
    local v = angle.vector(90)
    T.near(v.x, 1)
    T.near(v.z, 0)
    v = angle.vector(0)
    T.near(v.x, 0)
    T.near(v.z, 1)
  end },
}
