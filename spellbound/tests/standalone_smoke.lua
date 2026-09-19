-- Boots the generated single-file IDE import with no module files present.
local Mock=dofile("tests/mock_badge.lua")
local f=assert(io.open("dist/Spellbound-install.lua","rb"))
local all=f:read("*a");f:close()
local marker="]==]"
local at=assert(all:find(marker,1,true),"missing badge-app header terminator")
local body=all:sub(at+#marker)
assert(not body:find("require%s*%("),"standalone file still requires modules")
assert(not body:find("model_codec",1,true),"standalone file still contains model codec")

local b=Mock.new({source=body,production=true})
assert(b.api==nil,"Test hooks accidentally shipped")
for _=1,20 do b:tick() end

b:tap("DOWN");b:tap("A");b:tap("A")
local function motion(t) return 1400*math.sin(t*2*math.pi),0,1000 end
for _=1,4 do b:record(motion,1000) end
b:tick(100)
local learned=false
for _,w in ipairs(b.widgets) do
  if (rawget(w,"text") or ""):find("Fireball [learned]",1,true) then learned=true end
end
assert(learned,"Standalone training did not become active")
assert(b.file_writes==0,"Standalone session training must not persist model files")
b.env.on_exit();assert(b.disabled)
print("PASS standalone import boot, session training, no model persistence, cleanup")
