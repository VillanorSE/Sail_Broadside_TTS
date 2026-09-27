-- Sail & Broadside: values for rules that are still in flux (v0.8.2.4).
-- A rules change should be a one-line edit here, not a code change.
-- Entries marked PLACEHOLDER were not in DESIGN.md and must be checked
-- against the rules docx.

return {
  game = {
    max_turns = 6,
  },

  -- Sides and the TTS seat colour that controls each one.
  -- Red deploys on the south edge (Zone A) facing north, Blue on the north
  -- edge (Zone B) facing south. spawn_z is where new ships are lined up.
  sides = {
    { id = "red",  name = "Red",  seat = "Red",  heading = 0,   spawn_z = -20, tint = { 0.72, 0.16, 0.16 } },
    { id = "blue", name = "Blue", seat = "Blue", heading = 180, spawn_z = 20,  tint = { 0.16, 0.36, 0.75 } },
  },

  wind = {
    -- Game start condition roll (D20).
    condition_table = {
      { min = 1,  max = 5,  result = "calm"  },
      { min = 6,  max = 15, result = "fair"  },
      { min = 16, max = 20, result = "rough" },
    },
    condition_names = { calm = "Calm", fair = "Fair Weather", rough = "Rough Seas" },

    -- Compass bearings the wind blows FROM (0 = north = +z, clockwise).
    -- Deployment zone A is the south edge, B the north edge; the wind never
    -- blows between them. Rules numbering, seen from behind zone A: 1 is the
    -- near-left corner, then clockwise (1 SW, 2 W, 3 NW, 4 NE, 5 E, 6 SE),
    -- so 1-4, 2-5 and 3-6 are opposite pairs.
    direction_table = { 225, 270, 315, 45, 90, 135 },
    blocked_axis = { 0, 180 },

    -- Wind Phase change roll (D20) per condition (rules: Wind Shift).
    change_tables = {
      calm = {
        { min = 1,  max = 5,  result = "none" },
        { min = 6,  max = 17, result = "steady" },
        { min = 18, max = 20, result = "mild_shift" },
      },
      fair = {
        { min = 1,  max = 2,  result = "none" },
        { min = 3,  max = 14, result = "steady" },
        { min = 15, max = 19, result = "mild_shift" },
        { min = 20, max = 20, result = "squall" },
      },
      rough = {
        { min = 1,  max = 1,  result = "none" },
        { min = 2,  max = 8,  result = "steady" },
        { min = 9,  max = 16, result = "mild_shift" },
        { min = 17, max = 20, result = "squall" },
      },
    },
    change_names = { none = "No wind", steady = "Steady", mild_shift = "Mild shift", squall = "Squall" },

    -- Mild shift: D20 1-10 counterclockwise, 11-20 clockwise.
    shift_ccw_max = 10,
    -- Ruling: a mild shift moves the wind one D6 point either way (45 degrees,
    -- or 90 when stepping over the deployment axis, e.g. point 3 -> 4).
    shift_step = 45,
    shift_skips_blocked_axis = true,

    -- Attitude thresholds, in degrees between the ship's heading and the
    -- direction the wind blows toward (0 = wind dead astern).
    attitude = {
      running_below = 30,  -- < 30 off stern
      reaching_max = 90,   -- 30..90 off stern
      beating_max = 150,   -- 30..90 off bow
    },                     -- anything else: against (< 30 off bow)
    multipliers = { running = 1, reaching = 1.5, beating = 0.5, against = 0.25 },
    no_wind_multiplier = 1, -- ruling: becalmed, every ship moves at base sail
  },

  initiative = {
    die = 20,
    max_rerolls = 50,  -- safety cap; ties on total and running ships re-roll
  },

  ship = {
    full_pct = 50,      -- crew at or above this % of base crew: full strength
    abandoned_pct = 25, -- at or below: abandoned
    wreck_hull = -2,    -- hull remaining at or below this: wreck, removed
  },

  movement = {
    min_move = 2,
    backward_fraction = 0.25, -- backward moves: 1/4 of base movement, no wind
    nudge_step = 5,           -- degrees per heading nudge click
    contact_step = 0.05,      -- inches between scrape checks along a path
    idle_drift = 2,       -- active ship that elects not to move
    defeated_drift = 1.5, -- defeated ships, Wind Phase
  },

  shooting = {
    head_on_to_hit = -2,
    tail_on_to_hit = -2,
    tail_on_durability = -3,
    obstructed_to_hit = -3,   -- open item: may become equal to head/tail-on
    durability_saves_on_equal = true, -- D20 + mod >= damage negates the hit
    crit_can_be_saved = false,         -- the first crit damage is automatic
    ghost_lifetime = "until_durability", -- or "until_attack_roll"
  },

  -- Play area in inches (1 TTS unit = 1 inch). PLACEHOLDER size.
  table = {
    width = 48,
    depth = 48,
    surface_y = 1.0,  -- top of the spawned sea block
    sea_color = { 0.11, 0.29, 0.42 },
    surround_width = 84,
    surround_depth = 64,
    surround_color = { 0.16, 0.17, 0.19 },
  },

  tts = {
    log_lines = 8,
    label_scale = 0.5, -- size of ship name labels; tune in game
    done_scale = 1.5,  -- size of the Done button on ship bases
    wind_indicator = { x = 30, z = 18, length = 5 },
  },
}
