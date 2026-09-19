local APP={}
SPELLBOUND_APP=APP
local min,max=math.min,math.max
local S={
MAX_CAPTURE=4500,
spells={"Fireball","Shield","Recharge"},codes={"F","S","R"},
phase="home",selected=1,me="",radio_ok=false,
note="",note_until=0,effect="",effect_until=0,
next_ui=0,next_led=0,next_gc=0,last_screen=nil,
}
SPELLBOUND_STATE=S
local root,label
function S.clamp(v,a,b) return min(b,max(a,v)) end
function S.clock() return badge.sys.ms() end
function S.mac_key(v)
if type(v)~="string" then return nil end
local s=string.upper((v:gsub(":","")))
if #s~=12 or s:find("[^0-9A-F]") then return nil end
return s
end
function S.message(s,fx,duration)
S.note,S.note_until=s,S.clock()+(duration or 2000)
if fx then S.effect,S.effect_until=fx,S.clock()+700 end
end
function S.reset_home()
S.phase,S.selected="home",1
S.mode_button,S.mode_render=nil,nil
S.capture,S.training=nil,nil
S.role,S.peer,S.sid,S.match,S.pending,S.view,S.invite=nil,nil,nil,nil,nil,nil,nil
S.peers=nil
S.seq,S.revision,S.last_revision=0,0,-1
S.next_tx,S.leave_until,S.locally_ended=0,0,false
S.last_rx,S.last_state_tx,S.last_ping,S.deadline=0,0,0,0
S.declined,S.declined_until=nil,0
S.note,S.note_until,S.effect,S.effect_until="",0,"",0
S.last_screen=nil
end
function S.destroy_ui()
if label then label:delete();label=nil end
S.last_screen=nil
end
function S.create_ui(parent)
if label then return end
label=badge.ui.label(parent,"")
label:set_pos(12,8);label:set_size(296,224)
label:style({text_font=14,text_color=0xE8E4F5,pad_all=0})
S.last_screen=nil
end
function S.render(now)
if not label then return end
local shown=now<S.note_until and S.note or ""
local out="SPELLBOUND / "..string.upper(S.phase:gsub("_"," ")).." / "..S.me:sub(-4).."\n\n"
if S.phase=="home" then
out=out..(S.selected==1 and "> " or "  ").."Find a duel\n"..
(S.selected==2 and "> " or "  ").."Teach a spell\n\n"..
(shown~="" and shown or ("Radio "..(S.radio_ok and "ON" or "OFF")))..
"\nA open / B back"
elseif S.mode_render then
out=out..S.mode_render(now,shown)
else out=out.."Loading..." end
if S.last_screen~=out then label:set_text(out);S.last_screen=out end
end
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
if S.teach_button then return end
require("gesture_dtw");badge.sys.gc_step();mem(tag.."-after-gesture-dtw")
require("gesture_sig");badge.sys.gc_step();mem(tag.."-after-gesture-sig")
require("casting");badge.sys.gc_step();mem(tag.."-after-casting")
require("training");badge.sys.gc_step();mem(tag.."-after-training")
end
local function load_duel(tag)
if S.network_tick then return end
require("network");badge.sys.gc_step();mem(tag.."-after-network")
require("net_rx");badge.sys.gc_step();mem(tag.."-after-net-rx")
require("net_tick");badge.sys.gc_step();mem(tag.."-after-net-tick")
require("engine");badge.sys.gc_step();mem(tag.."-after-engine")
end
local function teach()
if not S.teach_button then drop("teach");load_teach("teach") end
S.phase,S.selected="train_select",1
S.mode_button,S.mode_render=S.teach_button,S.teach_render
if not label then rebuild("teach") else S.render(S.clock()) end
end
local function duel()
if not S.network_tick then drop("duel");load_duel("duel") end
if not S.radio_started then
mem("duel-before-radio");S.radio_started=badge.radio.enable()==true
S.me=S.mac_key(badge.radio.mac()) or S.me
S.radio_ok=S.radio_started and S.me~="000000000000"
if S.radio_ok then badge.radio.on_recv(S.receive) end
mem("duel-after-radio")
end
if S.radio_ok then
S.phase,S.peers,S.selected,S.next_tx="lobby",{},1,0
S.mode_button,S.mode_render=S.net_button,S.net_render
else
S.phase="home";S.message("Radio unavailable; HOME then reopen","X")
end
if not label then rebuild("duel") else S.render(S.clock()) end
end
local function enter(r)
root=r;S.create_ui(r)
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
return APP
