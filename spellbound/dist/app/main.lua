-- Spellbound lifecycle bootstrap. Runtime features live in small lazy modules.
local app
local function get_app()
  if app then return app end
  app=require("app")
  if package and package.loaded then package.loaded["app"]=nil end
  badge.sys.gc_step()
  return app
end

function on_enter(root) get_app().enter(root) end
function on_tick() if app then app.tick() end end
function on_button(button,kind) if app then app.button(button,kind) end end
function on_exit() if app then app.exit() end end
