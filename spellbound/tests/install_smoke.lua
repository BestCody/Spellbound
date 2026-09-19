-- Exercises actual generated production files, with test exports removed.
local Mock=dofile("tests/mock_badge.lua")
local b=Mock.new({path="dist/app",production=true})
assert(b.api==nil,"Test hooks accidentally shipped")
for _=1,20 do b:tick() end

-- Teach Fireball: Home -> Teach -> Fireball, then 1 example + held-out test.
b:tap("DOWN");b:tap("A");b:tap("A")
local function motion(t) return 1400*math.sin(t*2*math.pi),0,1000 end
for _=1,2 do b:record(motion,1000) end
b:tick(100)
local learned=false
for _,w in ipairs(b.widgets) do
  if (rawget(w,"text") or ""):find("Fireball [learned]",1,true) then learned=true end
end
assert(learned,"Production training did not become active for this session")
assert(b.file_writes==0,"Session-only gestures must not write model files")

-- Exercise the generated files through discovery, deferred engine loading, and a cast.
b:tap("B")
local c=Mock.new({path="dist/app",production=true,mac="AA:00:00:00:00:02"})
local function has(x,s)
 for _,w in ipairs(x.widgets) do if (rawget(w,"text") or ""):find(s,1,true) then return true end end
 return false
end
local function relay(x,y)
 local q=x.sent;x.sent={}
 for _,m in ipairs(q) do y:receive(x.mac,m.payload) end
end
local function step(ms)
 for _=1,math.ceil(ms/20) do b:tick(20);c:tick(20);relay(b,c);relay(c,b) end
end
b:tap("A");c:tap("A");step(1000);b:tap("A");step(800);c:tap("A");step(1800)
assert(has(b,"READY TO CAST") and has(c,"READY TO CAST"),"Production pairing failed")
b:record(motion,1000);step(2400)
assert(has(b,"FOE HP 75") and has(c,"YOU HP 75"),"Production gesture cast failed")

b.env.on_exit();c.env.on_exit();assert(b.disabled and c.disabled)
print("PASS packaged production teach, two-badge duel, cast, no persistence, cleanup")
