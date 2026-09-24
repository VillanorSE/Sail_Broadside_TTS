-- Game control panel (TTS XML UI). Buttons call global functions in tts/global.lua.
local M = {}

local function text(id, size, extra)
  return string.format('<Text id="%s" fontSize="%d" color="#FFFFFF" alignment="MiddleLeft" preferredHeight="%d" %s></Text>',
    id, size, size + 10, extra or "")
end

local function button(id, label, handler)
  return string.format('<Button id="%s" onClick="%s" preferredHeight="30" fontSize="14">%s</Button>', id, handler, label)
end

M.XML = table.concat({
  '<Panel id="sbPanel" width="320" height="470" rectAlignment="UpperRight" offsetXY="-10 -80" color="#14222FEE" padding="10 10 10 10">',
  '<VerticalLayout spacing="4" childForceExpandHeight="false">',
  '<Text fontSize="18" fontStyle="Bold" color="#F0D9A0" alignment="MiddleLeft" preferredHeight="26">Sail &amp; Broadside</Text>',
  text("sbTurn", 15),
  text("sbWind", 15),
  text("sbInit", 13),
  text("sbActive", 15, 'fontStyle="Bold"'),
  button("sbBtnSetup", "Roll Wind (game start)", "uiSetupWind"),
  button("sbBtnInit", "Roll Initiative", "uiRollInitiative"),
  button("sbBtnActivate", "End Activation (test ship)", "uiEndActivation"),
  button("sbBtnWind", "Run Wind Phase", "uiWindPhase"),
  button("sbBtnNew", "New Game", "uiNewGame"),
  '<Text id="sbLog" fontSize="12" color="#C8D2DC" alignment="UpperLeft" preferredHeight="150"></Text>',
  '</VerticalLayout>',
  '</Panel>',
})

function M.build()
  UI.setXml(M.XML)
end

-- UI.setXml is applied on the next frame, so updates are deferred a frame.
function M.update(view)
  Wait.frames(function()
    UI.setValue("sbTurn", view.turn)
    UI.setValue("sbWind", view.wind)
    UI.setValue("sbInit", view.initiative)
    UI.setValue("sbActive", view.active)
    UI.setValue("sbLog", view.log)
    for id, enabled in pairs(view.buttons) do
      UI.setAttribute(id, "interactable", enabled and "true" or "false")
    end
  end, 1)
end

return M
