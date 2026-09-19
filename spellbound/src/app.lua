-- Small coordinator. Feature-specific buttons/UI effects live in lazy modules.
local APP={}
SPELLBOUND_APP=APP
local S=require("core")
badge.sys.gc_step()
local root

local function gc8() for _=1,8 do badge.sys.gc_step() end end
local function mem(tag)
  local x=badge.sys.stats()
  badge.sys.log(string.format("MEM %s lua=%d peak=%d free=%d widgets=%d",
    tag,x.lua_used or -1,x.lua_peak or -1,x.free_heap or -1,x.widgets or -1))
end
local function drop(tag)
  mem(tag.."-before-ui-drop");S.destroy_ui();gc8();mem(tag.."-after-ui-drop")
end
local function rebuild(tag)
  gc8();mem(tag.."-before-ui-rebuild");S.create_ui(root);S.render(S.clock())
  mem(tag.."-after-ui-rebuild")
end
local function load_teach(tag)
  if S.handle_signature then return end
  local sig=require("gesture_sig");mem(tag.."-after-gesture-sig")
  local c=require("casting");c(S,sig);c=nil;badge.sys.gc_step();mem(tag.."-after-casting")
  S.raw_sample,S.signature=sig.raw_sample,sig.signature;sig=nil;badge.sys.gc_step()
  local d=require("gesture_dtw")
  S.distance,S.class_score,S.calibrate,S.recognize,S.train_max=
    d.distance,d.class_score,d.calibrate,d.recognize,d.train_max
  d=nil;badge.sys.gc_step();mem(tag.."-after-gesture-dtw")
  local t=require("training");t(S);t=nil;badge.sys.gc_step();mem(tag.."-after-training")
end
local function teach()
  if S.handle_signature then S.phase,S.selected="train_select",1;S.mode_button=S.teach_button;return end
  drop("teach");load_teach("teach");S.phase,S.selected="train_select",1;rebuild("teach")
end
local function duel()
  if S.network_tick and S.radio_started and S.radio_ok then
    S.phase,S.peers,S.selected,S.next_tx="lobby",{},1,0;S.mode_button=S.net_button;return
  end
  drop("duel")
  if not S.network_tick then
    local n=require("network");n(S);n=nil;badge.sys.gc_step();mem("duel-after-network")
    S.ensure_engine();mem("duel-after-engine");gc8()
  end
  if not S.radio_started then
    mem("duel-before-radio");S.radio_started=badge.radio.enable()==true
    S.me=S.mac_key(badge.radio.mac()) or S.me;S.radio_ok=S.radio_started and S.me~="000000000000"
    if S.radio_ok then badge.radio.on_recv(S.receive) end
    mem("duel-after-radio")
  end
  if S.radio_ok then S.phase,S.peers,S.selected,S.next_tx="lobby",{},1,0;S.mode_button=S.net_button
  else S.phase="home";S.message("Radio unavailable; HOME then reopen","X") end
  rebuild("duel")
end
local function enter(r)
  root=r;local u=require("ui");u(S,r);u=nil;badge.sys.gc_step()
  S.me=S.mac_key(badge.radio.mac()) or "000000000000"
  badge.sys.log("Spellbound | firmware "..tostring(badge.sys.version()))
  local now=S.clock();S.render(now);badge.led.clear();badge.led.show();mem("home-ready")
end
local function tick()
  local now=S.clock()
  if S.network_tick then S.network_tick(now) end
  if S.capture and S.capture_tick then S.capture_tick(now) end
  if now>=S.next_ui then S.render(now);S.next_ui=now+100 end
  if S.leds and now>=S.next_led then S.leds(now);S.next_led=now+70 end
  if now>=S.next_gc then badge.sys.gc_step();S.next_gc=now+250 end
end
local function button(b,k)
  local B,K=badge.input.BUTTON,badge.input.KIND;local now=S.clock()
  if b==B.A and k==K.RELEASED then
    if S.capture and S.capture_finish then S.capture_finish(now,false) end
    return
  end
  if k~=K.PRESSED then return end
  if S.phase=="home" then
    if b==B.UP or b==B.DOWN then S.selected=S.selected==1 and 2 or 1
    elseif b==B.A then if S.selected==1 then duel() else teach() end end
  elseif S.mode_button then S.mode_button(b,k,now) end
end
local function exit()
  if S.sid and S.transmit then S.transmit("Q") end
  badge.radio.on_recv(nil);badge.radio.disable();badge.led.clear();badge.led.show()
end
APP.enter,APP.tick,APP.button,APP.exit=enter,tick,button,exit
-- TEST_ONLY_BEGIN
local function test_api()
  load_teach("test")
  if not S.network_tick then local n=require("network");n(S) end
  S.ensure_engine()
  return {signature=S.signature,distance=S.distance,recognize=S.recognize,raw_sample=S.raw_sample,
    calibrate=S.calibrate,class_score=S.class_score,
    new_match=S.new_match,apply=S.apply,advance=S.advance,pack_state=S.pack_state,unpack_state=S.unpack_state,
    split_packet=S.split_packet,receive=S.receive,submit=S.submit,
    state=function() return {phase=S.phase,role=S.role,match=S.match,view=S.view,pending=S.pending,
      models=S.models,thresholds=S.thresholds,training=S.training,capture=S.capture,
      peers=S.peers,sid=S.sid,seq=S.seq,note=S.note,radio=S.radio_ok} end}
end
APP.test_api=test_api
-- TEST_ONLY_END
return APP
