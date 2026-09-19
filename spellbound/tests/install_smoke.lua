-- Exercises actual generated production files, with test exports removed.
local Mock=dofile("tests/mock_badge.lua")
local b=Mock.new({path="dist/app",production=true})
assert(b.api==nil,"Test hooks accidentally shipped")
for _=1,20 do b:tick() end

-- Teach Fireball: Home -> Teach -> Fireball, then 3 examples + held-out test.
b:tap("DOWN");b:tap("A");b:tap("A")
local function motion(t) return 1400*math.sin(t*2*math.pi),0,1000 end
for _=1,4 do b:record(motion,1000) end
local learned=false
for _,w in ipairs(b.widgets) do
  if (rawget(w,"text") or ""):find("Fireball [learned]",1,true) then learned=true end
end
assert(learned,"Production training did not become active for this session")
assert(b.file_writes==0,"Session-only gestures must not write model files")

b.env.on_exit();assert(b.disabled)
print("PASS packaged production boot, session training, no model persistence, cleanup")
