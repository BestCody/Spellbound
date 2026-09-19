local app
function on_enter(root)
if not app then
local loaded=require("app")
app=type(loaded)=="table" and loaded or SPELLBOUND_APP
SPELLBOUND_APP=nil
badge.sys.gc_step()
end
app.enter(root)
end
function on_tick() if app then app.tick() end end
function on_button(button,kind) if app then app.button(button,kind) end end
function on_exit() if app then app.exit() end end
