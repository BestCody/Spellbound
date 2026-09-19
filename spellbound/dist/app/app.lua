local APP={}
SPELLBOUND_APP=APP
local S={}
S[4]=5
S[1]=4500
S[59],S[9]={"Fireball","Shield","Recharge"},"FSR"
S[45],S[54],S[29],S[46]=0,1,"",false
S[40],S[41],S[15],S[16]="",0,0,0
S[39],S[37],S[36],S[23]=0,0,0,nil
SPELLBOUND_STATE=S
local root,label
S[7]=function() return badge.sys.ms() end
S[27]=function(v)
if type(v)~="string" then return nil end
local s=string.upper((v:gsub(":","")))
if #s~=12 or s:find("[^0-9A-F]") then return nil end
return s
end
S[30]=function(s,fx,duration)
S[40],S[41]=s,S[7]()+(duration or 2000)
if fx then S[15],S[16]=fx,S[7]()+700 end
end
S[51]=function()
S[45],S[54]=0,1
S[31],S[32]=nil,nil
S[5],S[62]=nil,nil
S[53],S[42],S[57],S[28],S[44],S[64],S[21]=nil,nil,nil,nil,nil,nil,nil
S[43]=nil
S[56],S[52]=0,0
S[38],S[26]=0,false
S[22],S[24],S[11]=0,0,0
S[12]=nil
S[40],S[41],S[15],S[16]="",0,0,0
S[23]=nil
end
S[13]=function()
if label then label:delete();label=nil end
S[23]=nil
end
S[10]=function(parent)
if label then return end
label=badge.ui.label(parent,"")
label:set_pos(12,8);label:set_size(296,224)
label:style({text_font=14,text_color=0xE8E4F5,pad_all=0})
S[23]=nil
end
S[50]=function(now)
if not label then return end
local shown=now<S[41] and S[40] or ""
local section=S[45]==0 and "HOME" or
((S[45]==1 or S[45]==2) and "TEACH" or "DUEL")
local out="SPELLBOUND / "..section.." / "..S[29]:sub(-4).."\n\n"
if S[45]==0 then
out=out..(S[54]==1 and "> " or "  ").."Find a duel\n"..
(S[54]==2 and "> " or "  ").."Teach a spell\n\n"..
(shown~="" and shown or ("Radio "..(S[46] and "ON" or "OFF")))..
"\nA open / B back"
elseif S[32] then
out=out..S[32](now,shown)
else out=out.."Loading..." end
if S[23]~=out then label:set_text(out);S[23]=out end
end
local function gc8() for _=1,8 do badge.sys.gc_step() end end
local function loaded(v)
if not v then error("Spellbound files mismatch; reinstall all") end
end
local function drop()
S[13]();gc8()
end
local function rebuild()
gc8();S[10](root);S[50](S[7]())
end
local function load_teach()
if S[61] then return end
require("gesture_dtw");gc8()
require("gesture_sig");gc8()
require("casting");gc8()
require("training");gc8()
loaded(S[49] and S[58] and S[6] and S[61])
end
local function load_duel()
if S[35] then return end
require("net_rx");gc8()
require("net_ui");gc8()
require("apply");gc8()
require("net_tick");gc8()
require("network");gc8()
loaded(S[3] and S[34] and S[48] and S[35] and S[25])
end
S[18]=function()
if not S[3] then gc8();require("apply");gc8() end
loaded(S[2] and S[3] and S[8])
S[18]=nil
end
local function teach()
if not S[61] then drop();load_teach();load_teach=nil end
S[45],S[54]=1,1
S[31],S[32]=S[61],S[61]
if not label then rebuild() else S[50](S[7]()) end
end
local function duel()
if S[46] then
if not S[35] then drop();load_duel();load_duel=nil end
badge.radio.on_recv(S[48])
S[45],S[43],S[54],S[38]=3,{},1,0
S[31],S[32]=S[34],S[34]
else
S[45]=0;S[30]("Radio unavailable",4)
end
if not label then rebuild() else S[50](S[7]()) end
end
local function enter(r,radio_ready)
root=r;S[10](r)
S[29]=S[27](badge.radio.mac()) or "000000000000"
S[46]=radio_ready==true and S[29]~="000000000000"
local now=S[7]();S[50](now);badge.led.clear();badge.led.show()
end
local function tick()
local now=S[7]()
if S[35] then S[35](now) end
if S[5] and S[6] then S[6](now,2) end
if now>=S[39] then S[50](now);S[39]=now+100 end
if S[25] and now>=S[37] then S[25](now);S[37]=now+70 end
if now>=S[36] then badge.sys.gc_step();S[36]=now+250 end
end
local function button(b,k)
local B,K=badge.input.BUTTON,badge.input.KIND;local now=S[7]()
if b==B.A and k==K.RELEASED then
if S[5] and S[6] then S[6](now,1) end
return
end
if k~=K.PRESSED then return end
if S[45]==0 then
if b==B.UP or b==B.DOWN then S[54]=S[54]==1 and 2 or 1
elseif b==B.A then if S[54]==1 then duel() else teach() end end
elseif S[31] then S[31](b,k,now) end
end
local function exit()
if S[57] and S[63] then S[63]("Q") end
badge.radio.on_recv(nil);badge.radio.disable();badge.led.clear();badge.led.show()
S[46]=false
end
APP.enter,APP.tick,APP.button,APP.exit=enter,tick,button,exit
return APP
