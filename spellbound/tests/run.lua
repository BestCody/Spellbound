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
local function raw_window(api,fn,pre,motion,post)
 local out,total={},pre+motion+post
 for t=0,total,20 do
  local u
  if t<=pre then u=0 elseif t>=pre+motion then u=1 else u=(t-pre)/motion end
  out[#out+1]=api.raw_sample(t,fn(u))
 end
 return table.concat(out)
end
local function raw_variant(api,fn,motion,pre,post,amp,warp,noise,ox,oy,oz,impulse)
 local out,total={},pre+motion+post
 local bx,by,bz=fn(0)
 for t=0,total,20 do
  local p
  if t<=pre then p=0 elseif t>=pre+motion then p=1 else p=(t-pre)/motion end
  local u=p^(warp or 1)
  local x,y,z=fn(u)
  x=bx+(x-bx)*(amp or 1)+(ox or 0)+(noise or 0)*math.sin(t*0.071)
  y=by+(y-by)*(amp or 1)+(oy or 0)+(noise or 0)*math.sin(t*0.047+1)
  z=bz+(z-bz)*(amp or 1)+(oz or 0)+(noise or 0)*math.sin(t*0.031+2)
  if impulse and t==0 then x=x+impulse end
  out[#out+1]=api.raw_sample(t,x,y,z)
 end
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

test("strict documented API boot + 1-widget UI",function()
 local b=Mock.new();eq(#b.widgets,1);eq(b:state().phase,"home");b:tick(100)
 for _,w in ipairs(b.widgets) do assert(w.x>=0 and w.y>=0 and w.x+w.w<=320 and w.y+w.h<=240) end
end)
test("exit clears LEDs and disables radio",function()
 local b=Mock.new();b.env.on_exit();eq(b.disabled,true);eq(#b.leds,0);eq(b.receiver,nil)
end)
test("radio failure keeps Teach available",function()
 local b=Mock.new({radio=false});b:tap("A");eq(b:state().phase,"home")
 b:tap("DOWN");b:tap("A");eq(b:state().phase,"train_select")
end)
test("missing accelerometer rejects recording safely",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A");b:tap("A");b.accel=nil;b:tap("A");eq(b:state().capture,nil)
end)
test("energetic samples above 4g no longer invalidate the capture",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A");b:tap("A")
 b.accel={5200,0,1000};b:press("A");b:tick(20)
 assert(b:state().capture and not b:state().capture.bad)
 b:release("A")
end)
test("stationary movement rejected",function()
 local b=Mock.new();local sig=b.api.signature(raw(b.api,function() return 0,0,1000 end,1000));eq(sig,nil)
end)
test("small stationary jitter is ignored",function()
 local a=Mock.new().api
 local out={}
 for t=0,1200,20 do out[#out+1]=a.raw_sample(t,(t/20)%2==0 and 30 or -30,0,1000) end
 eq(a.signature(table.concat(out)),nil)
end)
test("gesture segmentation trims delayed start and late release",function()
 local a=Mock.new().api
 local base=assert(a.signature(raw(a,fire,1000)))
 local delayed=assert(a.signature(raw_window(a,fire,700,1000,700)))
 assert(a.distance(base,delayed)<0.45,"idle padding should not dominate gesture shape")
end)
test("gesture DTW tolerates faster and slower execution",function()
 local a=Mock.new().api
 local fast=assert(a.signature(raw(a,shield,600)))
 local slow=assert(a.signature(raw(a,shield,1800)))
 assert(a.distance(fast,slow)<0.45,"speed should not substantially change gesture shape")
end)
test("normalized derivative features tolerate amplitude, warp, noise, and offset",function()
 local a=Mock.new().api
 local base=assert(a.signature(raw(a,fire,1000)))
 local variant=assert(a.signature(raw_variant(a,fire,1200,500,400,1.5,1.4,20,120,-80,50,500)))
 assert(a.distance(base,variant)<0.50,"realistic execution variation should stay near the learned class")
end)
test("long A hold is allowed when active gesture itself is short",function()
 local a=Mock.new().api
 local sig,err,meta=a.signature(raw_window(a,fire,1500,1000,1500))
 assert(sig,err);assert(meta.active_ms<2800 and meta.hold_ms==4000)
end)
test("short movement rejected",function()
 local b=Mock.new();eq(b.api.signature(raw(b.api,fire,100)),nil)
end)
test("untrained motion does not cast",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,fire,1000)))
 local id,why=a.recognize(s,{{},{},{}})
 eq(id,nil);assert(why:find("Teach",1,true))
end)
test("template identical distance zero",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,fire,1000)));eq(a.distance(s,s),0)
end)
test("ambiguous template does not cast",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,fire,1000)));eq(a.recognize(s,{{s},{s},{}}),nil)
end)
test("trained template recognizes its assigned spell",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,shield,1000)));eq(a.recognize(s,{{s},{},{}},{0.5,nil,nil}),1)
end)
test("adaptive spell threshold learns training variance and accepts held-out variant",function()
 local a=Mock.new().api
 local s1=assert(a.signature(raw_variant(a,fire,950,100,80,0.9,0.9,10,0,0,0,0)))
 local s2=assert(a.signature(raw_variant(a,fire,1100,250,100,1.2,1.2,15,50,-30,20,0)))
 local s3=assert(a.signature(raw_variant(a,fire,1000,400,150,1.0,1.0,20,-40,20,30,300)))
 local thr=a.calibrate({s1,s2,s3});assert(thr>=0.34 and thr<=0.68)
 local fresh=assert(a.signature(raw_variant(a,fire,1250,500,300,1.35,1.3,20,80,-50,30,0)))
 local id,why=a.recognize(fresh,{{s1,s2,s3},{},{}},{thr,nil,nil})
 assert(id==1,why)
end)
test("relative ambiguity rule rejects indistinguishable spell classes",function()
 local a=Mock.new().api;local s=assert(a.signature(raw(a,fire,1000)))
 local id,why=a.recognize(s,{{s,s,s},{s,s,s},{}},{0.5,0.5,nil})
 assert(id==nil and why:find("Ambiguous",1,true))
end)
test("full on-badge teach flow: 3 examples + held-out repetition",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A");b:tap("A")
 eq(b:state().phase,"teach")
 for _=1,4 do b:record(fire,1000) end
 eq(b:state().phase,"train_select");eq(#b:state().models[1],3)
end)
test("taught gestures are session-only",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A");b:tap("A")
 for _=1,4 do b:record(fire,1000) end
 eq(#b:state().models[1],3);eq(b.file_writes,0)
 local c=Mock.new({files=b.files,store=b.store});eq(#c:state().models[1],0)
end)
test("overlong recording rejected",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A");b:tap("A");b:record(fire,4700)
 eq(b:state().capture,nil);assert(b:state().note:find("too long"))
end)
test("fire damage delayed and applies once",function()
 local a=Mock.new().api;local g=a.new_match(0);eq(a.apply(g,1,1,0,0),0)
 a.advance(g,1799);eq(g[3],100);a.advance(g,1800);eq(g[3],75);a.advance(g,5000);eq(g[3],75)
end)
test("shield blocks and is consumed",function()
 local a=Mock.new().api;local g=a.new_match(0);a.apply(g,1,1,0,0);a.apply(g,2,2,1,500)
 a.advance(g,1800);eq(g[3],100);eq(g[7],0)
end)
test("late shield cannot undo resolved attack",function()
 local a=Mock.new().api;local g=a.new_match(0);a.apply(g,1,1,0,0);a.apply(g,2,2,1,1801);eq(g[3],75)
end)
test("duplicate guest sequence cannot double spend",function()
 local a=Mock.new().api;local g=a.new_match(0);eq(a.apply(g,2,1,1,0),0);eq(a.apply(g,2,1,1,1),5);eq(g[5],45)
end)
test("out-of-order command cannot advance sequence",function()
 local a=Mock.new().api;local g=a.new_match(0);eq(a.apply(g,2,1,2,0),5);eq(g[16],0)
end)
test("mana and cooldown rejected with sequenced response",function()
 local a=Mock.new().api;local g=a.new_match(0)
 a.apply(g,2,2,1,0);eq(a.apply(g,2,2,2,100),2);eq(g[16],2)
 g[5]=0;eq(a.apply(g,2,1,3,5000),1);eq(g[16],3)
end)
test("recharge capped and cooldown enforced",function()
 local a=Mock.new().api;local g=a.new_match(0);eq(a.apply(g,1,3,0,0),0);eq(g[4],100)
 eq(a.apply(g,1,3,0,100),2)
end)
test("simultaneous lethal attacks produce draw",function()
 local a=Mock.new().api;local g=a.new_match(0);g[2],g[3]=25,25;a.apply(g,1,1,0,0);a.apply(g,2,1,1,0)
 a.advance(g,1800);eq(g[1],3)
end)
test("host and guest surrender semantics",function()
 local a=Mock.new().api;local g=a.new_match(0);a.apply(g,1,4,0,0);eq(g[1],2)
 g=a.new_match(0);a.apply(g,2,4,1,0);eq(g[1],1)
end)
test("state is 22 bytes and reconstructs relative timers",function()
 local a=Mock.new().api;local g=a.new_match(0);a.apply(g,1,1,0,100)
 local s=a.pack_state(g,100);eq(#s,22);local c=assert(a.unpack_state(s,999000))
 eq(c[9],1000800);eq(c[4],45)
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
 eq(a:state().match[2],75);eq(b:state().view[2],75);eq(b:state().pending,nil)
end)
test("host fire and guest shield synchronizes",function()
 local a,b,step=setup_pair();a.api.submit(1);step(400);b.api.submit(2);step(2000)
 eq(a:state().match[3],100);eq(b:state().view[3],100)
end)
test("duplicate/reordered packets do not duplicate damage",function()
 local a,b,step=setup_pair({duplicate=true,delay=function(n) return n%4*40 end})
 b.api.submit(1);step(2600);eq(a:state().match[2],75);eq(a:state().match[5],45)
end)
test("periodic packet loss is recovered",function()
 local a,b,step=setup_pair({drop=function(n) return n%4==0 end,duplicate=true})
 b.api.submit(1);step(3000);eq(a:state().match[2],75);eq(b:state().view[2],75)
end)
test("unrelated session and wrong sender ignored",function()
 local a,b,step=setup_pair();local before=a:state().match[5]
 a:receive("AA:00:00:00:00:03","SB1|C|"..a:state().sid.."|0001|F")
 a:receive(b.mac,"SB1|C|87654321|0001|F");step(100)
 eq(a:state().match[5],before)
end)
test("guest clock offset does not break handshake or attacks",function()
 local a,b,step=setup_pair({offset=900000});b.api.submit(1);step(2600);eq(a:state().match[2],75)
end)
test("disconnect aborts instead of continuing stale match",function()
 local a,b,step=setup_pair();for _=1,310 do a:tick(20) end
 eq(a:state().phase,"result");eq(a:state().match[1],4)
end)
test("random incoming payloads cannot crash app",function()
 local a,b,step=setup_pair();math.randomseed(42)
 for _=1,1000 do
  local bytes={};for j=1,math.random(1,60) do bytes[j]=string.char(math.random(0,255)) end
  a:receive(b.mac,table.concat(bytes))
 end
 eq(a:state().match[2],100)
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
 eq(b:state().phase,"result");eq(b:state().view[1],4)
 local packet="SB1|T|"..b:state().sid.."|FFFF|"..a.api.pack_state(a:state().match,a.now)
 b:receive(a.mac,packet);eq(b:state().view[1],4)
end)
test("NaN accelerometer safely rejects recording",function()
 local b=Mock.new();b:tap("DOWN");b:tap("A");b:tap("A");b.accel={0/0,0,1000};b:tap("A");b:tick(100);eq(b:state().capture,nil)
end)
test("trained gesture travels through the real duel action path",function()
 local a,b,step=setup_pair()
 local s=assert(b.api.signature(raw(b.api,fire,1000)))
 b:state().models[1][1]=s;b:state().models[1][2]=s;b:state().models[1][3]=s
 b.accel={fire(0)};b:press("A")
 for t=20,1000,20 do b.accel={fire(t/1000)};step(20) end
 b:release("A");step(2600)
 eq(a:state().match[2],75);eq(b:state().view[2],75)
end)
test("stationary capture never spends multiplayer mana",function()
 local a,b,step=setup_pair();b:press("A");step(800);b:release("A");step(500)
 eq(a:state().match[5],75);eq(a:state().match[2],100)
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
