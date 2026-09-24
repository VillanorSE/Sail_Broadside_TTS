-- Screen UI: game control panel (right) and fleet status panel (left).
-- Buttons and dropdowns call global functions in tts/global.lua.
local M = {}

local function esc(s)
  return (tostring(s):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;"))
end

local function text(id, size, extra)
  return string.format('<Text id="%s" fontSize="%d" color="#FFFFFF" alignment="MiddleLeft" preferredHeight="%d" %s></Text>',
    id, size, size + 10, extra or "")
end

local function button(id, label, handler)
  return string.format('<Button id="%s" onClick="%s" preferredHeight="30" fontSize="14">%s</Button>', id, handler, esc(label))
end

-- dd: { id, label, handler, options = { {value, label}... }, selected = value }
local function dropdown(dd)
  local opts = {}
  for i, o in ipairs(dd.options) do
    opts[i] = string.format('<Option%s>%s</Option>', o[1] == dd.selected and ' selected="true"' or "", esc(o[2]))
  end
  return table.concat({
    '<HorizontalLayout preferredHeight="28" spacing="6" childForceExpandWidth="false">',
    string.format('<Text preferredWidth="60" fontSize="13" color="#C8D2DC" alignment="MiddleLeft">%s</Text>', esc(dd.label)),
    string.format('<Dropdown id="%s" onValueChanged="%s" flexibleWidth="1" preferredWidth="220" fontSize="13">', dd.id, dd.handler),
    table.concat(opts),
    '</Dropdown></HorizontalLayout>',
  })
end

-- dropdowns: list of dropdown specs for the Add Ship section.
function M.build(dropdowns)
  local picks = {}
  for i, dd in ipairs(dropdowns) do picks[i] = dropdown(dd) end
  UI.setXml(table.concat({
    '<Panel id="sbPanel" width="320" height="700" rectAlignment="UpperRight" offsetXY="-10 -80" color="#14222FEE" padding="10 10 10 10">',
    '<VerticalLayout spacing="4" childForceExpandHeight="false">',
    -- Titles are set with UI.setValue: TTS shows XML entities like &amp; literally.
    '<Text id="sbTitle" fontSize="18" fontStyle="Bold" color="#F0D9A0" alignment="MiddleLeft" preferredHeight="26"></Text>',
    text("sbTurn", 15),
    text("sbWind", 15),
    text("sbInit", 13),
    text("sbActive", 15, 'fontStyle="Bold"'),
    -- Setup: add ships, then Start Game. Hidden once the game starts.
    '<VerticalLayout id="sbSetupSection" spacing="4" childForceExpandHeight="false">',
    '<Text fontSize="15" fontStyle="Bold" color="#F0D9A0" alignment="MiddleLeft" preferredHeight="26">Add Ship</Text>',
    table.concat(picks),
    button("sbBtnAdd", "Add Ship", "uiAddShip"),
    button("sbBtnStart", "Start Game", "uiStartGame"),
    '</VerticalLayout>',
    -- Game flow: shown once the game starts.
    '<VerticalLayout id="sbGameSection" active="false" spacing="4" childForceExpandHeight="false">',
    button("sbBtnSetup", "Roll Wind", "uiSetupWind"),
    button("sbBtnInit", "Roll Initiative", "uiRollInitiative"),
    button("sbBtnWind", "Run Wind Phase", "uiWindPhase"),
    '</VerticalLayout>',
    button("sbBtnNew", "New Game", "uiNewGame"),
    '<Text id="sbLog" fontSize="12" color="#C8D2DC" alignment="UpperLeft" preferredHeight="150"></Text>',
    '</VerticalLayout>',
    '</Panel>',
    '<Panel id="sbFleet" width="340" height="560" rectAlignment="UpperLeft" offsetXY="10 -80" color="#14222FDD" padding="10 10 10 10">',
    '<VerticalLayout spacing="2" childForceExpandHeight="false">',
    '<Text fontSize="16" fontStyle="Bold" color="#F0D9A0" alignment="MiddleLeft" preferredHeight="24">Fleet</Text>',
    '<Text id="sbFleetText" fontSize="12" color="#FFFFFF" alignment="UpperLeft" preferredHeight="520"></Text>',
    '</VerticalLayout>',
    '</Panel>',
  }))
end

-- UI.setXml is applied on the next frame, so updates are deferred a frame.
function M.update(view)
  Wait.frames(function()
    UI.setValue("sbTitle", "Sail & Broadside")
    UI.setAttribute("sbSetupSection", "active", view.started and "false" or "true")
    UI.setAttribute("sbGameSection", "active", view.started and "true" or "false")
    UI.setValue("sbTurn", view.turn)
    UI.setValue("sbWind", view.wind)
    UI.setValue("sbInit", view.initiative)
    UI.setValue("sbActive", view.active)
    UI.setValue("sbLog", view.log)
    UI.setValue("sbFleetText", view.fleet)
    for id, enabled in pairs(view.buttons) do
      UI.setAttribute(id, "interactable", enabled and "true" or "false")
    end
  end, 1)
end

return M
