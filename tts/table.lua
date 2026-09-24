-- Play surface: a locked sea block at the rules table size, on a larger
-- surround so objects dropped off the sea don't fall. Built from scaled
-- BlockSquares so the top height is known exactly (lines are drawn on it).
local M = {}

local function spawn_block(spec, on_ready)
  spawnObject({
    type = "BlockSquare",
    position = { 0, spec.top - spec.thickness / 2, 0 },
    rotation = { 0, 0, 0 },
    sound = false,
    callback_function = function(obj)
      -- Scale from the measured size so this works whatever the block's native size is.
      local b, s = obj.getBounds(), obj.getScale()
      obj.setScale({
        s.x * spec.width / b.size.x,
        s.y * spec.thickness / b.size.y,
        s.z * spec.depth / b.size.z,
      })
      obj.setColorTint(spec.color)
      obj.setName(spec.name)
      obj.setLock(true)
      obj.interactable = false
      on_ready(obj)
    end,
  })
end

-- guids: table kept in the saved state; filled in with new objects' GUIDs.
function M.ensure(config, guids)
  local t = config.table
  local specs = {
    sea = { name = "Sea", width = t.width, depth = t.depth, top = t.surface_y, thickness = 0.4, color = t.sea_color },
    surround = {
      name = "Surround", width = t.surround_width, depth = t.surround_depth,
      top = t.surface_y - 0.1, thickness = 0.4, color = t.surround_color,
    },
  }
  for key, spec in pairs(specs) do
    if not (guids[key] and getObjectFromGUID(guids[key])) then
      spawn_block(spec, function(obj) guids[key] = obj.getGUID() end)
    end
  end
end

return M
