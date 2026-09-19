if SPELLBOUND_STATE[4]~=5 then error("Spellbound files mismatch; reinstall all") end
local S=SPELLBOUND_STATE
local function rem(t,now) return math.min(93,math.ceil(math.max(0,t-now)/40)) end
S[8]=function(op,a,b,c)
if op==0 then
return string.char(33+a[1],33+a[2]/25,33+a[3]/25,33+a[4]/5,33+a[5]/5,
33+rem(a[6],b),33+rem(a[7],b),33+rem(a[8],b),33+rem(a[9],b))..
string.format("%04X",S[56])..string.char(33+a[16])
end
if #a~=14 then return nil end
c=c or {}
c[1],c[2],c[3],c[4],c[5],c[6],c[7],c[8],c[9]=a:byte(1,9)
for i=1,9 do c[i]=c[i]-33;if c[i]<0 then return nil end end
c[10],c[11]=tonumber(a:sub(10,13),16),(a:byte(14) or 0)-33
if not c[10] or c[1]>4 or c[11]<0 or c[11]>1 or
math.max(c[2],c[3])>4 or math.max(c[4],c[5])>20 then return nil end
c[2],c[3],c[4],c[5]=c[2]*25,c[3]*25,c[4]*5,c[5]*5
c[6],c[7]=b+c[6]*40,b+c[7]*40
c[8],c[9]=c[8]>0 and b+c[8]*40 or 0,c[9]>0 and b+c[9]*40 or 0
return c
end
S[48]=function(mac,rssi,p)
local from=S[27](mac);if not from or from==S[29] then return end
local now=S[7]();local phase=S[45]
if p=="SB2H" then
if phase==3 then
local signal=rssi
for i=1,#S[43],3 do
if S[43][i]==from then S[43][i+1],S[43][i+2]=now,signal;return end
end
if #S[43]<15 then
S[43][#S[43]+1]=from;S[43][#S[43]+1]=now;S[43][#S[43]+1]=signal
else
local weak=1
for i=4,#S[43],3 do if S[43][i+2]<S[43][weak+2] then weak=i end end
if signal>S[43][weak+2]+3 then S[43][weak],S[43][weak+1],S[43][weak+2]=from,now,signal end
end
end
return
end
if #p<12 or p:sub(1,3)~="SB2" then return end
local k,s=p:sub(4,4),p:sub(5,12)
if not tonumber(s,16) then return end
if k=="I" and #p==24 then
if p:sub(13)~=S[29] or (S[12]==from..s and now<(S[11] or 0)) then return end
if phase==3 then S[21]={from,s};S[45]=4;S[11]=now+12000
elseif phase==5 and from==S[42] and from<S[29] then
S[57],S[53],S[45],S[11],S[22],S[38]=s,2,6,now+12000,now,0
S[56],S[52],S[24]=0,-1,0;S[26]=false;S[43]=nil;S[63]("J")
elseif phase==6 and from==S[42] and s==S[57] then S[63]("J") end
return
end
if k=="Q" and #p==12 and phase==4 and S[21] and S[21][1]==from and S[21][2]==s then
S[21]=nil;S[45]=3;S[30]("Invite cancelled");return
end
if from~=S[42] or s~=S[57] or S[26] then return end
if k=="Q" and #p==12 then
if phase~=0 and phase~=8 then S[22]=now;S[17]() end
elseif S[53]==1 then
local active=phase==7 or phase==8
if k=="J" and #p==12 then
S[22]=now
if phase==5 then
S[45]=7;phase=7;S[28]={0,100,100,75,75,0,0,0,0,0,0,0,0,0,0,0};S[11]=0
end
if phase==7 then S[55](now) end
elseif k=="P" and #p==12 and active then S[22]=now
elseif k=="C" and #p==17 and S[28] and active then
local number=tonumber(p:sub(13,16),16);local c=p:sub(17)
if not number or number==0 or number>S[56]+1 or not c:find("^[FSRX]$") then return end
S[22]=now
if number==S[56]+1 then
local spell=c=="F" and 1 or (c=="S" and 2 or (c=="R" and 3 or 4))
S[3](S[28],2,spell,number,now)
end
S[55](now)
end
elseif S[53]==2 and k=="T" and #p==30 and (phase==6 or phase==7 or phase==8) then
local rev=tonumber(p:sub(13,16),16);if not rev then return end
local data=p:sub(17);local seq=tonumber(data:sub(10,13),16)
if rev<=(S[52] or -1) or not seq or seq>(S[56] or 0) then return end
local old_hp=S[64] and S[64][3];local old_in=S[64] and S[64][9]
local g=S[8](1,data,now,S[64]);if not g then return end
S[22],S[52]=now,rev
if old_hp then
if g[3]<old_hp then S[15],S[16]=5,now+700
elseif old_in>0 and g[9]==0 and g[1]==0 then S[15],S[16]=6,now+700 end
end
S[64]=g
if S[44] and g[10]==S[44][1] then S[19](g[11],S[44][2]);S[44]=nil end
if phase==6 then S[45]=7;S[11]=0 end
if g[1]~=0 then
S[45],S[5]=8,nil
if g[1]==2 then S[15],S[16]=7,now+60000 end
end
end
end
