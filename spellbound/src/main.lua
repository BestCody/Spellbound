-- Tiny lifecycle bootstrap. Runtime features install into app state lazily.
local app
local function get_app()
  if app then return app end
  local loaded=require("app")
  local candidate=type(loaded)=="table" and loaded or SPELLBOUND_APP
  if type(candidate)~="table" or type(candidate.enter)~="function"
    or type(candidate.tick)~="function" or type(candidate.button)~="function"
    or type(candidate.exit)~="function" then
    error("app.lua export missing/corrupt (require returned "..type(loaded)..")")
  end
  if type(loaded)~="table" then
    badge.sys.log("Spellbound app export fallback: require returned "..type(loaded))
  end
  app=candidate
  SPELLBOUND_APP=nil
  badge.sys.gc_step()
  return app
end

function on_enter(root) get_app().enter(root) end
function on_tick() if app then app.tick() end end
function on_button(button,kind) if app then app.button(button,kind) end end
function on_exit() if app then app.exit() end end

-- TEST_EXPORTS_BEGIN
if SPELLBOUND_TEST then
  return function() return get_app().test_api() end
end
