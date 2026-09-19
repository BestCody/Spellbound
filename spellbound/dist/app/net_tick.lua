if SPELLBOUND_STATE[4]~=4 then error("Spellbound file versions do not match; reinstall every app file") end
local S=SPELLBOUND_STATE
S[37]=function(now)
if not S[50] then return end
local phase=S[49]
if phase==3 then
for i=#S[47]-2,1,-3 do if now-S[47][i+1]>4000 then table.remove(S[47],i+2);table.remove(S[47],i+1);table.remove(S[47],i) end end
S[58]=math.min(math.max(S[58],1),math.max(1,#S[47]/3))
if now>=S[41] then badge.radio.send("SB1|H");S[41]=now+850 end
elseif phase==4 then
if now>S[12] then S[22]=nil;S[49]=3 end
elseif phase==5 or phase==6 or phase==7 then
if now>S[12] then S[18]("Pairing timed out - try again");return end
if now>=S[41] then
S[69](phase==5 and "I" or (phase==6 and "S" or "J"),
phase==5 and S[46] or nil)
S[41]=now+600
end
elseif phase==8 or phase==9 then
if phase==8 and now-S[23]>6000 then S[18]("Link lost - match cancelled");return end
if S[57]==1 and S[29] then
local hp,attack=S[29][2],S[29][8];S[2](S[29],now)
if S[29][2]<hp then S[16],S[17]=5,now+700
elseif attack>0 and S[29][8]==0 and S[29][1]==0 then S[16],S[17]=6,now+700 end
if S[29][1]~=0 then S[49],S[5]=9,nil end
if now-(S[25] or 0)>=200 then S[59](now) end
elseif S[57]==2 then
if now-(S[25] or 0)>=750 then S[69]("P");S[25]=now end
if S[48] and now>=S[48][3] then
S[69]("C",string.format("%04X|%s",S[48][1],
S[48][2]==4 and "X" or S[10]:sub(S[48][2],S[48][2])))
S[48][3]=now+350
if now-S[48][4]>5000 then S[18]("Cast not acknowledged - cancelled") end
end
end
end
end
S[36]=function(now,shown)
local out="";local phase=S[49]
if phase==3 then
if #S[47]==0 then out="Searching...\nKeep both badges nearby."
else for i=1,#S[47],3 do
local n=(i+2)/3;out=out..(n==S[58] and "> " or "  ").."Badge "..S[47][i]:sub(-6).."\n"
end end
return out.."\nRadio code "..S[30]:sub(-6).."\nA invite / B back"
elseif phase==4 then
return "Challenge from "..S[22][1]:sub(-6).."\n\nA accepts / B declines"
elseif phase==5 then return "Invitation queued.\nWaiting for opponent.\n\nB cancels"
elseif phase==6 or phase==7 then return "Synchronizing...\n\nB cancels" end
local own=S[57]==1 and 1 or 2
local g=S[57]==1 and S[29] or S[71]
if g then
local hi=own==1 and 2 or 3;local mi=own==1 and 4 or 5
local fh=own==1 and 3 or 2;local fm=own==1 and 5 or 4
out="YOU HP "..g[hi].."  MANA "..g[mi].."\nFOE HP "..g[fh].."  MANA "..g[fm].."\n\n"
end
local title="READY TO CAST"
if phase==9 then
title=(not g or g[1]==4) and "MATCH CANCELLED" or
(g[1]==3 and "DRAW" or (g[1]==own and "YOU WIN" or "DEFEAT"))
return out..title.."\n"..(shown~="" and shown or "A or B returns to menu")
end
if g then
local si=own==1 and 6 or 7;local ii=own==1 and 8 or 9
if g[ii]>now then title=g[si]>=g[ii] and "SHIELD READY TO BLOCK" or "INCOMING! CAST SHIELD"
elseif now<S[17] and S[16]==6 then title="BLOCKED"
elseif S[5] then title="CHANNELING..."
elseif S[48] then title="CAST QUEUED - WAIT"
elseif g[si]>now then title="SHIELD ACTIVE" end
end
return out..title.."\n"..(shown~="" and shown or "Hold A > move > release").."\nB twice surrenders"
end
