-- Turn tracker: setup -> (initiative -> activation -> wind) x N -> over.
--
-- Actions return true on success, or false plus a message the UI can show.
local M = {}

M.SETUP, M.INITIATIVE, M.ACTIVATION, M.WIND, M.OVER =
  "setup", "initiative", "activation", "wind", "over"

function M.new(side_ids, max_turns)
  local ships = {}
  for _, id in ipairs(side_ids) do ships[id] = {} end
  return {
    turn = 0,
    max_turns = max_turns,
    phase = M.SETUP,
    sides = side_ids,
    ships = ships,      -- side id -> list of ship ids able to activate this turn
    activated = {},     -- ship id -> true
    order = nil,        -- initiative order of side ids
    current = nil,      -- side id to activate next
  }
end

-- Wind has been rolled; begin turn 1.
function M.start(state)
  if state.phase ~= M.SETUP then return false, "game already started" end
  state.turn = 1
  state.phase = M.INITIATIVE
  return true
end

function M.set_ships(state, side, ids)
  if not state.ships[side] then return false, "unknown side " .. tostring(side) end
  local list = {}
  for i, id in ipairs(ids) do list[i] = id end
  state.ships[side] = list
  return true
end

function M.remaining(state, side)
  local out = {}
  for _, id in ipairs(state.ships[side] or {}) do
    if not state.activated[id] then out[#out + 1] = id end
  end
  return out
end

-- The next side to activate after `last` (nil = start of the round),
-- skipping sides with no ships left. nil when everyone has activated.
function M.next_side(state, last)
  local order = state.order
  local n = #order
  local start = 1
  if last then
    for i, id in ipairs(order) do
      if id == last then start = i % n + 1 end
    end
  end
  for k = 0, n - 1 do
    local side = order[(start - 1 + k) % n + 1]
    if #M.remaining(state, side) > 0 then return side end
  end
  return nil
end

local function enter_activation(state)
  state.current = M.next_side(state, nil)
  state.phase = state.current and M.ACTIVATION or M.WIND
end

function M.set_initiative(state, order)
  if state.phase ~= M.INITIATIVE then return false, "not the initiative phase" end
  state.order = order
  state.activated = {}
  enter_activation(state)
  return true
end

function M.activate(state, side, ship_id)
  if state.phase ~= M.ACTIVATION then return false, "not the activation phase" end
  if side ~= state.current then return false, "it is " .. tostring(state.current) .. "'s activation" end
  local owned = false
  for _, id in ipairs(state.ships[side]) do
    if id == ship_id then owned = true end
  end
  if not owned then return false, tostring(ship_id) .. " is not an active ship of " .. side end
  if state.activated[ship_id] then return false, tostring(ship_id) .. " has already activated" end

  state.activated[ship_id] = true
  state.current = M.next_side(state, side)
  if not state.current then state.phase = M.WIND end
  return true
end

-- Takes a ship out of the turn (deleted, sunk, abandoned). If that leaves
-- the side to move with nothing to activate, play passes on.
function M.remove_ship(state, ship_id)
  for _, side in ipairs(state.sides) do
    local list = state.ships[side]
    for i = #list, 1, -1 do
      if list[i] == ship_id then table.remove(list, i) end
    end
  end
  state.activated[ship_id] = nil
  if state.phase == M.ACTIVATION and #M.remaining(state, state.current) == 0 then
    state.current = M.next_side(state, state.current)
    if not state.current then state.phase = M.WIND end
  end
end

-- Called once the Wind Phase (drift + wind roll) has been resolved.
function M.end_wind_phase(state)
  if state.phase ~= M.WIND then return false, "not the wind phase" end
  if state.turn >= state.max_turns then
    M.end_game(state, "turns")
  else
    state.turn = state.turn + 1
    state.phase = M.INITIATIVE
    state.order = nil
    state.current = nil
    state.activated = {}
  end
  return true
end

function M.end_game(state, reason, winner)
  state.phase = M.OVER
  state.current = nil
  state.end_reason = reason
  state.winner = winner
end

return M
