-- Spellbound coordinator. Heavy feature modules are installed only when entered.
local S=require("core")
if package and package.loaded then package.loaded["core"]=nil end
badge.sys.gc_step()

local network_loaded,casting_loaded=false,false
local function install(name,...)
  local init=require(name);init(S,...)
  if package and package.loaded then package.loaded[name]=nil end
  init=nil;badge.sys.gc_step()
end
local function ensure_network() if not network_loaded then install("network");network_loaded=true end end
local function ensure_casting() if not casting_loaded then install("casting");casting_loaded=true end end

local function enter(root)
  install("ui",root)
  S.me=S.mac_key(badge.radio.mac()) or "000000000000"
  badge.sys.log("Spellbound | firmware "..tostring(badge.sys.version()))
  local now=S.clock();S.render(now);S.leds(now)
end
local function tick()
  local now=S.clock()
  if network_loaded then S.network_tick(now) end
  if casting_loaded and S.capture then S.capture_tick(now) end
  if now>=S.next_ui then S.render(now);S.next_ui=now+100 end
  if now>=S.next_led then S.leds(now);S.next_led=now+70 end
  if now>=S.next_gc then badge.sys.gc_step();S.next_gc=now+250 end
end
local function button(button,kind)
  local B,K=badge.input.BUTTON,badge.input.KIND;local now=S.clock()
  if button==B.A and kind==K.RELEASED then if casting_loaded then S.capture_finish(now,false) end;return end
  if kind~=K.PRESSED then return end
  if button==B.B then
    S.capture=nil
    if S.phase=="duel" then
      if now<S.leave_until then if S.submit then S.submit(4) end;S.leave_until=0 else S.leave_until=now+1800;S.message("Press B again to surrender",nil,1800) end
    elseif S.phase=="teach" then S.training=nil;S.phase="train_select"
    elseif S.phase=="offer" then
      S.declined,S.declined_until=S.invite.peer..S.invite.sid,now+14000;badge.radio.send("SB1|Q|"..S.invite.sid);S.invite=nil;S.phase="lobby"
    else if S.sid and S.phase~="result" and S.transmit then S.transmit("Q") end;S.reset_home() end
    return
  end
  if S.phase=="home" then
    if button==B.UP or button==B.DOWN then S.selected=S.selected==1 and 2 or 1
    elseif button==B.A then
      if S.selected==1 then
        ensure_network()
        if not S.radio_started then
          S.radio_started=badge.radio.enable()==true;S.me=S.mac_key(badge.radio.mac()) or S.me;S.radio_ok=S.radio_started and S.me~="000000000000"
          if S.radio_ok then badge.radio.on_recv(S.receive) end
        end
        if S.radio_ok then S.phase,S.peers,S.selected,S.next_tx="lobby",{},1,0 else S.message("Radio unavailable; HOME then reopen","X") end
      else ensure_casting();S.phase,S.selected="train_select",1 end
    end
  elseif S.phase=="lobby" then
    if button==B.UP then S.selected=math.max(1,S.selected-1)
    elseif button==B.DOWN then S.selected=math.min(math.max(1,#S.peers),S.selected+1)
    elseif button==B.A and S.peers[S.selected] then
      S.peer=S.peers[S.selected].id;S.sid=string.format("%08X",badge.sys.random());S.role,S.phase,S.deadline,S.last_rx,S.next_tx="host","waiting",now+12000,now,0;S.seq,S.revision,S.last_revision=0,0,-1
    end
  elseif S.phase=="offer" and button==B.A then
    S.peer,S.sid=S.invite.peer,S.invite.sid;S.invite=nil;S.role,S.phase,S.deadline,S.last_rx,S.next_tx="guest","joining",now+12000,now,0;S.seq,S.revision,S.last_revision=0,0,-1
  elseif S.phase=="train_select" then
    if button==B.UP then S.selected=(S.selected+1)%3+1 elseif button==B.DOWN then S.selected=S.selected%3+1 elseif button==B.A then ensure_casting();S.training={spell=S.selected,samples={}};S.phase="teach" end
  elseif S.phase=="teach" or S.phase=="duel" then
    if button==B.A and not S.capture then ensure_casting();S.capture_start(now) end
  elseif S.phase=="result" and button==B.A then S.reset_home() end
end
local function exit()
  if S.sid and S.transmit then S.transmit("Q") end
  badge.radio.on_recv(nil);badge.radio.disable();badge.led.clear();badge.led.show()
end
local function test_api()
  ensure_casting();S.ensure_gesture();ensure_network();S.ensure_engine()
  return {signature=S.signature,distance=S.distance,recognize=S.recognize,raw_sample=S.raw_sample,
    calibrate=S.calibrate,class_score=S.class_score,
    new_match=S.new_match,apply=S.apply,advance=S.advance,pack_state=S.pack_state,unpack_state=S.unpack_state,
    split_packet=S.split_packet,receive=S.receive,submit=S.submit,
    state=function() return {phase=S.phase,role=S.role,match=S.match,view=S.view,pending=S.pending,
      models=S.models,thresholds=S.thresholds,training=S.training,capture=S.capture,
      peers=S.peers,sid=S.sid,seq=S.seq,note=S.note,radio=S.radio_ok} end}
end
return {enter=enter,tick=tick,button=button,exit=exit,test_api=test_api}
