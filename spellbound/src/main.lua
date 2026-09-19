-- Tiny lifecycle bootstrap. Runtime features install into app state lazily.
local app,radio_ready
function on_enter(root)
  if not app then
    -- Native NimBLE/HCI needs its large buffers before the Lua application is
    -- compiled. Delaying this until Duel left enough total heap but not enough
    -- usable native allocation headroom on the ESP32-C3.
    radio_ready=badge.radio.enable()==true
    local loaded=require("app")
    app=type(loaded)=="table" and loaded or SPELLBOUND_APP
    SPELLBOUND_APP=nil
    badge.sys.gc_step()
  end
  app.enter(root,radio_ready)
end

function on_tick() if app then app.tick() end end
function on_button(button,kind) if app then app.button(button,kind) end end
function on_exit()
  if app then app.exit()
  else badge.radio.on_recv(nil);badge.radio.disable() end
end

-- TEST_EXPORTS_BEGIN
if SPELLBOUND_TEST then
  return function() return app.test_api() end
end
