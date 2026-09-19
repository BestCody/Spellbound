-- Run from repository root: lua tests/run.lua (Lua 5.3/5.4 or texlua).
local Mock=dofile("tests/mock_badge.lua")
local passed,failed=0,0
local function eq(a,b,msg) assert(a==b,(msg or "mismatch")..": expected "..tostring(b)..", got "..tostring(a)) end
local function test(name,fn)
 local ok,err=pcall(fn)
 if ok then passed=passed+1;print("PASS "..name) else failed=failed+1;print("FAIL "..name.."\n  "..tostring(err)) end
end
local function fire(t) return 1400*math.sin(t*2*math.pi),0,1000 end
local function recharge(t) return 1200*math.sin(t*4*math.pi),0,1000 end
local function shield(t) local a=math.min(1,t/0.7)*math.pi/2;return 0,1000*math.sin(a),1000*math.cos(a) end
local function raw(api,fn,duration)
 local out={}
 for t=0,duration,20 do out[#out+1]=api.raw_sample(t,fn(t/duration)) end
 return table.concat(out)
end
local function setup_pair(opts)
 opts=opts or {}
 local a=Mock.new({mac="AA:00:00:00:00:01"})
 local b=Mock.new({mac="AA:00:00:00:00:02",offset=opts.offset or 0})
 local traffic=0
 local wire={}
 local function enqueue(src,dst)
  local queue=src.sent;src.sent={}
  for _,m in ipairs(queue) do
   traffic=traffic+1
   if not opts.drop or not opts.drop(traffic,m.payload,src) then
    local delay=opts.delay and opts.delay(traffic) or 0
    wire[#wire+1]={src=src,dst=dst,p=m.payload,due=a.now+delay}
    if opts.duplicate and traffic%3==0 then wire[#wire+1]={src=src,dst=dst,p=m.payload,due=a.now+delay+40} end
   end
  end
 end
 local function step(ms)
  for _=1,math.ceil(ms/20) do
   a:tick(20);b:tick(20)
   enqueue(a,b);enqueue(b,a)
   local drained={[a]=0,[b]=0}
   for i=#wire,1,-1 do
    local m=wire[i]
    if m.due<=a.now and drained[m.dst]<4 then
     m.dst:receive(m.src.mac,m.p);drained[m.dst]=drained[m.dst]+1;table.remove(wire,i)
    end
   end
  end
 end
 a:tap("A");b:tap("A");step(1000)
 eq(a:state().phase,"lobby");assert(#a:state().peers>0)
 a:tap("A");step(800)
 eq(b:state().phase,"offer")
 b:tap("A");step(1800)
 eq(a:state().phase,"duel");eq(b:state().phase,"duel")
 return a,b,step
end

test("strict documented API boot + 20-widget UI",function()
 local b=Mock.new();assert(#b.widgets<=20);eq(b:state().phase,"home");b:tick(100)
 for _,w in ipairs(b.widgets) do assert(w.x>=0 and w.y>=0 and w.x+w.w<=320 and w.y+w.h<=240) end
end)
test("exit clears LEDs and disables radio",function()
 local b=Mock.new();b.env.on_exit();eq(b.disabled,true);eq(#b.leds,0);eq(b.receiver,nil)
end)
test("radio failure keeps practice available",function()
 local b=Mock.new({radio=false});b:tap("A");eq(b:state().phase,"home")
 b:tap("DOWN");b:tap("A");eq(b:state().phase,"practice")
end)
test("missing accelerometer rejects recording safely",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A");b.accel=nil;b:tap("A");eq(b:state().capture,nil)
end)
test("stationary movement rejected",function()
 local b=Mock.new();local sig=b.api.signature(raw(b.api,function() return 0,0,1000 end,1000));eq(sig,nil)
end)
test("short movement rejected",function()
 local b=Mock.new();eq(b.api.signature(raw(b.api,fire,100)),nil)
end)
test("preset fire synthetic fixture",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,fire,1000)));eq(a.recognize(s),1)
end)
test("preset shield synthetic fixture",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,shield,1000)));eq(a.recognize(s),2)
end)
test("preset recharge synthetic fixture",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,recharge,1200)));eq(a.recognize(s),3)
end)
test("template identical distance zero",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,fire,1000)));eq(a.distance(s,s),0)
end)
test("ambiguous template does not cast",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,fire,1000)));eq(a.recognize(s,{{s},{s},{}}),nil)
end)
test("personal template overrides preset for that spell",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,shield,1000)));eq(a.recognize(s,{{s},{},{}}),1)
end)
test("binary model journal roundtrip",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,fire,1000)))
 local bytes=a.encode_models({{s,s,s},{},{}});local m=assert(a.decode_models(bytes));eq(m[1][3],s)
end)
test("corrupt model rejected",function()
 local a=Mock.new().api;local bytes=a.encode_models({{},{},{}})
 eq(a.decode_models(bytes:sub(1,-2).."Z"),nil);eq(a.decode_models("SBG1"),nil)
end)
test("failed save preserves old active model",function()
 local b=Mock.new();local s=assert(b.api.signature(raw(b.api,fire,1000)))
 b.write_fail=true;eq(b.api.save_models({{s,s,s},{},{}}),false);eq(#b:state().models[1],0)
end)
test("save survives restart",function()
 local b=Mock.new();local s=assert(b.api.signature(raw(b.api,fire,1000)))
 assert(b.api.save_models({{s,s,s},{},{}}))
 local c=Mock.new({files=b.files,store=b.store});eq(c:state().models[1][1],s)
end)
test("corrupt active journal falls back to older slot",function()
 local b=Mock.new();local s=assert(b.api.signature(raw(b.api,fire,1000)))
 assert(b.api.save_models({{s,s,s},{},{}}));assert(b.api.save_models({{s,s,s},{s,s,s},{}}))
 b.files["appdata/gest0.dat"]="CORRUPT"
 local c=Mock.new({files=b.files,store=b.store});eq(#c:state().models[1],3);eq(#c:state().models[2],0)
end)
test("full on-badge teach flow: 3 examples + held-out repetition",function()
 local b=Mock.new();b:tap("DOWN");b:tap("DOWN");b:tap("A");b:tap("A")
 eq(b:state().phase,"teach")
 for _=1,4 do b:record(fire,1000) end
 eq(b:state().phase,"train_select");eq(#b:state().models[1],3)
end)
test("overlong recording rejected",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A");b:record(fire,2600)
 eq(b:state().capture,nil);assert(b:state().note:find("too long"))
end)
test("fire damage delayed and applies once",function()
 local a=Mock.new().api;local g=a.new_match(0);eq(a.apply(g,1,1,0,0),0)
 a.advance(g,1799);eq(g.hp[2],100);a.advance(g,1800);eq(g.hp[2],75);a.advance(g,5000);eq(g.hp[2],75)
end)
test("shield blocks and is consumed",function()
 local a=Mock.new().api;local g=a.new_match(0);a.apply(g,1,1,0,0);a.apply(g,2,2,1,500)
 a.advance(g,1800);eq(g.hp[2],100);eq(g.shield[2],0)
end)
test("late shield cannot undo resolved attack",function()
 local a=Mock.new().api;local g=a.new_match(0);a.apply(g,1,1,0,0);a.apply(g,2,2,1,1801);eq(g.hp[2],75)
end)
test("duplicate guest sequence cannot double spend",function()
 local a=Mock.new().api;local g=a.new_match(0);eq(a.apply(g,2,1,1,0),0);eq(a.apply(g,2,1,1,1),5);eq(g.mana[2],45)
end)
test("out-of-order command cannot advance sequence",function()
 local a=Mock.new().api;local g=a.new_match(0);eq(a.apply(g,2,1,2,0),5);eq(g.ack,0)
end)
test("mana and cooldown rejected with sequenced response",function()
 local a=Mock.new().api;local g=a.new_match(0)
 a.apply(g,2,2,1,0);eq(a.apply(g,2,2,2,100),2);eq(g.ack,2)
 g.mana[2]=0;eq(a.apply(g,2,1,3,5000),1);eq(g.ack,3)
end)
test("recharge capped and cooldown enforced",function()
 local a=Mock.new().api;local g=a.new_match(0);eq(a.apply(g,1,3,0,0),0);eq(g.mana[1],100)
 eq(a.apply(g,1,3,0,100),2)
end)
test("simultaneous lethal attacks produce draw",function()
 local a=Mock.new().api;local g=a.new_match(0);g.hp={25,25};a.apply(g,1,1,0,0);a.apply(g,2,1,1,0)
 a.advance(g,1800);eq(g.result,3)
end)
test("host and guest surrender semantics",function()
 local a=Mock.new().api;local g=a.new_match(0);a.apply(g,1,4,0,0);eq(g.result,2)
 g=a.new_match(0);a.apply(g,2,4,1,0);eq(g.result,1)
end)
test("state is 22 bytes and reconstructs relative timers",function()
 local a=Mock.new().api;local g=a.new_match(0);a.apply(g,1,1,0,100)
 local s=a.pack_state(g,100);eq(#s,22);local c=assert(a.unpack_state(s,999000))
 eq(c.incoming[2],1000800);eq(c.mana[1],45)
end)
test("state parser rejects invalid ranges and shape",function()
 local a=Mock.new().api;eq(a.unpack_state(string.rep("F",22),0),nil);eq(a.unpack_state("0",0),nil)
end)
test("packet parser rejects unrelated/malformed frames",function()
 local a=Mock.new().api
 for _,s in ipairs({"ping","SB1|I|1234|AABBCCDD0011","SB1|T|12345678|x"..string.rep("x",50),"SB1|K|12345678|"}) do eq(a.split_packet(s),nil) end
end)
test("two-badge handshake + guest fire reaches host once",function()
 local a,b,step=setup_pair();b.api.submit(1);step(2400)
 eq(a:state().match.hp[1],75);eq(b:state().view.hp[1],75);eq(b:state().pending,nil)
end)
test("host fire and guest shield synchronizes",function()
 local a,b,step=setup_pair();a.api.submit(1);step(400);b.api.submit(2);step(2000)
 eq(a:state().match.hp[2],100);eq(b:state().view.hp[2],100)
end)
test("duplicate/reordered packets do not duplicate damage",function()
 local a,b,step=setup_pair({duplicate=true,delay=function(n) return n%4*40 end})
 b.api.submit(1);step(2600);eq(a:state().match.hp[1],75);eq(a:state().match.mana[2],45)
end)
test("periodic packet loss is recovered",function()
 local a,b,step=setup_pair({drop=function(n) return n%4==0 end,duplicate=true})
 b.api.submit(1);step(3000);eq(a:state().match.hp[1],75);eq(b:state().view.hp[1],75)
end)
test("unrelated session and wrong sender ignored",function()
 local a,b,step=setup_pair();local before=a:state().match.mana[2]
 a:receive("AA:00:00:00:00:03","SB1|C|"..a:state().sid.."|0001|F")
 a:receive(b.mac,"SB1|C|87654321|0001|F");step(100)
 eq(a:state().match.mana[2],before)
end)
test("guest clock offset does not break handshake or attacks",function()
 local a,b,step=setup_pair({offset=900000});b.api.submit(1);step(2600);eq(a:state().match.hp[1],75)
end)
test("disconnect aborts instead of continuing stale match",function()
 local a,b,step=setup_pair();for _=1,310 do a:tick(20) end
 eq(a:state().phase,"result");eq(a:state().match.result,4)
end)
test("random incoming payloads cannot crash app",function()
 local a,b,step=setup_pair();math.randomseed(42)
 for _=1,1000 do
  local bytes={};for j=1,math.random(1,60) do bytes[j]=string.char(math.random(0,255)) end
  a:receive(b.mac,table.concat(bytes))
 end
 eq(a:state().match.hp[1],100)
end)
test("ten repeated matches do not accumulate UI widgets",function()
 local a,b,step=setup_pair();local n=#a.widgets
 for i=1,10 do
  a.api.submit(4);step(300);a:tap("A");b:tap("A");eq(a:state().phase,"home");eq(#a.widgets,n)
  if i<10 then a:tap("A");b:tap("A");step(1000);a:tap("A");step(800);b:tap("A");step(1800) end
 end
end)
test("local timeout remains terminal despite late live state",function()
 local a,b,step=setup_pair()
 for _=1,310 do b:tick(20) end
 eq(b:state().phase,"result");eq(b:state().view.result,4)
 local packet="SB1|T|"..b:state().sid.."|FFFF|"..a.api.pack_state(a:state().match,a.now)
 b:receive(a.mac,packet);eq(b:state().view.result,4)
end)
test("NaN accelerometer safely rejects recording",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A");b.accel={0/0,0,1000};b:tap("A");b:tick(100);eq(b:state().capture,nil)
end)
test("recognized gesture travels through the real duel action path",function()
 local a,b,step=setup_pair()
 b.accel={fire(0)};b:press("A")
 for t=20,1000,20 do b.accel={fire(t/1000)};step(20) end
 b:release("A");step(2600)
 eq(a:state().match.hp[1],75);eq(b:state().view.hp[1],75)
end)
test("stationary capture never spends multiplayer mana",function()
 local a,b,step=setup_pair();b:press("A");step(800);b:release("A");step(500)
 eq(a:state().match.mana[2],75);eq(a:state().match.hp[1],100)
end)
test("declined invitation is not immediately shown again",function()
 local b=Mock.new({mac="AA:00:00:00:00:02"});b:tap("A")
 local p="SB1|I|12345678|AA0000000002"
 b:receive("AA:00:00:00:00:01",p);eq(b:state().phase,"offer");b:tap("B")
 b:receive("AA:00:00:00:00:01",p);eq(b:state().phase,"lobby")
end)
test("host cancellation closes an unaccepted invitation",function()
 local b=Mock.new({mac="AA:00:00:00:00:02"});b:tap("A")
 b:receive("AA:00:00:00:00:01","SB1|I|12345678|AA0000000002");eq(b:state().phase,"offer")
 b:receive("AA:00:00:00:00:01","SB1|Q|12345678");eq(b:state().phase,"lobby")
end)
print(string.format("\n%d passed, %d failed",passed,failed))
if failed>0 then os.exit(1) end
