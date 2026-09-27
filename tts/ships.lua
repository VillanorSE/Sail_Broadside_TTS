-- Ship bases: flat blocks at the rulebook base size, with a bow arrow,
-- a name label and a "Done" (end activation) button.
--
-- Headings are compass bearings (0 = +z, 90 = +x) and equal the object's
-- y rotation. Local offsets are given in inches (right, up, forward) and
-- converted with positionToLocal so object scale never has to be guessed.
local M = {}

M.THICKNESS = 0.15

local function world_point(obj, right, up, forward)
  local p, rot = obj.getPosition(), math.rad(obj.getRotation().y)
  local c, s = math.cos(rot), math.sin(rot)
  return { x = p.x + right * c + forward * s, y = p.y + up, z = p.z - right * s + forward * c }
end

local function local_point(obj, right, up, forward)
  local l = obj.positionToLocal(world_point(obj, right, up, forward))
  return { l.x, l.y, l.z }
end

function M.spawn(ship, pos, heading, color, surface_y, on_ready)
  spawnObject({
    type = "BlockSquare",
    position = { pos.x, surface_y + M.THICKNESS / 2 + 0.05, pos.z },
    rotation = { 0, 0, 0 },
    sound = false,
    callback_function = function(obj)
      local b, s = obj.getBounds(), obj.getScale()
      obj.setScale({
        s.x * ship.base.width / b.size.x,
        s.y * M.THICKNESS / b.size.y,
        s.z * ship.base.length / b.size.z,
      })
      obj.setRotation({ 0, heading, 0 })
      obj.setColorTint(color)
      obj.setName(ship.name)
      on_ready(obj)
    end,
  })
end

-- Ray from the base centre, `deg` off the bow (0) or stern (180) toward
-- one side (sign = 1 right, -1 left), clipped to the base edge.
local function ray_end(W, L, deg, sign)
  local r = math.rad(deg)
  local dx, dz = math.sin(r) * sign, math.cos(r)
  local t = math.huge
  if math.abs(dx) > 1e-9 then t = math.min(t, W / 2 / math.abs(dx)) end
  if math.abs(dz) > 1e-9 then t = math.min(t, L / 2 / math.abs(dz)) end
  return dx * t, dz * t
end

local WHITE = { 1, 1, 1 }

-- (Re)draws the markings, label and button. Safe to call on every refresh.
-- opts: { button = M.BUTTONS entry, label_scale, done_scale, attitude = config.wind.attitude }
function M.decorate(obj, ship, opts)
  local s = obj.getScale()
  local top = M.THICKNESS / 2 + 0.02
  local L, W = ship.base.length, ship.base.width
  local lines = {}

  local function line(points, thickness)
    local pts = {}
    for i, p in ipairs(points) do pts[i] = local_point(obj, p[1], top, p[2]) end
    lines[#lines + 1] = { points = pts, color = WHITE, thickness = thickness or 0.025 }
  end

  -- Wind attitude boundaries: the X marks 30 degrees off the stern
  -- (running) and off the bow (against); the cross line is abeam, 90 degrees.
  -- Angles are off the bow: running ends at 180 - 30, beating ends at 180 - 150.
  local a = opts.attitude
  local drawn = {}
  for _, deg in ipairs({ 180 - a.running_below, 180 - a.reaching_max, 180 - a.beating_max }) do
    if not drawn[deg] then
      drawn[deg] = true
      for _, sign in ipairs({ 1, -1 }) do
        local x, z = ray_end(W, L, deg, sign)
        line({ { 0, 0 }, { x, z } })
      end
    end
  end

  -- Small bow arrow in the front section.
  line({ { 0, L * 0.3 }, { 0, L * 0.46 } }, 0.03)
  line({ { -W * 0.1, L * 0.4 }, { 0, L * 0.46 }, { W * 0.1, L * 0.4 } }, 0.03)

  obj.setVectorLines(lines)

  -- Text faces the stern so it reads upright from behind the ship.
  local k, d = opts.label_scale, opts.done_scale
  obj.clearButtons()
  obj.createButton({
    click_function = "sbNoop", function_owner = Global,
    label = ship.name,
    position = local_point(obj, 0, top, -L * 0.14),
    rotation = { 0, 180, 0 },
    width = 0, height = 0, font_size = 90,
    font_color = WHITE,
    scale = { k / s.x, 1, k / s.z },
  })
  local b = opts.button
  obj.createButton({
    click_function = b.click, function_owner = Global,
    label = b.label,
    tooltip = b.tooltip,
    position = local_point(obj, 0, top, -L * 0.34),
    rotation = { 0, 180, 0 },
    width = 420, height = 150, font_size = 80,
    color = b.color,
    font_color = { 0, 0, 0 },
    scale = { d / s.x, 1, d / s.z },
  })
end

-- Button states for the ship base.
M.BUTTONS = {
  move = { label = "Move", click = "sbShipMove", color = { 0.6, 0.85, 1 }, tooltip = "Start this ship's move" },
  moving = { label = "Moving", click = "sbNoop", color = { 0.45, 0.75, 0.45 }, tooltip = "Drag the ship; confirm in the panel" },
  done = { label = "Done", click = "sbShipDone", color = { 0.95, 0.85, 0.6 }, tooltip = "End this ship's activation" },
  activated = { label = "Activated", click = "sbNoop", color = { 0.35, 0.35, 0.35 }, tooltip = "Already activated this turn" },
}

return M
