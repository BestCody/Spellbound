-- Spellbound coordinator with memory-ordered feature loading.
local APP={}
SPELLBOUND_APP=APP
local S=require("core")
badge.sys.gc_step()

local root_handle
local network_loaded,casting_loaded,training_loaded,gesture_loaded=false,false,false,false
local teach_preloaded,duel_preloaded=false,false

local function gc_hard() for _=1,8 do badge.sys.gc_step() end end
local function mem(tag)
  local x=badge.sys.stats()
  badge.sys.log(string.format("MEM %s lua=%d peak=%d free=%d widgets=%d",
    tag,x.lua_used or -1,x.lua_peak or -1,x.free_heap or -1,x.widgets or -1))
end
local function install(name,...)
  local init=require(name);init(S,...);init=nil;badge.sys.gc_step()
end
local function ensure_network()
  if not network_loaded then install("network");network_loaded=true end
end
local function drop_ui(tag)
  mem(tag.."-before-ui-drop");S.destroy_ui();gc_hard();mem(tag.."-after-ui-drop")
end
local function rebuild_ui(tag)
  gc_hard();mem(tag.."-before-ui-rebuild")
  S.create_ui(root_handle);S.render(S.clock());mem(tag.."-after-ui-rebuild")
end

-- Hardware require() has a private cache and no package.loaded escape hatch.
-- Compile the largest recognizer chunk first, while physical heap is largest.
local function load_gesture_stack(tag)
  if gesture_loaded and casting_loaded and training_loaded then return end
  local sig=require("gesture_sig");mem(tag.."-after-gesture-sig")
  if not casting_loaded then
    local c=require("casting");c(S,sig);c=nil;casting_loaded=true
    badge.sys.gc_step();mem(tag.."-after-casting")
  end
  S.raw_sample,S.signature=sig.raw_sample,sig.signature;sig=nil;badge.sys.gc_step()
  local dtw=require("gesture_dtw")
  S.distance,S.class_score,S.calibrate,S.recognize,S.train_max=
    dtw.distance,dtw.class_score,dtw.calibrate,dtw.recognize,dtw.train_max
  dtw=nil;badge.sys.gc_step();gesture_loaded=true;mem(tag.."-after-gesture-dtw")
  if not training_loaded then
    local t=require("training");t(S);t=nil;training_loaded=true
    badge.sys.gc_step();mem(tag.."-after-training")
  end
end

local function preload_teach()
  if teach_preloaded then S.phase,S.selected="train_select",1;return end
  drop_ui("teach")
  load_gesture_stack("teach")
  gc_hard();teach_preloaded=true;S.phase,S.selected="train_select",1
  rebuild_ui("teach")
end
local function enter_lobby()
  if duel_preloaded and S.radio_started and S.radio_ok then
    S.phase,S.peers,S.selected,S.next_tx="lobby",{},1,0;return
  end
  drop_ui("duel")
  if not duel_preloaded then
    ensure_network();mem("duel-after-network")
    S.ensure_engine();mem("duel-after-engine")
    gc_hard();duel_preloaded=true
  end
  if not S.radio_started then
    mem("duel-before-radio")
    S.radio_started=badge.radio.enable()==true
    S.me=S.mac_key(badge.radio.mac()) or S.me
    S.radio_ok=S.radio_started and S.me~="000000000000"
    if S.radio_ok then badge.radio.on_recv(S.receive) end
    mem("duel-after-radio")
  end
  if S.radio_ok then S.phase,S.peers,S.selected,S.next_tx="lobby",{},1,0
  else S.phase="home";S.message("Radio unavailable; HOME then reopen","X") end
  rebuild_ui("duel")
end

local function enter(root)
  root_handle=root;install("ui",root)
  S.me=S.mac_key(badge.radio.mac()) or "000000000000"
  badge.sys.log("Spellbound | firmware "..tostring(badge.sys.version()))
  local now=S.clock();S.render(now);S.leds(now);mem("home-ready")
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
  if button==B.A and kind==K.RELEASED then
    if casting_loaded then S.capture_finish(now,false) end;return
  end
  if kind~=K.PRESSED then return end
  if button==B.B then
    S.capture=nil
    if S.phase=="duel" then
      if now<S.leave_until then if S.submit then S.submit(4) end;S.leave_until=0
      else S.leave_until=now+1800;S.message("Press B again to surrender",nil,1800) end
    elseif S.phase=="teach" then S.training=nil;S.phase="train_select"
    elseif S.phase=="offer" then
      S.declined,S.declined_until=S.invite.peer..S.invite.sid,now+14000
      badge.radio.send("SB1|Q|"..S.invite.sid);S.invite=nil;S.phase="lobby"
    else if S.sid and S.phase~="result" and S.transmit then S.transmit("Q") end;S.reset_home() end
    return
  end
  if S.phase=="home" then
    if button==B.UP or button==B.DOWN then S.selected=S.selected==1 and 2 or 1
    elseif button==B.A then if S.selected==1 then enter_lobby() else preload_teach() end end
  elseif S.phase=="lobby" then
    if button==B.UP then S.selected=math.max(1,S.selected-1)
    elseif button==B.DOWN then S.selected=math.min(math.max(1,#S.peers),S.selected+1)
    elseif button==B.A and S.peers[S.selected] then
      S.peer=S.peers[S.selected].id;S.sid=string.format("%08X",badge.sys.random())
      S.role,S.phase,S.deadline,S.last_rx,S.next_tx="host","waiting",now+12000,now,0
      S.seq,S.revision,S.last_revision=0,0,-1
    end
  elseif S.phase=="offer" and button==B.A then
    S.peer,S.sid=S.invite.peer,S.invite.sid;S.invite=nil
    S.role,S.phase,S.deadline,S.last_rx,S.next_tx="guest","joining",now+12000,now,0
    S.seq,S.revision,S.last_revision=0,0,-1
  elseif S.phase=="train_select" then
    if button==B.UP then S.selected=(S.selected+1)%3+1
    elseif button==B.DOWN then S.selected=S.selected%3+1
    elseif button==B.A then S.training={spell=S.selected,samples={}};S.phase="teach" end
  elseif S.phase=="teach" then
    if button==B.A and not S.capture then S.capture_start(now) end
  elseif S.phase=="duel" then
    if button==B.A and not S.capture then
      if casting_loaded then S.capture_start(now) else S.message("Teach spells before duel","X") end
    end
  elseif S.phase=="result" and button==B.A then S.reset_home() end
end
local function exit()
  if S.sid and S.transmit then S.transmit("Q") end
  badge.radio.on_recv(nil);badge.radio.disable();badge.led.clear();badge.led.show()
end
APP.enter,APP.tick,APP.button,APP.exit=enter,tick,button,exit

return APP
