local APP={}
SPELLBOUND_APP=APP
local S={}
S[4]=4
S[1]=4500
S[63],S[10]={"Fireball","Shield","Recharge"},"FSR"
S[49],S[58],S[30],S[50]=0,1,"",false
S[43],S[44],S[16],S[17]="",0,0,0
S[42],S[40],S[39],S[24]=0,0,0,nil
SPELLBOUND_STATE=S
local root,label
S[9]=function() return badge.sys.ms() end
S[28]=function(v)
if type(v)~="string" then return nil end
local s=string.upper((v:gsub(":","")))
if #s~=12 or s:find("[^0-9A-F]") then return nil end
return s
end
S[31]=function(s,fx,duration)
S[43],S[44]=s,S[9]()+(duration or 2000)
if fx then S[16],S[17]=fx,S[9]()+700 end
end
S[55]=function()
S[49],S[58]=0,1
S[32],S[33]=nil,nil
S[5],S[68]=nil,nil
S[57],S[46],S[61],S[29],S[48],S[71],S[22]=nil,nil,nil,nil,nil,nil,nil
S[47]=nil
S[60],S[56]=0,0
S[41],S[27]=0,false
S[23],S[25],S[12]=0,0,0
S[13]=nil
S[43],S[44],S[16],S[17]="",0,0,0
S[24]=nil
end
S[14]=function()
if label then label:delete();label=nil end
S[24]=nil
end
S[11]=function(parent)
if label then return end
label=badge.ui.label(parent,"")
label:set_pos(12,8);label:set_size(296,224)
label:style({text_font=14,text_color=0xE8E4F5,pad_all=0})
S[24]=nil
end
S[54]=function(now)
if not label then return end
local shown=now<S[44] and S[43] or ""
local section=S[49]==0 and "HOME" or
((S[49]==1 or S[49]==2) and "TEACH" or "DUEL")
local out="SPELLBOUND / "..section.." / "..S[30]:sub(-4).."\n\n"
if S[49]==0 then
out=out..(S[58]==1 and "> " or "  ").."Find a duel\n"..
(S[58]==2 and "> " or "  ").."Teach a spell\n\n"..
(shown~="" and shown or ("Radio "..(S[50] and "ON" or "OFF")))..
"\nA open / B back"
elseif S[33] then
out=out..S[33](now,shown)
else out=out.."Loading..." end
if S[24]~=out then label:set_text(out);S[24]=out end
end
local function gc8() for _=1,8 do badge.sys.gc_step() end end
local function loaded(v)
if not v then error("Spellbound file versions do not match; reinstall every app file") end
end
local function drop()
S[14]();gc8()
end
local function rebuild()
gc8();S[11](root);S[54](S[9]())
end
local function load_teach()
if S[66] then return end
require("gesture_dtw");gc8()
require("gesture_sig");gc8()
require("casting");gc8()
require("training");gc8()
loaded(S[53] and S[62] and S[7] and S[66])
end
local function load_duel()
if S[37] then return end
require("network");gc8()
require("net_rx");gc8()
require("net_tick");gc8()
loaded(S[35] and S[52] and S[37])
end
S[19]=function()
if not S[38] then require("engine");gc8() end
loaded(S[38] and S[3] and S[70])
S[19]=nil
end
local function teach()
if not S[66] then drop();load_teach();load_teach=nil end
S[49],S[58]=1,1
S[32],S[33]=S[66],S[67]
if not label then rebuild() else S[54](S[9]()) end
end
local function duel()
if S[50] then
if not S[37] then drop();load_duel();load_duel=nil end
badge.radio.on_recv(S[52])
S[49],S[47],S[58],S[41]=3,{},1,0
S[32],S[33]=S[35],S[36]
else
S[49]=0;S[31]("Radio unavailable; HOME then reopen",4)
end
if not label then rebuild() else S[54](S[9]()) end
end
local function enter(r,radio_ready)
root=r;S[11](r)
S[30]=S[28](badge.radio.mac()) or "000000000000"
S[50]=radio_ready==true and S[30]~="000000000000"
local now=S[9]();S[54](now);badge.led.clear();badge.led.show()
end
local function tick()
local now=S[9]()
if S[37] then S[37](now) end
if S[5] and S[8] then S[8](now) end
if now>=S[42] then S[54](now);S[42]=now+100 end
if S[26] and now>=S[40] then S[26](now);S[40]=now+70 end
if now>=S[39] then badge.sys.gc_step();S[39]=now+250 end
end
local function button(b,k)
local B,K=badge.input.BUTTON,badge.input.KIND;local now=S[9]()
if b==B.A and k==K.RELEASED then
if S[5] and S[6] then S[6](now,false) end
return
end
if k~=K.PRESSED then return end
if S[49]==0 then
if b==B.UP or b==B.DOWN then S[58]=S[58]==1 and 2 or 1
elseif b==B.A then if S[58]==1 then duel() else teach() end end
elseif S[32] then S[32](b,k,now) end
end
local function exit()
if S[61] and S[69] then S[69]("Q") end
badge.radio.on_recv(nil);badge.radio.disable();badge.led.clear();badge.led.show()
S[50]=false
end
APP.enter,APP.tick,APP.button,APP.exit=enter,tick,button,exit
return APP
