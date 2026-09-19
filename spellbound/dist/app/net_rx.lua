if SPELLBOUND_STATE[4]~=4 then error("Spellbound file versions do not match; reinstall every app file") end
local S=SPELLBOUND_STATE
S[52]=function(mac,rssi,payload)
local from=S[28](mac);if not from or from==S[30] then return end
local now=S[9]();local phase=S[49]
if payload=="SB1|H" then
if phase==3 then
local signal=type(rssi)=="number" and rssi or -127
local found=false
for i=1,#S[47],3 do
if S[47][i]==from then S[47][i+1],S[47][i+2]=now,signal;found=true;break end
end
if not found and #S[47]<15 then
S[47][#S[47]+1]=from;S[47][#S[47]+1]=now;S[47][#S[47]+1]=signal
elseif not found then
local weak=1
for i=4,#S[47],3 do if S[47][i+2]<S[47][weak+2] then weak=i end end
if signal>S[47][weak+2]+3 then S[47][weak],S[47][weak+1],S[47][weak+2]=from,now,signal end
end
end
return
end
local k,s,d=S[64](payload);if not k then return end
if k=="I" then
if d~=S[30] or (S[13]==from..s and now<(S[12] or 0)) then return end
if phase==3 then S[22]={from,s};S[49]=4;S[12]=now+12000
elseif phase==5 and from==S[46] and from<S[30] then
S[61],S[57],S[49],S[12],S[23],S[41]=s,2,7,now+12000,now,0
S[60],S[56]=0,-1;S[27]=false;S[47]=nil;S[69]("J")
elseif phase==7 and from==S[46] and s==S[61] then S[69]("J") end
return
end
if k=="Q" and d=="" and phase==4 and S[22] and S[22][1]==from and S[22][2]==s then
S[22]=nil;S[49]=3;S[31]("Invitation cancelled");return
end
if from~=S[46] or s~=S[61] or S[27] then return end
if k=="Q" and d=="" then
if phase~=0 and phase~=9 then S[23]=now;S[18]("Other badge left the match") end
elseif S[57]==1 then
local active=phase==8 or phase==9
if k=="J" and d=="" then
if phase==5 then S[49]=6;phase=6;S[29]=S[38](now);S[12]=now+12000 end
if phase==6 then S[23]=now;S[69]("S")
elseif active then S[23]=now;S[59](now) end
elseif k=="K" and d=="" and phase==6 then
S[23]=now;S[49]=8;S[12]=0;S[59](now)
elseif k=="P" and d=="" and active then S[23]=now
elseif k=="C" and S[29] and active then
local n,c=d:match("^([0-9A-F]+)|([FSRX])$")
if not n or #n~=4 then return end
local number=tonumber(n,16);if number==0 or number>S[29][16]+1 then return end
S[23]=now
if number==S[29][16]+1 then
local spell=c=="F" and 1 or (c=="S" and 2 or (c=="R" and 3 or 4))
S[3](S[29],2,spell,number,now)
end
S[59](now)
end
elseif S[57]==2 then
if k=="S" and d=="" then
if phase==7 or phase==8 then S[23]=now;S[69]("K") end
elseif k=="T" and (phase==7 or phase==8 or phase==9) then
local r,data=d:match("^([0-9A-F]+)|([0-9A-F]+)$")
if not r or #r~=4 then return end
local old_hp=S[71] and S[71][3]
local old_in=S[71] and S[71][9]
local rev=tonumber(r,16);local seq=tonumber(data:sub(18,21),16)
if rev<=(S[56] or -1) or not seq or seq>(S[60] or 0) then return end
local g=S[70](data,now,S[71]);if not g then return end
S[23],S[56]=now,rev
if old_hp then
if g[3]<old_hp then S[16],S[17]=5,now+700
elseif old_in>0 and g[9]==0 and g[1]==0 then S[16],S[17]=6,now+700 end
end
S[71]=g
if S[48] and g[16]==S[48][1] then S[20](g[17],S[48][2]);S[48]=nil end
if phase==7 then S[49]=8;S[12]=0 end
if g[1]~=0 then S[49],S[5]=9,nil end
end
end
end
