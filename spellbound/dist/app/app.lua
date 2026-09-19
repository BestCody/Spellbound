local APP={}
SPELLBOUND_APP=APP
local S={}
S[4]=3
S[1]=4500
S[68],S[10]={"Fireball","Shield","Recharge"},{"F","S","R"}
S[53],S[63],S[34],S[54]="home",1,"",false
S[47],S[48],S[17],S[18]="",0,"",0
S[46],S[44],S[43],S[27]=0,0,0,nil
SPELLBOUND_STATE=S
local root,label,radio_tried
S[9]=function() return badge.sys.ms() end
S[32]=function(v)
if type(v)~="string" then return nil end
local s=string.upper((v:gsub(":","")))
if #s~=12 or s:find("[^0-9A-F]") then return nil end
return s
end
S[35]=function(s,fx,duration)
S[47],S[48]=s,S[9]()+(duration or 2000)
if fx then S[17],S[18]=fx,S[9]()+700 end
end
S[60]=function()
S[53],S[63]="home",1
S[36],S[37]=nil,nil
S[5],S[73]=nil,nil
S[62],S[50],S[66],S[33],S[52],S[76],S[23]=nil,nil,nil,nil,nil,nil,nil
S[51]=nil
S[65],S[61],S[25]=0,0,-1
S[45],S[29],S[31]=0,0,false
S[26],S[28],S[24],S[12]=0,0,0,0
S[13],S[14]=nil,0
S[47],S[48],S[17],S[18]="",0,"",0
S[27]=nil
end
S[15]=function()
if label then label:delete();label=nil end
S[27]=nil
end
S[11]=function(parent)
if label then return end
label=badge.ui.label(parent,"")
label:set_pos(12,8);label:set_size(296,224)
label:style({text_font=14,text_color=0xE8E4F5,pad_all=0})
S[27]=nil
end
S[59]=function(now)
if not label then return end
local shown=now<S[48] and S[47] or ""
local out="SPELLBOUND / "..string.upper(S[53]:gsub("_"," ")).." / "..S[34]:sub(-4).."\n\n"
if S[53]=="home" then
out=out..(S[63]==1 and "> " or "  ").."Find a duel\n"..
(S[63]==2 and "> " or "  ").."Teach a spell\n\n"..
(shown~="" and shown or ("Radio "..(S[54] and "ON" or "OFF")))..
"\nA open / B back"
elseif S[37] then
out=out..S[37](now,shown)
else out=out.."Loading..." end
if S[27]~=out then label:set_text(out);S[27]=out end
end
local function gc8() for _=1,8 do badge.sys.gc_step() end end
local function loaded(v)
if not v then error("Spellbound file versions do not match; reinstall every app file") end
end
local function drop()
S[15]();gc8()
end
local function rebuild()
gc8();S[11](root);S[59](S[9]())
end
local function load_teach()
if S[71] then return end
require("gesture_dtw");gc8()
require("gesture_sig");gc8()
require("casting");gc8()
require("training");gc8()
loaded(S[58] and S[67] and S[7] and S[71])
end
local function load_duel()
if S[41] then return end
require("network");gc8()
require("net_rx");gc8()
require("net_tick");gc8()
loaded(S[39] and S[57] and S[41])
end
S[20]=function()
if not S[42] then require("engine");gc8() end
loaded(S[42] and S[3] and S[75])
S[20]=nil
end
local function teach()
if not S[71] then drop();load_teach();load_teach=nil end
S[53],S[63]="train_select",1
S[36],S[37]=S[71],S[72]
if not label then rebuild() else S[59](S[9]()) end
end
local function duel()
if not S[41] and not radio_tried then drop() end
if not radio_tried then
radio_tried=true
S[55]=badge.radio.enable()==true
S[34]=S[32](badge.radio.mac()) or S[34]
S[54]=S[55] and S[34]~="000000000000"
end
if S[54] then
if not S[41] then load_duel();load_duel=nil end
badge.radio.on_recv(S[57])
S[53],S[51],S[63],S[45]="lobby",{},1,0
S[36],S[37]=S[39],S[40]
else
S[53]="home";S[35]("Radio unavailable; HOME then reopen","X")
end
if not label then rebuild() else S[59](S[9]()) end
end
local function enter(r)
root=r;radio_tried=false;S[55]=false;S[54]=false;S[11](r)
S[34]=S[32](badge.radio.mac()) or "000000000000"
local now=S[9]();S[59](now);badge.led.clear();badge.led.show()
end
local function tick()
local now=S[9]()
if S[41] then S[41](now) end
if S[5] and S[8] then S[8](now) end
if now>=S[46] then S[59](now);S[46]=now+100 end
if S[30] and now>=S[44] then S[30](now);S[44]=now+70 end
if now>=S[43] then badge.sys.gc_step();S[43]=now+250 end
end
local function button(b,k)
local B,K=badge.input.BUTTON,badge.input.KIND;local now=S[9]()
if b==B.A and k==K.RELEASED then
if S[5] and S[6] then S[6](now,false) end
return
end
if k~=K.PRESSED then return end
if S[53]=="home" then
if b==B.UP or b==B.DOWN then S[63]=S[63]==1 and 2 or 1
elseif b==B.A then if S[63]==1 then duel() else teach() end end
elseif S[36] then S[36](b,k,now) end
end
local function exit()
if S[66] and S[74] then S[74]("Q") end
badge.radio.on_recv(nil);badge.radio.disable();badge.led.clear();badge.led.show()
S[55],S[54],radio_tried=false,false,false
end
APP.enter,APP.tick,APP.button,APP.exit=enter,tick,button,exit
return APP
