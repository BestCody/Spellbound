-- Boots the generated single-file IDE import with no module files present.
local Mock=dofile("tests/mock_badge.lua")
local f=assert(io.open("dist/Spellbound-install.lua","rb"))
local all=f:read("*a");f:close()
local marker="]==]"
local at=assert(all:find(marker,1,true),"missing badge-app header terminator")
local body=all:sub(at+#marker)
assert(not body:find("require%s*%("),"standalone file still requires modules")

local b=Mock.new({source=body,production=true})
assert(b.api==nil,"Test hooks accidentally shipped")
for _=1,20 do b:tick() end
b:tap("DOWN");b:tap("A")
b:tap("START");b:tap("LEFT");b:tick(100)
local seen=false
for _,w in ipairs(b.widgets) do
  if rawget(w,"text")=="Fireball test cast" then seen=true end
end
assert(seen,"Standalone button-mode practice did not execute")

b:tap("B");b:tap("DOWN");b:tap("DOWN");b:tap("A");b:tap("A")
local function motion(t) return 1400*math.sin(t*2*math.pi),0,1000 end
for _=1,4 do b:record(motion,1000) end
assert(b.files["appdata/gest1.dat"],"Standalone training did not persist")
b.env.on_exit();assert(b.disabled)
print("PASS standalone import boot, controls, training, persistence, cleanup")
