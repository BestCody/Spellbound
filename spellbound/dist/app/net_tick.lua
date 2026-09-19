if SPELLBOUND_STATE[4]~=3 then error("Spellbound file versions do not match; reinstall every app file") end
local S=SPELLBOUND_STATE
S[41]=function(now)
if not S[54] then return end
if S[53]=="lobby" then
for i=#S[51]-2,1,-3 do if now-S[51][i+1]>4000 then table.remove(S[51],i+2);table.remove(S[51],i+1);table.remove(S[51],i) end end
S[63]=math.min(math.max(S[63],1),math.max(1,#S[51]/3))
if now>=S[45] then badge.radio.send("SB1|H");S[45]=now+850 end
elseif S[53]=="offer" then
if now>S[12] then S[23]=nil;S[53]="lobby" end
elseif S[53]=="waiting" or S[53]=="starting" or S[53]=="joining" then
if now>S[12] then S[19]("Pairing timed out - try again");return end
if now>=S[45] then
S[74](S[53]=="waiting" and "I" or (S[53]=="starting" and "S" or "J"),
S[53]=="waiting" and S[50] or nil)
S[45]=now+600
end
elseif S[53]=="duel" or S[53]=="result" then
if S[53]=="duel" and now-S[26]>6000 then S[19]("Link lost - match cancelled");return end
if S[62]=="host" and S[33] then
local hp,attack=S[33][2],S[33][8];S[2](S[33],now)
if S[33][2]<hp then S[17],S[18]="D",now+700
elseif attack>0 and S[33][8]==0 and S[33][1]==0 then S[17],S[18]="B",now+700 end
if S[33][1]~=0 then S[53],S[5]="result",nil end
if now-(S[28] or 0)>=200 then S[64](now) end
elseif S[62]=="guest" then
if now-(S[24] or 0)>=750 then S[74]("P");S[24]=now end
if S[52] and now>=S[52][3] then
S[74]("C",string.format("%04X|%s",S[52][1],
S[52][2]==4 and "X" or S[10][S[52][2]]))
S[52][3]=now+350
if now-S[52][4]>5000 then S[19]("Cast not acknowledged - cancelled") end
end
end
end
end
S[40]=function(now,shown)
local out=""
if S[53]=="lobby" then
if #S[51]==0 then out="Searching...\nKeep both badges nearby."
else for i=1,#S[51],3 do
local n=(i+2)/3;out=out..(n==S[63] and "> " or "  ").."Badge "..S[51][i]:sub(-6).."\n"
end end
return out.."\nRadio code "..S[34]:sub(-6).."\nA invite / B back"
elseif S[53]=="offer" then
return "Challenge from "..S[23][1]:sub(-6).."\n\nA accepts / B declines"
elseif S[53]=="waiting" then return "Invitation queued.\nWaiting for opponent.\n\nB cancels"
elseif S[53]=="starting" or S[53]=="joining" then return "Synchronizing...\n\nB cancels" end
local own=S[62]=="host" and 1 or 2
local g=S[62]=="host" and S[33] or S[76]
if g then
local hi=own==1 and 2 or 3;local mi=own==1 and 4 or 5
local fh=own==1 and 3 or 2;local fm=own==1 and 5 or 4
out="YOU HP "..g[hi].."  MANA "..g[mi].."\nFOE HP "..g[fh].."  MANA "..g[fm].."\n\n"
end
local title="READY TO CAST"
if S[53]=="result" then
title=(not g or g[1]==4) and "MATCH CANCELLED" or
(g[1]==3 and "DRAW" or (g[1]==own and "YOU WIN" or "DEFEAT"))
return out..title.."\n"..(shown~="" and shown or "A or B returns to menu")
end
if g then
local si=own==1 and 6 or 7;local ii=own==1 and 8 or 9
if g[ii]>now then title=g[si]>=g[ii] and "SHIELD READY TO BLOCK" or "INCOMING! CAST SHIELD"
elseif now<S[18] and S[17]=="B" then title="BLOCKED"
elseif S[5] then title="CHANNELING..."
elseif S[52] then title="CAST QUEUED - WAIT"
elseif g[si]>now then title="SHIELD ACTIVE" end
end
return out..title.."\n"..(shown~="" and shown or "Hold A > move > release").."\nB twice surrenders"
end
