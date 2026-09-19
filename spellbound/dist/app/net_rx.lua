if SPELLBOUND_STATE[4]~=3 then error("Spellbound file versions do not match; reinstall every app file") end
local S=SPELLBOUND_STATE
S[57]=function(mac,rssi,payload)
local from=S[32](mac);if not from or from==S[34] then return end
local now=S[9]()
if payload=="SB1|H" then
if S[53]=="lobby" then
local signal=type(rssi)=="number" and rssi or -127
local found=false
for i=1,#S[51],3 do
if S[51][i]==from then S[51][i+1],S[51][i+2]=now,signal;found=true;break end
end
if not found and #S[51]<15 then
S[51][#S[51]+1]=from;S[51][#S[51]+1]=now;S[51][#S[51]+1]=signal
elseif not found then
local weak=1
for i=4,#S[51],3 do if S[51][i+2]<S[51][weak+2] then weak=i end end
if signal>S[51][weak+2]+3 then S[51][weak],S[51][weak+1],S[51][weak+2]=from,now,signal end
end
end
return
end
local k,s,d=S[69](payload);if not k then return end
if k=="I" then
if d~=S[34] or (S[13]==from..s and now<(S[14] or 0)) then return end
if S[53]=="lobby" then S[23]={from,s};S[53]="offer";S[12]=now+12000
elseif S[53]=="waiting" and from==S[50] and from<S[34] then
S[66],S[62],S[53],S[12],S[26],S[45]=s,"guest","joining",now+12000,now,0
S[65],S[61],S[25]=0,0,-1;S[31]=false;S[74]("J")
elseif S[53]=="joining" and from==S[50] and s==S[66] then S[74]("J") end
return
end
if k=="Q" and d=="" and S[53]=="offer" and S[23] and S[23][1]==from and S[23][2]==s then
S[23]=nil;S[53]="lobby";S[35]("Invitation cancelled");return
end
if from~=S[50] or s~=S[66] or S[31] then return end
if k=="Q" and d=="" then
if S[53]~="home" and S[53]~="result" then S[26]=now;S[19]("Other badge left the match") end
elseif k=="J" and d=="" and S[62]=="host" then
if S[53]=="waiting" then S[53]="starting";S[33]=S[42](now);S[12]=now+12000 end
if S[53]=="starting" then S[26]=now;S[74]("S")
elseif S[53]=="duel" or S[53]=="result" then S[26]=now;S[64](now) end
elseif k=="S" and d=="" and S[62]=="guest" then
if S[53]=="joining" or S[53]=="duel" then S[26]=now;S[74]("K") end
elseif k=="K" and d=="" and S[62]=="host" and S[53]=="starting" then
S[26]=now;S[53]="duel";S[33][18]=now;S[64](now)
elseif k=="P" and d=="" and S[62]=="host" and (S[53]=="duel" or S[53]=="result") then
S[26]=now
elseif k=="C" and S[62]=="host" and S[33] and (S[53]=="duel" or S[53]=="result") then
local n,c=d:match("^([0-9A-F]+)|([FSRX])$")
if not n or #n~=4 then return end
local number=tonumber(n,16);if number==0 or number>S[33][16]+1 then return end
S[26]=now
if number==S[33][16]+1 then
local spell=c=="F" and 1 or (c=="S" and 2 or (c=="R" and 3 or 4))
S[3](S[33],2,spell,number,now)
end
S[64](now)
elseif k=="T" and S[62]=="guest" and (S[53]=="joining" or S[53]=="duel" or S[53]=="result") then
local r,data=d:match("^([0-9A-F]+)|([0-9A-F]+)$")
if not r or #r~=4 then return end
local old_hp=S[76] and S[76][3]
local old_in=S[76] and S[76][9]
local rev=tonumber(r,16);local seq=tonumber(data:sub(18,21),16)
if rev<=(S[25] or -1) or not seq or seq>(S[65] or 0) then return end
local g=S[75](data,now,S[76]);if not g then return end
S[26],S[25]=now,rev
if old_hp then
if g[3]<old_hp then S[17],S[18]="D",now+700
elseif old_in>0 and g[9]==0 and g[1]==0 then S[17],S[18]="B",now+700 end
end
S[76]=g
if S[52] and g[16]==S[52][1] then S[21](g[17],S[52][2]);S[52]=nil end
if S[53]=="joining" then S[53]="duel" end
if g[1]~=0 then S[53],S[5]="result",nil end
end
end
