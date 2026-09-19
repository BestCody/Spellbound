-- Exercises actual generated production files, with test exports removed.
local Mock=dofile("tests/mock_badge.lua")
local b=Mock.new({path="dist/app",production=true})
assert(b.api==nil,"Test hooks accidentally shipped")
for _=1,20 do b:tick() end
b:tap("DOWN");b:tap("A");b:tap("START");b:tap("LEFT");b:tick(100)
local recognized=false
for _,w in ipairs(b.widgets) do if rawget(w,"text")=="Fireball test cast" then recognized=true end end
assert(recognized,"Production button mode did not show Fireball")
b:tap("B");b:tap("DOWN");b:tap("DOWN");b:tap("A");b:tap("A")
local function motion(t) return 1400*math.sin(t*2*math.pi),0,1000 end
for _=1,4 do b:record(motion,1000) end
assert(b.files["appdata/gest1.dat"],"Production training did not persist")
b.env.on_exit();assert(b.disabled)
print("PASS packaged production boot, controls, training, persistence, cleanup")
