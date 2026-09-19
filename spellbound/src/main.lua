--[[
MIT License

Copyright (c) 2026 Spellbound contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

]]

-- Spellbound: a foreground two-badge duel for the HTN 2026 Lua API.
-- A: hold / move / release. B: back (twice to surrender). START: control mode.
-- Button mode: LEFT Fireball, UP Shield, RIGHT Recharge. HOME exits.
-- Source is original; no GesturePod/EdgeML code or model is included.
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
local led_rows={1,1,2,3,3,2}
local light_levels={0,64,160,255}
local radio_started=false
local widgets, text_cache, visible_phase = {}, {}, nil
local next_gc = 0
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
  -- Reject a missing separator before nonempty data and non-canonical shapes.
  if p ~= "SB1|"..k.."|"..s..(d ~= "" and ("|"..d) or "") then return nil end
  return k,s,d
end

local label,ui_create
local raw_sample,signature,distance,recognize
local encode_models,decode_models
local new_match,apply,advance,pack_state,unpack_state
-- Load modules after the main chunk returns, so compiler temporaries can be freed.
local function load_components()
  -- Construction is one-shot; release its code before loading game modules.
  ui_create,label=nil,nil
  badge.sys.gc_step()
  local g=require("gesture")
  raw_sample,signature,distance,recognize=g.raw_sample,g.signature,g.distance,g.recognize
  badge.sys.gc_step()
  local e=require("engine");new_match,apply,advance,pack_state,unpack_state=e.new_match,e.apply,e.advance,e.pack,e.unpack
  badge.sys.gc_step()
  local c=require("model_codec");encode_models,decode_models=c.encode,c.decode
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

-- A deliberate invitation, then J/S/K handshake. No user identity is broadcast.
-- Peer MAC + fresh session nonce scope the match; this is NOT authentication.
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
      if now-last_state_tx>=200 then send_state(now) end
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

-- Low-widget-count, asset-free UI. All native positions and sizes are integers.
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
      local items=phase=="home" and {"Find a duel","Practice spells","Teach a spell"} or {}
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
  -- Leave Bluetooth off until Find a duel; Practice/Teach need no radio.
  badge.sys.log("Spellbound | firmware "..tostring(badge.sys.version()))
  render(clock());leds(clock())
end
function on_tick()
  local now=clock()
  network_tick(now)
  if capture then
    if now-capture.start>MAX_CAPTURE then capture_finish(now,true)
    else capture_sample(now);if not badge.input.is_down(badge.input.BUTTON.A) then capture_finish(now,false) end end
  end
  if now>=next_ui then render(now);next_ui=now+100 end
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
    if button==B.UP then selected=(selected+1)%3+1
    elseif button==B.DOWN then selected=selected%3+1
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
      else phase,selected="train_select",1 end
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
  elseif phase=="result" and button==B.A then reset_home() end
end
function on_exit()
  if sid then transmit("Q") end
  if stats_dirty then badge.store.set_int("buttons",buttons and 1 or 0);badge.store.set_int("brightness",brightness) end
  badge.radio.on_recv(nil);badge.radio.disable()
  badge.led.clear();badge.led.show()
end

-- TEST_EXPORTS_BEGIN
-- Test-only exports. SPELLBOUND_TEST is never defined by the badge runtime.
if SPELLBOUND_TEST then
  return function() return {signature=signature,distance=distance,recognize=recognize,preset=require("gesture").preset,
    encode_models=encode_models,decode_models=decode_models,save_models=save_models,
    raw_sample=raw_sample,new_match=new_match,apply=apply,advance=advance,
    pack_state=pack_state,unpack_state=unpack_state,split_packet=split_packet,
    receive=receive,submit=submit,
    state=function() return {phase=phase,role=role,match=match,view=view,pending=pending,
      models=models,training=training,capture=capture,peers=peers,sid=sid,seq=seq,note=note,radio=radio_ok} end} end
end
