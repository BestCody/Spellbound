local app,radio_ready
function on_enter(root)
if not app then
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
