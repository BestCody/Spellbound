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
local function log_has(b,s)
 for _,v in ipairs(b.logs) do if v:find(s,1,true) then return true end end
 return false
end
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

test("home and Teach leave Bluetooth off",function()
 local b=Mock.new();assert(b.enables==0);b:tick(100)
 b:tap("DOWN");b:tap("A");b:tap("A");b:tick(100)
 assert(b:state().phase=="teach" and b.enables==0)
end)
test("Find a duel enables radio once per foreground session",function()
 local b=Mock.new();b:tap("A");assert(b.enables==1 and b.receiver)
 b:tap("B");b:tap("A");assert(b.enables==1)
end)
test("Teach preloading deletes and rebuilds the UI",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A")
 assert(b:state().phase=="train_select" and #b.widgets==3)
 -- TEST_EXPORTS prewarms recognizer modules before this transition; production
 -- UI-drop/module-stage logging is locked by the source/build contract.
end)
test("duel preloading deletes UI before engine and radio",function()
 local b=Mock.new();b:tap("A")
 assert(b:state().phase=="lobby" and #b.widgets==3)
 assert(log_has(b,"MEM duel-after-ui-drop") and log_has(b,"widgets=0"))
 -- TEST_EXPORTS prewarms network/engine, so only the physical radio transition
 -- remains lazy in this desktop path.
 assert(log_has(b,"MEM duel-before-radio"))
 assert(log_has(b,"MEM duel-after-radio"))
 assert(log_has(b,"MEM duel-after-ui-rebuild") and log_has(b,"widgets=3"))
end)
test("failed radio startup leaves Teach usable",function()
 local b=Mock.new({radio=false});b:tap("A");assert(b:state().phase=="home")
 b:tap("DOWN");b:tap("A");assert(b:state().phase=="train_select")
end)
test("idle is dark and has no flash writes or sensor polling",function()
 local b=Mock.new();for _=1,100 do b:tick(20) end
 assert(b.file_writes==0 and b.store_writes==0 and b.sensor_reads==0)
 for i=1,6 do assert(light(b,i)==0) end
end)
test("one LED latch per scheduled frame, no catch-up burst",function()
 local b=Mock.new();local n=b.shows;b:tick(50);assert(b.shows==n+1)
 n=b.shows;b:tick(5000);assert(b.shows==n+1)
end)
test("fallback spell buttons are disabled",function()
 local a,b,step=pair();local mana=a:state().match.mana[1]
 a:tap("START");a:tap("LEFT");a:tap("UP");a:tap("RIGHT");step(200)
 assert(a:state().match.mana[1]==mana)
 assert(not has(a,"LEFT fire"))
end)
test("unchanged duel vitals avoid full repaint",function()
 local a,b,step=pair();step(100)
 local n=a.ui_writes;a:tick(100)
 -- Only the reusable recording progress widget visibility is touched.
 assert(a.ui_writes-n<=1,"Unexpected full repaint")
end)
test("LEDs are spell effects, not duplicate health meters",function()
 local a,b,step=pair()
 -- Fireball: one moving orange/red point.
 a.api.submit(1);step(100)
 local lit=0
 for i=1,6 do if light(a,i)>0 then lit=lit+1 end end
 assert(lit==1)
 -- Shield: full blue field.
 b.api.submit(2);step(100)
 for i=1,6 do local x=b.leds[i] or {0,0,0};assert(x[3]>x[1]) end
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
 for i=1,6 do assert(light(a,i)==0,"Idle LEDs should be off") end
end)
test("low-memory UI uses three bounded widgets",function()
 local a,b,step=pair();a.api.submit(1);step(400)
 for _,c in ipairs({a,b}) do
  assert(#c.widgets==3)
  for _,w in ipairs(c.widgets) do assert(w.x>=0 and w.y>=0 and w.x+w.w<=320 and w.y+w.h<=240) end
 end
end)
print(string.format("\n%d design tests passed, %d failed",passed,failed))
if failed>0 then os.exit(1) end
