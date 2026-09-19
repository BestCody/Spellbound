-- Design regression tests; desktop mocks, not physical badge validation.
local Mock=dofile("tests/mock_badge.lua")
local passed,failed=0,0
local function test(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;print("PASS "..name) else failed=failed+1;print("FAIL "..name..": "..tostring(err)) end
end
local function has(b,text)
 for _,w in ipairs(b.widgets) do if not w.hide and (rawget(w,"text") or ""):find(text,1,true) then return true end end
 return false
end
local function light(b,i) local c=b.leds[i] or {0,0,0};return c[1]+c[2]+c[3] end
local function pair()
 local a=Mock.new({mac="AA:00:00:00:00:01"})
 local b=Mock.new({mac="AA:00:00:00:00:02"})
 local function relay(x,y) local q=x.sent;x.sent={};for _,m in ipairs(q) do y:receive(x.mac,m.payload) end end
 local function step(ms)
  for _=1,math.ceil(ms/20) do a:tick(20);b:tick(20);relay(a,b);relay(b,a) end
 end
 a:tap("A");b:tap("A");step(1000);a:tap("A");step(800);b:tap("A");step(1800)
 assert(a:state().phase=="duel" and b:state().phase=="duel")
 return a,b,step
end

test("home, practice and teach leave Bluetooth off",function()
 local b=Mock.new();assert(b.enables==0);b:tick(100)
 b:tap("DOWN");b:tap("A");b:tick(100);assert(b.enables==0)
 b:tap("B");b:tap("DOWN");b:tap("DOWN");b:tap("A");b:tap("A");b:tick(100)
 assert(b:state().phase=="teach" and b.enables==0)
end)
test("Find a duel enables radio once per foreground session",function()
 local b=Mock.new();b:tap("A");assert(b.enables==1 and b.receiver)
 b:tap("B");b:tap("A");assert(b.enables==1)
end)
test("failed radio startup leaves practice usable",function()
 local b=Mock.new({radio=false});b:tap("A");assert(b:state().phase=="home")
 b:tap("DOWN");b:tap("A");assert(b:state().phase=="practice")
end)
test("all four brightness levels include fully off",function()
 local b=Mock.new()
 for _,expected in ipairs({255,0,64,160}) do
  b:tap("AUX1");b:tick(100);assert(has(b,"LED brightness "..expected))
  if expected==0 then for i=1,6 do assert(light(b,i)==0) end end
 end
end)
test("off persists across HOME and reopening",function()
 local b=Mock.new();b:tap("AUX1");b:tap("AUX1");assert(b.store_writes==0)
 b.env.on_exit();assert(b.store.brightness==0)
 local c=Mock.new({store=b.store});for i=1,6 do assert(light(c,i)==0) end
end)
test("idle has no flash writes or diagnostic sensor polling",function()
 local b=Mock.new();for _=1,100 do b:tick(20) end
 assert(b.file_writes==0 and b.store_writes==0 and b.sensor_reads==0)
end)
test("one LED latch per scheduled frame, no catch-up burst",function()
 local b=Mock.new();local n=b.shows;b:tick(50);assert(b.shows==n+1)
 n=b.shows;b:tick(5000);assert(b.shows==n+1)
end)
test("notifications do not erase physical-button controls",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A");b:tap("START");b:tap("LEFT");b:tick(100)
 assert(has(b,"Fireball test cast") and has(b,"LEFT fire  UP shield  RIGHT mana"))
 assert(not has(b,"Fireball recognized"))
end)
test("unchanged duel vitals do not rewrite the four bars",function()
 local a,b,step=pair();step(100)
 local n=a.ui_writes;a:tick(100)
 -- Progress and projectile visibility still have three cheap native writes.
 assert(a.ui_writes-n<=3,"Unexpected full repaint")
end)
test("physical left LEDs 1/6/5 encode local health",function()
 local a,b,step=pair();a:state().match.hp[1]=33;step(200)
 assert(light(a,1)>0 and light(a,6)==0 and light(a,5)==0)
 assert(light(a,2)>0 and light(a,3)>0 and light(a,4)>0)
 -- Guest sees its own full health on the left, the host's low health on right.
 assert(light(b,1)>0 and light(b,6)>0 and light(b,5)>0)
 assert(light(b,2)>0 and light(b,3)==0 and light(b,4)==0)
end)
test("incoming warning stays visible while recording",function()
 local a,b,step=pair();a.api.submit(1);step(200);b:press("A");step(200)
 assert(has(b,"INCOMING! CAST SHIELD"));b:release("A")
end)
test("shielded incoming attack has distinct ready and blocked feedback",function()
 local a,b,step=pair();a.api.submit(1);step(200);b.api.submit(2);step(300)
 assert(has(b,"SHIELD READY TO BLOCK"));assert(not has(b,"INCOMING! CAST SHIELD"))
 step(1600);assert(b:state().view.hp[2]==100 and has(b,"BLOCKED"))
end)
test("pending guest action is not presented as a confirmed cast",function()
 local a,b,step=pair();b.api.submit(1);b:tick(100)
 assert(has(b,"CAST QUEUED - WAIT"));assert(not has(b,"Fireball cast"))
end)
test("new menu cancels stale result notes and LED effects",function()
 local a,b,step=pair();a:tap("B");a:tap("B");step(200)
 assert(a:state().phase=="result");a:tap("A");a:tick(100)
 assert(a:state().phase=="home" and a:state().note=="")
 for i=1,6 do assert(a.leds[i][3]>a.leds[i][1],"Idle should be violet, not result color") end
end)
test("all widget bounds remain within 320x240",function()
 local a,b,step=pair();a.api.submit(1);step(400)
 for _,c in ipairs({a,b}) do
  assert(#c.widgets==18)
  for _,w in ipairs(c.widgets) do assert(w.x>=0 and w.y>=0 and w.x+w.w<=320 and w.y+w.h<=240) end
 end
end)
print(string.format("\n%d design tests passed, %d failed",passed,failed))
if failed>0 then os.exit(1) end
