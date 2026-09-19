--[==[badge-app
slug=spellbound
name=Spellbound
icon=SB
api=2
heap_kb=96
wake_lock=1
version=0.2.0
]==]

local function __load_gesture()
local floor,min,max,abs=math.floor,math.min,math.max,math.abs
local SB={nodes=16,max_capture=2400}
local function clamp(v,a,b) return min(b,max(a,v)) end
local function round(v) return floor(v+0.5) end
local function raw_sample(t,x,y,z)
  return string.char(floor(t/256), t%256,
    clamp(round(x/32)+128,1,255), clamp(round(y/32)+128,1,255),
    clamp(round(z/32)+128,1,255))
end
local function unpack_sample(s,i)
  local a,b,x,y,z = s:byte(i,i+4)
  return a*256+b,(x-128)*32,(y-128)*32,(z-128)*32
end
local function signature(raw)
  local n = #raw/5
  if n < 8 or n ~= floor(n) then return nil,"Too few motion samples" end
  local duration = select(1,unpack_sample(raw,#raw-4))
  if duration < 300 or duration > SB.max_capture then return nil,"Use a 0.3-2.4s movement" end
  local _,bx,by,bz = unpack_sample(raw,1)
  local out, j, movement = {}, 1, 0
  for k=0,SB.nodes-1 do
    local target = duration*k/(SB.nodes-1)
    while j < n-1 and select(1,unpack_sample(raw,j*5+1)) < target do j=j+1 end
    local t,x,y,z = unpack_sample(raw,(j-1)*5+1)
    local u,a,b,c = unpack_sample(raw,j*5+1)
    if u <= t then return nil,"Invalid sample timing" end
    local f=clamp((target-t)/(u-t),0,1)
    local dx,dy,dz = x+(a-x)*f-bx, y+(b-y)*f-by, z+(c-z)*f-bz
    movement=max(movement,math.sqrt(dx*dx+dy*dy+dz*dz))
    out[#out+1]=string.char(clamp(round(dx/50)+128,1,255),
      clamp(round(dy/50)+128,1,255),clamp(round(dz/50)+128,1,255))
  end
  if movement < 260 then return nil,"No clear movement" end
  return table.concat(out),nil,duration
end
local function distance(a,b)
  if #a ~= 48 or #b ~= 48 then return 99 end
  local sum=0
  for i=1,48 do local d=(a:byte(i)-b:byte(i))*0.05; sum=sum+d*d end
  return math.sqrt(sum/48)
end
local function nearest(sig, model)
  local first,second,id=99,99,nil
  for s=1,3 do
    local d=99
    for _,t in ipairs(model[s]) do d=min(d,distance(sig,t)) end
    if d<first then second,first,id=first,d,s elseif d<second then second=d end
  end
  return id,first,second
end
local function preset(sig)
  local peak,tail,axis,range=0,0,1,0
  for a=1,3 do
    local lo,hi=0,0
    for i=a,48,3 do local v=(sig:byte(i)-128)*0.05;lo=min(lo,v);hi=max(hi,v) end
    if hi-lo>range then range,axis=hi-lo,a end
  end
  local flips,last=0,0
  for k=0,15 do
    local i=k*3+1
    local x,y,z=(sig:byte(i)-128)*0.05,(sig:byte(i+1)-128)*0.05,(sig:byte(i+2)-128)*0.05
    peak=max(peak,math.sqrt(x*x+y*y+z*z))
    local v=(sig:byte(k*3+axis)-128)*0.05
    local sign=v>0.28 and 1 or (v< -0.28 and -1 or 0)
    if sign~=0 then if last~=0 and sign~=last then flips=flips+1 end;last=sign end
  end
  local e1,e2,e3=(sig:byte(46)-128)*0.05,(sig:byte(47)-128)*0.05,(sig:byte(48)-128)*0.05
  local endpoint=math.sqrt(e1*e1+e2*e2+e3*e3)
  for i=40,45 do tail=max(tail,abs(sig:byte(i)-sig:byte(46+(i-40)%3))*0.05) end
  if peak>3.4 then return nil end
  if flips>=3 and flips<=6 and range>0.85 and endpoint<0.65 then return 3 end
  if endpoint>0.8 and endpoint<2.15 and tail<0.25 and flips<=1 then return 2 end
  if flips==1 and range>1.2 and endpoint<0.50 then return 1 end
end
local function recognize(sig, model)
  model=model or {{},{},{}}
  local id,d,runner=nearest(sig,model)
  if id and d<=0.42 then
    if runner-d<0.09 or d>runner*0.78 then return nil,"Ambiguous - try again",d end
    return id,"Learned gesture",d
  end
  local p=preset(sig)
  if p and #model[p]==0 then return p,"Preset (calibrate for accuracy)",d end
  return nil,"Fizzle - no clear match",d
end

return raw_sample,signature,distance,recognize
end
local function __load_engine()
local min,max=math.min,math.max
local costs,cooldowns={30,25,0},{2400,2400,3000}
local function clamp(v,a,b) return min(b,max(a,v)) end
local function new_match(now)
  return {hp={100,100},mana={75,75},shield={0,0},incoming={0,0},
    cd={{0,0,0},{0,0,0}},result=0,ack=0,reply=0,started=now}
end
local function advance(g,now)
  if g.result~=0 then return end
  for p=1,2 do
    if g.incoming[p]>0 and now>=g.incoming[p] then
      if g.shield[p]>=g.incoming[p] then g.shield[p]=0
      else g.hp[p]=max(0,g.hp[p]-25) end
      g.incoming[p]=0
    end
  end
  if g.hp[1]==0 and g.hp[2]==0 then g.result=3
  elseif g.hp[1]==0 then g.result=2 elseif g.hp[2]==0 then g.result=1 end
end
local function apply(g,p,spell,number,now)
  if p==2 and number~=g.ack+1 then return 5 end
  advance(g,now)
  local result=0
  if g.result~=0 then result=4
  elseif spell==4 then g.result=3-p
  elseif g.mana[p]<costs[spell] then result=1
  elseif now<g.cd[p][spell] then result=2
  elseif spell==1 and g.incoming[3-p]>0 then result=3
  else
    g.mana[p]=clamp(g.mana[p]-costs[spell]+(spell==3 and 35 or 0),0,100)
    g.cd[p][spell]=now+cooldowns[spell]
    if spell==1 then g.incoming[3-p]=now+1800
    elseif spell==2 then g.shield[p]=now+2200 end
  end
  if p==2 then g.ack,g.reply=number,result end
  return result
end
local function pack_state(g,now)
  local function rem(t) return clamp(math.ceil(max(0,t-now)/20),0,255) end
  return string.format("%X%02X%02X%02X%02X%02X%02X%02X%02X%04X%X",
    g.result,g.hp[1],g.hp[2],g.mana[1],g.mana[2],rem(g.shield[1]),rem(g.shield[2]),
    rem(g.incoming[1]),rem(g.incoming[2]),g.ack,g.reply)
end
local function unpack_state(s,now)
  if #s~=22 or s:find("[^0-9A-F]") then return nil end
  local function h(a,b) return tonumber(s:sub(a,b),16) end
  local g={result=h(1,1),hp={h(2,3),h(4,5)},mana={h(6,7),h(8,9)},
    shield={now+h(10,11)*20,now+h(12,13)*20},
    incoming={h(14,15),h(16,17)},ack=h(18,21),reply=h(22,22)}
  if g.result>4 or g.reply>5 or g.hp[1]>100 or g.hp[2]>100 or g.mana[1]>100 or g.mana[2]>100 then return nil end
  for p=1,2 do g.incoming[p]=g.incoming[p]>0 and (now+g.incoming[p]*20) or 0 end
  return g
end

return new_match,apply,advance,pack_state,unpack_state
end
local function __load_codec()
local floor=math.floor
local function checksum(s)
  local v=0
  for i=1,#s do v=(v+s:byte(i)*i)%65536 end
  return string.char(floor(v/256),v%256)
end
local function encode_models(model)
  local parts={"SBG1"}
  for i=1,3 do
    parts[#parts+1]=string.char(#model[i])
    for _,s in ipairs(model[i]) do parts[#parts+1]=s end
  end
  local s=table.concat(parts);return s..checksum(s)
end
local function decode_models(s)
  if type(s)~="string" or #s<9 or #s>441 or s:sub(1,4)~="SBG1" then return nil end
  if checksum(s:sub(1,-3))~=s:sub(-2) then return nil end
  local result,pos={{},{},{}},5
  for i=1,3 do
    local n=s:byte(pos);pos=pos+1
    if not n or (n~=0 and n~=3) then return nil end
    for j=1,n do
      local t=s:sub(pos,pos+47); if #t~=48 then return nil end
      result[i][j]=t;pos=pos+48
    end
  end
  if pos~=#s-1 then return nil end
  return result
end

return encode_models,decode_models
end

local floor, min, max, abs = math.floor, math.min, math.max, math.abs
local MAX_CAPTURE=2400
local spells = {"Fireball", "Shield", "Recharge"}
local codes = {"F", "S", "R"}
local reject_messages={"Not enough mana","Spell cooling down","Attack already in flight","Match finished","Out-of-order action"}
local phase, selected, role = "home", 1, nil
local me, peer, sid, radio_ok = "", nil, nil, false
local peers, invite, match, pending, view = {}, nil, nil, nil, nil
local declined, declined_until = nil, 0
local seq, revision, last_revision = 0, 0, -1
local last_rx, next_tx, next_ui, next_led = 0, 0, 0, 0
local last_state_tx, last_ping, deadline = 0, 0, 0
local capture, training, models = nil, nil, {{},{},{}}
local note, note_until, effect, effect_until = "", 0, "", 0
local buttons, brightness, leave_until = false, 160, 0
local sensor_x,sensor_y,sensor_z
local reads,changes,diag_since=0,0,0
local led_rows={1,1,2,3,3,2}
local light_levels={0,64,160,255}
local radio_started=false
local widgets, text_cache, visible_phase = {}, {}, nil
local last_sample_at, next_gc = 0, 0
local stats_dirty, slot, locally_ended = false, 0, false

local function clamp(v,a,b) return min(b,max(a,v)) end
local function round(v) return floor(v+0.5) end
local function clock() return badge.sys.ms() end
local function mac_key(v)
  if type(v) ~= "string" then return nil end
  local s = string.upper((v:gsub(":", "")))
  if #s ~= 12 or s:find("[^0-9A-F]") then return nil end
  return s
end
local function message(s, fx, duration)
  note, note_until = s, clock() + (duration or 2000)
  if fx then effect, effect_until = fx, clock() + 700 end
end
local function transmit(kind, data)
  if not radio_ok or not sid then return false end
  local p = "SB1|"..kind.."|"..sid..(data and ("|"..data) or "")
  if #p > 44 then return false end
  return badge.radio.send(p)
end
local function split_packet(p)
  if type(p) ~= "string" or #p > 44 then return nil end
  local k,s,d = p:match("^SB1|([IJSKCTPQ])|([0-9A-F]+)|?(.*)$")
  if not k or #s ~= 8 then return nil end
  if p ~= "SB1|"..k.."|"..s..(d ~= "" and ("|"..d) or "") then return nil end
  return k,s,d
end

local label,ui_create
local raw_sample,signature,distance,recognize
local encode_models,decode_models
local new_match,apply,advance,pack_state,unpack_state
local function load_components()
  ui_create,label=nil,nil
  badge.sys.gc_step()
  raw_sample,signature,distance,recognize=__load_gesture();__load_gesture=nil
  badge.sys.gc_step()
  new_match,apply,advance,pack_state,unpack_state=__load_engine();__load_engine=nil
  badge.sys.gc_step()
  encode_models,decode_models=__load_codec();__load_codec=nil
  badge.sys.gc_step()
end
local function save_models(model)
  local next_slot=1-slot
  local path="appdata/gest"..next_slot..".dat"
  local data=encode_models(model)
  badge.fs.write(path,data)
  if badge.fs.read(path)~=data then return false end
  badge.store.set_int("gesture_slot",next_slot)
  if badge.store.get_int("gesture_slot",-1)~=next_slot then return false end
  slot,models=next_slot,model
  return true
end

local function send_state(now)
  if not match then return end
  revision=revision+1
  if revision>65535 then match.result=4;revision=65535 end
  transmit("T",string.format("%04X|",revision)..pack_state(match,now))
  last_state_tx=now
end
local function feedback(code,spell)
  if code==0 then message(spell==4 and "You surrendered" or (spells[spell].." cast"),spell==4 and nil or codes[spell])
  else message(reject_messages[code] or "Action rejected","X") end
end
local function submit(spell)
  if phase=="practice" then message(spells[spell]..(buttons and " test cast" or " recognized"),codes[spell]);return end
  if phase~="duel" then return end
  local now=clock()
  if role=="host" then feedback(apply(match,1,spell,0,now),spell);send_state(now)
  elseif view then
    if pending then message("Waiting for cast acknowledgement");return end
    if seq>=65534 then message("Match limit - start a new duel");return end
    seq=seq+1;pending={seq=seq,spell=spell,next=now,started=now}
  end
end
local function reset_home()
  phase,selected,role="home",1,nil
  peer,sid,match,pending,view,invite,capture,training=nil,nil,nil,nil,nil,nil,nil,nil
  seq,revision,last_revision=0,0,-1
  next_tx,leave_until,locally_ended=0,0,false
  note,note_until,effect,effect_until="",0,"",0
end
local function end_link(reason)
  locally_ended=true
  if match then match.result=4 end
  if view then view.result=4 end
  phase,pending,capture="result",nil,nil
  effect,effect_until="",0
  message(reason,nil,60000)
end

local function receive(mac,rssi,payload)
  local from=mac_key(mac)
  if not from or from==me then return end
  local now=clock()
  if payload=="SB1|H" then
    if phase=="lobby" then
      local found=false
      for _,p in ipairs(peers) do if p.id==from then p.seen=now;found=true;break end end
      if not found and #peers<5 then peers[#peers+1]={id=from,seen=now} end
    end
    return
  end
  local k,s,d=split_packet(payload)
  if not k then return end
  if k=="I" then
    if d~=me or (declined==from..s and now<declined_until) then return end
    if phase=="lobby" then
      invite={peer=from,sid=s};phase="offer";deadline=now+12000
    elseif phase=="joining" and from==peer and s==sid then transmit("J") end
    return
  end
  if k=="Q" and d=="" and phase=="offer" and invite.peer==from and invite.sid==s then
    invite=nil;phase="lobby";message("Invitation cancelled");return
  end
  if from~=peer or s~=sid or locally_ended then return end
  if k=="Q" and d=="" then
    if phase~="home" and phase~="result" then last_rx=now;end_link("Other badge left the match") end
  elseif k=="J" and d=="" and role=="host" then
    if phase=="waiting" then phase="starting";match=new_match(now);deadline=now+12000 end
    if phase=="starting" then last_rx=now;transmit("S")
    elseif phase=="duel" or phase=="result" then last_rx=now;send_state(now) end
  elseif k=="S" and d=="" and role=="guest" then
    if phase=="joining" or phase=="duel" then last_rx=now;transmit("K") end
  elseif k=="K" and d=="" and role=="host" and phase=="starting" then
    last_rx=now;phase="duel";match.started=now;send_state(now)
  elseif k=="P" and d=="" and role=="host" and (phase=="duel" or phase=="result") then last_rx=now
  elseif k=="C" and role=="host" and match and (phase=="duel" or phase=="result") then
    local n,c=d:match("^([0-9A-F]+)|([FSRX])$")
    if not n or #n~=4 then return end
    local number=tonumber(n,16)
    if number==0 or number>match.ack+1 then return end
    last_rx=now
    if number==match.ack+1 then
      local spell=c=="F" and 1 or (c=="S" and 2 or (c=="R" and 3 or 4))
      apply(match,2,spell,number,now)
    end
    send_state(now)
  elseif k=="T" and role=="guest" and (phase=="joining" or phase=="duel" or phase=="result") then
    local r,data=d:match("^([0-9A-F]+)|([0-9A-F]+)$")
    if not r or #r~=4 then return end
    local rev=tonumber(r,16)
    local g=unpack_state(data,now)
    if not g or rev<=last_revision or g.ack>seq then return end
    last_rx,last_revision=now,rev
    if view then
      if g.hp[2]<view.hp[2] then effect,effect_until="D",now+700
      elseif view.incoming[2]>0 and g.incoming[2]==0 and g.result==0 then effect,effect_until="B",now+700 end
    end
    view=g
    if pending and g.ack==pending.seq then feedback(g.reply,pending.spell);pending=nil end
    if phase=="joining" then phase="duel" end
    if g.result~=0 then phase,capture="result",nil end
  end
end

local function network_tick(now)
  if not radio_ok then return end
  if phase=="lobby" then
    for i=#peers,1,-1 do if now-peers[i].seen>4000 then table.remove(peers,i) end end
    selected=clamp(selected,1,max(1,#peers))
    if now>=next_tx then badge.radio.send("SB1|H");next_tx=now+850 end
  elseif phase=="offer" then
    if now>deadline then invite=nil;phase="lobby" end
  elseif phase=="waiting" or phase=="starting" or phase=="joining" then
    if now>deadline then end_link("Pairing timed out - try again");return end
    if now>=next_tx then
      transmit(phase=="waiting" and "I" or (phase=="starting" and "S" or "J"),phase=="waiting" and peer or nil)
      next_tx=now+600
    end
  elseif phase=="duel" or phase=="result" then
    if phase=="duel" and now-last_rx>6000 then end_link("Link lost - match cancelled");return end
    if role=="host" and match then
      local hp,attack=match.hp[1],match.incoming[1]
      advance(match,now)
      if match.hp[1]<hp then effect,effect_until="D",now+700
      elseif attack>0 and match.incoming[1]==0 and match.result==0 then effect,effect_until="B",now+700 end
      if match.result~=0 then phase,capture="result",nil end
      if now-last_state_tx>=300 then send_state(now) end
    elseif role=="guest" then
      if now-last_ping>=750 then transmit("P");last_ping=now end
      if pending and now>=pending.next then
        transmit("C",string.format("%04X|%s",pending.seq,pending.spell==4 and "X" or codes[pending.spell]))
        pending.next=now+350
        if now-pending.started>5000 then end_link("Cast not acknowledged - cancelled") end
      end
    end
  end
end

local function read_accel()
  local x,y,z=badge.sensor.accel()
  if type(x)=="number" and type(y)=="number" and type(z)=="number" and x==x and y==y and z==z and max(abs(x),abs(y),abs(z))<=4000 then return x,y,z end
end
local function capture_start(now)
  local x,y,z=read_accel()
  if not x then message("Motion sensor unavailable / invalid","X");return end
  capture={start=now,last=now,raw=raw_sample(0,x,y,z),bad=false}
  effect=""
end
local function capture_sample(now)
  if not capture or now-capture.last<20 then return end
  local x,y,z=read_accel()
  if not x then capture.bad=true;return end
  local elapsed=now-capture.start
  if elapsed<=MAX_CAPTURE then capture.raw=capture.raw..raw_sample(elapsed,x,y,z) end
  capture.last=now
end
local function capture_finish(now,too_long)
  if not capture then return end
  capture_sample(now)
  local raw,bad=capture.raw,capture.bad
  capture=nil
  if bad or too_long then message(too_long and "Gesture too long - try again" or "Sensor error / movement too strong","X");return end
  local sig,err=signature(raw)
  if not sig then message(err,"X");return end
  if phase=="teach" and training then
    local samples=training.samples
    if #samples<3 then
      for _,other in ipairs(samples) do if distance(sig,other)>0.48 then message("Repeat the SAME movement");return end end
      for s=1,3 do if s~=training.spell then
        for _,other in ipairs(models[s]) do if distance(sig,other)<0.28 then message("Too similar to "..spells[s]);return end end
      end end
      samples[#samples+1]=sig
      message(#samples==3 and "Now test with a NEW repetition" or "Example saved in RAM","R")
    else
      local proposed={models[1],models[2],models[3]};proposed[training.spell]=samples
      local id,why=recognize(sig,proposed)
      if id~=training.spell then message("Test failed - repeat or B to retry");return end
      if save_models(proposed) then
        message(spells[id].." learned and saved","R",4000);training=nil;phase="train_select"
      else message("Save failed; old model kept") end
    end
  else
    local id,why=recognize(sig,models)
    if id then submit(id) else message(why,"X") end
  end
end

label=function(root,key,x,y,w,h,size,color)
  local obj=badge.ui.label(root,"")
  obj:set_pos(x,y);obj:set_size(w,h)
  obj:style({text_font=size,text_color=color or 0xE8E4F5,pad_all=0})
  widgets[key]=obj
end
local function text(key,value)
  if text_cache[key]~=value then widgets[key]:set_text(value);text_cache[key]=value;return true end
end
ui_create=function(root)
  local bg=badge.ui.box(root,320,240);bg:set_pos(0,0)
  bg:style({bg_color=0x100C20,border_width=0,pad_all=0,radius=0})
  label(bg,"title",12,7,296,27,24,0xC3A0FF)
  label(bg,"status",12,37,296,20,14,0xA49BB8)
  label(bg,"body",12,63,296,111,16)
  label(bg,"left",12,63,140,19,14,0xC3A0FF);label(bg,"right",168,63,140,19,14,0xF0CA73)
  label(bg,"score1",12,97,140,18,14);label(bg,"score2",168,97,140,18,14)
  label(bg,"effect",12,128,296,24,18,0xF0CA73)
  label(bg,"hint",12,180,296,36,14,0xE8E4F5)
  label(bg,"footer",12,221,296,17,14,0xB9B2CB)
  for i=1,4 do
    local b=badge.ui.bar(bg,0,100,100)
    b:set_pos(i%2==1 and 12 or 168,i<=2 and 85 or 117);b:set_size(140,i<=2 and 7 or 4)
    b:style({bg_color=0x30263F,radius=3})
    b:style({bg_color=i>2 and 0x69C9C4 or (i==1 and 0xC3A0FF or 0xF0CA73)},"indicator")
    widgets["bar"..i]=b
  end
  local b=badge.ui.bar(bg,0,2400,0);b:set_pos(12,173);b:set_size(296,4)
  b:style({bg_color=0x30263F});b:style({bg_color=0xE8C573},"indicator");widgets.progress=b
  for i=1,2 do
    local p=badge.ui.box(bg,9,9);p:style({bg_color=0xFF924E,border_width=0,radius=4})
    widgets["orb"..i]=p
  end
end
local function render(now)
  local duel=phase=="duel" or phase=="result"
  local own=role=="host" and 1 or 2
  local g=role=="host" and match or view
  if visible_phase~=phase then
    visible_phase=phase;widgets.body:hidden(duel)
    for _,k in ipairs({"left","right","score1","score2","effect","bar1","bar2","bar3","bar4"}) do widgets[k]:hidden(not duel) end
  end
  local shown=now<note_until and note or ""
  local hint,footer="","UP/DOWN select  A open  B back"
  text("title","SPELLBOUND")
  text("status",string.upper(phase:gsub("_"," ")).." / "..(buttons and "BUTTONS" or "MOTION").." / "..me:sub(-4))
  if duel then
    if g then
      for i=1,2 do
        local p=i==1 and own or 3-own
        if text(i==1 and "left" or "right",(i==1 and "YOU  HP " or "FOE  HP ")..g.hp[p]) then widgets["bar"..i]:set_value(g.hp[p]) end
        if text("score"..i,"MANA "..g.mana[p]) then widgets["bar"..(i+2)]:set_value(g.mana[p]) end
      end
    end
    local title="READY TO CAST"
    if phase=="result" then
      title=(not g or g.result==4) and "MATCH CANCELLED" or (g.result==3 and "DRAW" or (g.result==own and "YOU WIN" or "DEFEAT"))
      footer="A or B returns to menu"
    else
      if g and g.incoming[own]>now then title=g.shield[own]>=g.incoming[own] and "SHIELD READY TO BLOCK" or "INCOMING! CAST SHIELD"
      elseif now<effect_until and effect=="B" then title="BLOCKED"
      elseif capture then title="CHANNELING..."
      elseif pending then title="CAST QUEUED - WAIT"
      elseif g and g.shield[own]>now then title="SHIELD ACTIVE" end
      footer=buttons and "LEFT fire  UP shield  RIGHT mana" or "Hold A > move > release"
      hint="FIRE 30  SHIELD 25  MANA +35\nSTART controls. B twice surrenders."
    end
    text("effect",title)
  else
    local body=""
    if phase=="home" or phase=="lobby" or phase=="train_select" then
      local items=phase=="home" and {"Find a duel","Practice spells","Teach a spell","Diagnostics"} or {}
      if phase=="lobby" then for i,p in ipairs(peers) do items[i]="Badge "..p.id:sub(-4) end end
      if phase=="train_select" then for i=1,3 do items[i]=spells[i]..(#models[i]>0 and " [learned]" or " [preset]") end end
      for i,t in ipairs(items) do body=body..(i==selected and "> " or "  ")..t.."\n" end
      if phase=="lobby" then
        hint="Your radio code: "..me:sub(-4).."\nOne player sends the invitation."
        if #peers==0 then body="Searching...\nBoth badges: Find a duel.\nKeep badges nearby." end
      elseif phase=="home" then
        hint="AUX lights "..brightness.."/255  Radio "..(radio_ok and "ON" or "OFF").."\nHOME saves settings and exits"
        footer="A open   START changes controls"
      else hint="Three examples, then a fresh test." end
    elseif phase=="offer" then body="Challenge from "..invite.peer:sub(-4).."\n\nAccept this player?";footer="A accepts   B declines"
    elseif phase=="waiting" then body="Invitation queued.\nWaiting for opponent to accept.";footer="B cancels"
    elseif phase=="starting" or phase=="joining" then body="Synchronizing...";footer="B cancels"
    elseif phase=="teach" then
      body=spells[training.spell].."\n"..(#training.samples<3 and ("Example "..(#training.samples+1).." of 3") or "Fresh test repetition").."\n\nHold still; move; release A."
      hint="Keep the same starting pose.\nOnly a successful test saves."
      footer="Hold A to record   B cancels"
    elseif phase=="practice" then
      body="FIREBALL: push, then stop\nSHIELD: tilt up and hold\nRECHARGE: side to side\n\nUse Teach for personal gestures."
      hint="Preset accuracy is unmeasured.\nNo opponent or radio required."
      footer=buttons and "LEFT fire  UP shield  RIGHT mana" or "Hold A > move > release   B back"
    elseif phase=="diag" then
      local stats=badge.sys.stats()
      body=(sensor_x and string.format("Accel: %d %d %d mg",round(sensor_x),round(sensor_y),round(sensor_z)) or "Sensor unavailable")..
        string.format("\nReads %d / changed %d\nChanges/s %d (not Hz)\nLua %d/%d; peak %d\nWidgets %d / radio drops %d",reads,changes,floor(changes*1000/max(1,now-diag_since)),stats.lua_used,stats.lua_limit,stats.lua_peak,stats.widgets,badge.radio.dropped())
      hint="Changed readings are not sample Hz.\nA logs stats to the IDE console."
      footer="A log stats   B back"
    end
    text("body",body)
  end
  text("hint",shown~="" and shown or hint)
  text("footer",capture and "Recording... release A" or footer)
  widgets.progress:hidden(not capture)
  if capture then widgets.progress:set_value(clamp(now-capture.start,0,2400)) end
  for i=1,2 do
    local active=phase=="duel" and g and g.incoming[i]>now
    widgets["orb"..i]:hidden(not active)
    if active then
      local f=clamp(1-(g.incoming[i]-now)/1800,0,1)
      widgets["orb"..i]:set_pos(round(i==own and 284-f*268 or 16+f*268),i==own and 151 or 161)
    end
  end
end
local function leds(now)
  local g=role=="host" and match or view
  local own=role=="host" and 1 or 2
  local mode=now<effect_until and effect or ""
  if phase=="result" then mode=(g and g.result==own) and "W" or "E"
  elseif mode=="D" or mode=="B" then -- Confirmed impact feedback.
  elseif capture then mode="C"
  elseif phase=="duel" and g and g.incoming[own]>now then mode=g.shield[own]>=g.incoming[own] and "S" or "I"
  elseif mode=="" and phase=="duel" and g and g.shield[own]>now then mode="S" end
  local pulse=(now%2400)/1200
  if pulse>1 then pulse=2-pulse end
  local wave=0.4+0.6*pulse
  local sweep=floor(now/170)%3+1
  local chase=floor(now/150)%6+1
  for i=1,6 do
    local r,gc,b,v=0,0,0,wave
    local row=led_rows[i]
    if mode=="C" then r,gc=1,0.65;v=4-row<=math.ceil((now-capture.start)/800) and 1 or 0.25
    elseif mode=="F" or mode=="I" then r,gc=1,0.3;v=(mode=="F" and 4-row or row)==sweep and 1 or 0.3
    elseif mode=="S" or mode=="B" then gc,b=0.65,1
    elseif mode=="R" then gc,b=1,0.5;v=4-row==sweep and 1 or 0.3
    elseif mode=="D" then r=1
    elseif mode=="X" then r,gc=1,0.55
    elseif mode=="W" then r,gc,b=1,0.78,0.3;v=i==chase and 1 or 0.3
    elseif mode=="E" then r,gc,b=0.75,0.45,0.45
    elseif phase=="duel" and g then
      local left=i==1 or i==6 or i==5
      v=row<=math.ceil(g.hp[left and own or (3-own)]/100*3) and 0.75 or 0
      r,gc,b=left and 0.65 or 1,left and 0.35 or 0.78,left and 1 or 0.3
    elseif phase=="lobby" or phase=="offer" or phase=="waiting" or phase=="starting" or phase=="joining" then
      gc,b=0.6,1;v=i==chase and 1 or 0.2
    else r,gc,b=0.65,0.35,1 end
    badge.led.set(i,round(r*brightness*v),round(gc*brightness*v),round(b*brightness*v))
  end
  badge.led.show()
end

function on_enter(root)
  ui_create(root)
  load_components()
  me=mac_key(badge.radio.mac()) or "000000000000"
  buttons=badge.store.get_int("buttons",0)==1
  brightness=clamp(badge.store.get_int("brightness",160),0,255)
  slot=clamp(badge.store.get_int("gesture_slot",0),0,1)
  local loaded=decode_models(badge.fs.read("appdata/gest"..slot..".dat"))
  if not loaded then loaded=decode_models(badge.fs.read("appdata/gest"..(1-slot)..".dat"));if loaded then slot=1-slot end end
  if loaded then models=loaded end
  diag_since=clock()
  badge.sys.log("Spellbound 0.2.0 | firmware "..tostring(badge.sys.version()))
  render(clock());leds(clock())
end
function on_tick()
  local now=clock()
  network_tick(now)
  if capture then
    if now-capture.start>MAX_CAPTURE then capture_finish(now,true)
    else capture_sample(now);if not badge.input.is_down(badge.input.BUTTON.A) then capture_finish(now,false) end end
  end
  if phase=="diag" and now-last_sample_at>=20 then
    last_sample_at=now
    local x,y,z=read_accel()
    if x then
      reads=reads+1
      if x~=sensor_x or y~=sensor_y or z~=sensor_z then changes=changes+1 end
      sensor_x,sensor_y,sensor_z=x,y,z
    else sensor_x,sensor_y,sensor_z=nil,nil,nil end
  end
  if now>=next_ui then render(now);next_ui=now+(phase=="diag" and 500 or 100) end
  if now>=next_led then leds(now);next_led=now+70 end
  if now>=next_gc then badge.sys.gc_step();next_gc=now+250 end
end
function on_button(button,kind)
  local B,K=badge.input.BUTTON,badge.input.KIND
  local now=clock()
  if button==B.A and kind==K.RELEASED then capture_finish(now,false);return end
  if kind~=K.PRESSED then return end
  if button==B.START and (phase=="home" or phase=="practice" or phase=="duel") then
    if capture then capture=nil end
    effect,effect_until="",0
    buttons=not buttons;stats_dirty=true;message(buttons and "Button controls enabled" or "Motion controls enabled");return
  end
  if button==B.AUX1 and phase=="home" then
    local level=0
    for _,v in ipairs(light_levels) do if v>brightness then level=v;break end end
    brightness=level;stats_dirty=true
    message("LED brightness "..brightness.." / 255");return
  end
  if button==B.B then
    capture=nil
    if phase=="duel" then
      if now<leave_until then submit(4);leave_until=0 else leave_until=now+1800;message("Press B again to surrender",nil,1800) end
    elseif phase=="teach" then training=nil;phase="train_select"
    elseif phase=="offer" then
      declined,declined_until=invite.peer..invite.sid,now+14000
      badge.radio.send("SB1|Q|"..invite.sid);invite=nil;phase="lobby"
    else if sid and phase~="result" then transmit("Q") end;reset_home() end
    return
  end
  if phase=="home" then
    if button==B.UP then selected=(selected+2)%4+1
    elseif button==B.DOWN then selected=selected%4+1
    elseif button==B.A then
      if selected==1 then
        if not radio_started then
          radio_started=badge.radio.enable()==true
          me=mac_key(badge.radio.mac()) or me
          radio_ok=radio_started and me~="000000000000"
          if radio_ok then badge.radio.on_recv(receive) end
        end
        if radio_ok then phase,peers,selected,next_tx="lobby",{},1,0
        else message("Radio unavailable; HOME then reopen","X") end
      elseif selected==2 then phase="practice"
      elseif selected==3 then phase,selected="train_select",1
      else phase="diag";reads,changes,diag_since=0,0,now;sensor_x,sensor_y,sensor_z=nil,nil,nil end
    end
  elseif phase=="lobby" then
    if button==B.UP then selected=max(1,selected-1)
    elseif button==B.DOWN then selected=min(max(1,#peers),selected+1)
    elseif button==B.A and peers[selected] then
      peer=peers[selected].id;sid=string.format("%08X",badge.sys.random())
      role,phase,deadline,last_rx,next_tx="host","waiting",now+12000,now,0
      seq,revision,last_revision=0,0,-1
    end
  elseif phase=="offer" and button==B.A then
    peer,sid=invite.peer,invite.sid;invite=nil
    role,phase,deadline,last_rx,next_tx="guest","joining",now+12000,now,0
    seq,revision,last_revision=0,0,-1
  elseif phase=="train_select" then
    if button==B.UP then selected=(selected+1)%3+1
    elseif button==B.DOWN then selected=selected%3+1
    elseif button==B.A then training={spell=selected,samples={}};phase="teach" end
  elseif phase=="teach" then
    if button==B.A and not capture then capture_start(now) end
  elseif phase=="duel" or phase=="practice" then
    if buttons then
      if button==B.LEFT then submit(1) elseif button==B.UP then submit(2) elseif button==B.RIGHT then submit(3) end
    elseif button==B.A and not capture then capture_start(now) end
  elseif phase=="diag" and button==B.A then
    local s=badge.sys.stats()
    badge.sys.log("firmware="..badge.sys.version().." lua="..s.lua_used.."/"..s.lua_limit.." peak="..s.lua_peak.." widgets="..s.widgets.." free="..s.free_heap)
    message("Stats logged to the IDE console")
  elseif phase=="result" and button==B.A then reset_home() end
end
function on_exit()
  if sid then transmit("Q") end
  if stats_dirty then badge.store.set_int("buttons",buttons and 1 or 0);badge.store.set_int("brightness",brightness) end
  badge.radio.on_recv(nil);badge.radio.disable()
  badge.led.clear();badge.led.show()
end
