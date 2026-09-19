local S=SPELLBOUND_STATE
function S.network_tick(now)
if not S.radio_ok then return end
if S.phase=="lobby" then
for i=#S.peers,1,-1 do if now-S.peers[i][2]>4000 then table.remove(S.peers,i) end end
S.selected=S.clamp(S.selected,1,math.max(1,#S.peers))
if now>=S.next_tx then badge.radio.send("SB1|H");S.next_tx=now+850 end
elseif S.phase=="offer" then
if now>S.deadline then S.invite=nil;S.phase="lobby" end
elseif S.phase=="waiting" or S.phase=="starting" or S.phase=="joining" then
if now>S.deadline then S.end_link("Pairing timed out - try again");return end
if now>=S.next_tx then
S.transmit(S.phase=="waiting" and "I" or (S.phase=="starting" and "S" or "J"),
S.phase=="waiting" and S.peer or nil)
S.next_tx=now+600
end
elseif S.phase=="duel" or S.phase=="result" then
if S.phase=="duel" and now-S.last_rx>6000 then S.end_link("Link lost - match cancelled");return end
if S.role=="host" and S.match then
local hp,attack=S.match[2],S.match[8];S.advance(S.match,now)
if S.match[2]<hp then S.effect,S.effect_until="D",now+700
elseif attack>0 and S.match[8]==0 and S.match[1]==0 then S.effect,S.effect_until="B",now+700 end
if S.match[1]~=0 then S.phase,S.capture="result",nil end
if now-(S.last_state_tx or 0)>=200 then S.send_state(now) end
elseif S.role=="guest" then
if now-(S.last_ping or 0)>=750 then S.transmit("P");S.last_ping=now end
if S.pending and now>=S.pending[3] then
S.transmit("C",string.format("%04X|%s",S.pending[1],
S.pending[2]==4 and "X" or S.codes[S.pending[2]]))
S.pending[3]=now+350
if now-S.pending[4]>5000 then S.end_link("Cast not acknowledged - cancelled") end
end
end
end
end
function S.net_render(now,shown)
local out=""
if S.phase=="lobby" then
if #S.peers==0 then out="Searching...\nKeep both badges nearby."
else for n=1,#S.peers do
local x=S.peers[n];out=out..(n==S.selected and "> " or "  ").."Badge "..x[1]:sub(-4).."\n"
end end
return out.."\nRadio code "..S.me:sub(-4).."\nA invite / B back"
elseif S.phase=="offer" then
return "Challenge from "..S.invite[1]:sub(-4).."\n\nA accepts / B declines"
elseif S.phase=="waiting" then return "Invitation queued.\nWaiting for opponent.\n\nB cancels"
elseif S.phase=="starting" or S.phase=="joining" then return "Synchronizing...\n\nB cancels" end
local own=S.role=="host" and 1 or 2
local g=S.role=="host" and S.match or S.view
if g then
local hi=own==1 and 2 or 3;local mi=own==1 and 4 or 5
local fh=own==1 and 3 or 2;local fm=own==1 and 5 or 4
out="YOU HP "..g[hi].."  MANA "..g[mi].."\nFOE HP "..g[fh].."  MANA "..g[fm].."\n\n"
end
local title="READY TO CAST"
if S.phase=="result" then
title=(not g or g[1]==4) and "MATCH CANCELLED" or
(g[1]==3 and "DRAW" or (g[1]==own and "YOU WIN" or "DEFEAT"))
return out..title.."\n"..(shown~="" and shown or "A or B returns to menu")
end
if g then
local si=own==1 and 6 or 7;local ii=own==1 and 8 or 9
if g[ii]>now then title=g[si]>=g[ii] and "SHIELD READY TO BLOCK" or "INCOMING! CAST SHIELD"
elseif now<S.effect_until and S.effect=="B" then title="BLOCKED"
elseif S.capture then title="CHANNELING..."
elseif S.pending then title="CAST QUEUED - WAIT"
elseif g[si]>now then title="SHIELD ACTIVE" end
end
return out..title.."\n"..(shown~="" and shown or "Hold A > move > release").."\nB twice surrenders"
end
