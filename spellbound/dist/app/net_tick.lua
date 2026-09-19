if SPELLBOUND_STATE[4]~=5 then error("Spellbound files mismatch; reinstall all") end
local S=SPELLBOUND_STATE
S[2]=function(g,now)
if g[1]~=0 then return end
for p=1,2 do
local ii=7+p;local si=5+p;local hi=1+p
if g[ii]>0 and now>=g[ii] then
if g[si]>=g[ii] then g[si]=0 else g[hi]=math.max(0,g[hi]-25) end
g[ii]=0
end
end
if g[2]==0 and g[3]==0 then g[1]=3 elseif g[2]==0 then g[1]=2 elseif g[3]==0 then g[1]=1 end
end
S[35]=function(now)
local phase=S[45]
if phase==3 then
for i=#S[43]-2,1,-3 do if now-S[43][i+1]>4000 then table.remove(S[43],i+2);table.remove(S[43],i+1);table.remove(S[43],i) end end
S[54]=math.min(math.max(S[54],1),math.max(1,#S[43]/3))
if now>=S[38] then badge.radio.send("SB2H");S[38]=now+850 end
elseif phase==4 then
if now>S[11] then S[21]=nil;S[45]=3 end
elseif phase==5 or phase==6 then
if now>S[11] then S[17]();return end
if now>=S[38] then
S[63](phase==5 and "I" or "J",
phase==5 and S[42] or nil)
S[38]=now+600
end
elseif phase==7 or phase==8 then
if phase==7 and now-S[22]>6000 then S[17]();return end
if S[53]==1 and S[28] then
local hp,attack=S[28][2],S[28][8];S[2](S[28],now)
if S[28][2]<hp then S[15],S[16]=5,now+700
elseif attack>0 and S[28][8]==0 and S[28][1]==0 then S[15],S[16]=6,now+700 end
if S[28][1]~=0 then
S[45],S[5]=8,nil
if S[28][1]==1 then S[15],S[16]=7,now+60000 end
end
if now-S[24]>=200 then S[55](now) end
elseif S[53]==2 then
if now-S[24]>=750 then S[63]("P");S[24]=now end
if S[44] and now>=S[44][3] then
S[63]("C",string.format("%04X%s",S[44][1],
S[44][2]==4 and "X" or S[9]:sub(S[44][2],S[44][2])))
S[44][3]=now+350
if now-S[44][4]>5000 then S[17]() end
end
end
end
end
